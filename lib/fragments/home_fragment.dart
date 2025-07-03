import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../views/children/create_child.dart';

/// --- Models & Helpers ---

enum SessionType { Kids, Teens, Adults }

SessionType _parseSessionType(dynamic raw) {
  if (raw is int) {
    return SessionType.values[raw.clamp(0, SessionType.values.length - 1)];
  } else if (raw is String) {
    return SessionType.values.firstWhere(
      (e) =>
          e.toString().split('.').last.toLowerCase() ==
          raw.toLowerCase(),
      orElse: () => SessionType.Kids,
    );
  }
  return SessionType.Kids;
}

class EventSummary {
  final int         id;
  final SessionType sessionType;
  final DateTime    startDate;
  final String      startTime;
  final String      endTime;
  final String      locationName;
  final int         availableSeats;

  EventSummary({
    required this.id,
    required this.sessionType,
    required this.startDate,
    required this.startTime,
    required this.endTime,
    required this.locationName,
    required this.availableSeats,
  });

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    return EventSummary(
      id:             json['eventId']           as int,
      sessionType:    _parseSessionType(json['sessionType']),
      startDate:      DateTime.parse(json['startDate'] as String),
      startTime:      json['startTime']         as String,
      endTime:        json['endTime']           as String,
      locationName:   json['locationName']      as String,
      availableSeats: json['availbleSeatsCount'] as int,
    );
  }
}

class EventDetail {
  final int       id;
  final String    description;
  final String    address;
  final int       totalSeats;
  final String    locationName;
  final List<int> availableSeats;

  EventDetail({
    required this.id,
    required this.description,
    required this.address,
    required this.totalSeats,
    required this.locationName,
    required this.availableSeats,
  });

  factory EventDetail.fromJson(Map<String, dynamic> json) {
    return EventDetail(
      id:             json['eventId']        as int,
      description:    json['description']    as String?    ?? '',
      address:        json['address']        as String?    ?? '',
      totalSeats:     json['totalSeatsCount'] as int?      ?? 0,
      locationName:   json['locationName']   as String?    ?? '',
      availableSeats: (json['availableSeats'] as List<dynamic>?)
                          ?.cast<int>()                    ?? [],
    );
  }
}

/// --- HomeFragment ---

class HomeFragment extends StatefulWidget {
  const HomeFragment({Key? key}) : super(key: key);
  @override
  State<HomeFragment> createState() => _HomeFragmentState();
}

class _HomeFragmentState extends State<HomeFragment> {
  late Future<List<EventSummary>> _futureSummaries;

  // filter & sort state
  String? _filterLocation;
  bool   _dateAsc   = true;
  bool   _seatsAsc  = true;

  @override
  void initState() {
    super.initState();
    _futureSummaries = _loadSummaries();
  }

  Future<List<EventSummary>> _loadSummaries() async {
    final resp = await AuthHttpClient.get('/api/events');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(EventSummary.fromJson)
        .toList();
  }

  Future<EventDetail> _loadDetail(int id) async {
    final resp = await AuthHttpClient.get('/api/events/$id');
    return EventDetail.fromJson(jsonDecode(resp.body));
  }

  void _refreshList() {
    setState(() => _futureSummaries = _loadSummaries());
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final isUser    = auth.isUser;
    final canManage = auth.isAdmin || auth.isEventManager;

    return FutureBuilder<List<EventSummary>>(
      future: _futureSummaries,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        final events = snap.data!;
        if (events.isEmpty) {
          return const Center(
            child: Text('No events', style: TextStyle(color: Colors.white70)),
          );
        }

        // build unique location list
        final locs = events.map((e) => e.locationName).toSet().toList()..sort();

        // apply filters
        var filtered = events
            .where((e) =>
                _filterLocation == null || e.locationName == _filterLocation)
            .toList();

        // apply sorting
        filtered.sort((a, b) {
          final dateCmp = _dateAsc
              ? a.startDate.compareTo(b.startDate)
              : b.startDate.compareTo(a.startDate);
          if (a.availableSeats != b.availableSeats) {
            return _seatsAsc
                ? a.availableSeats.compareTo(b.availableSeats)
                : b.availableSeats.compareTo(a.availableSeats);
          }
          return dateCmp;
        });

        return Column(
          children: [
            const SizedBox(height: 16),
            FilterPanel(
              locations:         locs,
              selectedLocation:  _filterLocation,
              dateAsc:           _dateAsc,
              seatsAsc:          _seatsAsc,
              onLocationChanged: (v)  => setState(() => _filterLocation = v),
              onDateSortChanged: (v)  => setState(() => _dateAsc  = v!),
              onSeatSortChanged: (v)  => setState(() => _seatsAsc = v!),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _refreshList();
                  await _futureSummaries;
                },
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final summary = filtered[i];
                    return EventTile(
                      summary:    summary,
                      isUser:     isUser,
                      canManage:  canManage,
                      loadDetail: _loadDetail,
                      onBooked:   _refreshList,
                      onReserved: _refreshList,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// --- FilterPanel ---

class FilterPanel extends StatelessWidget {
  final List<String>        locations;
  final String?             selectedLocation;
  final bool                dateAsc;
  final bool                seatsAsc;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<bool?>  onDateSortChanged;
  final ValueChanged<bool?>  onSeatSortChanged;

  const FilterPanel({
    Key? key,
    required this.locations,
    required this.selectedLocation,
    required this.dateAsc,
    required this.seatsAsc,
    required this.onLocationChanged,
    required this.onDateSortChanged,
    required this.onSeatSortChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding:              const EdgeInsets.symmetric(horizontal: 16),
      collapsedIconColor:       Colors.white70,
      iconColor:                Colors.white,
      title:                    const Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor:          Colors.grey.shade900,
      collapsedBackgroundColor: Colors.black,
      childrenPadding:          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButton<String?>(
                isExpanded:    true,
                dropdownColor: Colors.black,
                value:         selectedLocation,
                hint:          const Text('All locations', style: TextStyle(color: Colors.white70)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All', style: TextStyle(color: Colors.white))),
                  ...locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc, style: const TextStyle(color: Colors.white)))),
                ],
                onChanged: onLocationChanged,
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<bool>(
              dropdownColor: Colors.black,
              value:         dateAsc,
              items: const [
                DropdownMenuItem(value: true,  child: Text('Date ↑', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: false, child: Text('Date ↓', style: TextStyle(color: Colors.white))),
              ],
              onChanged: onDateSortChanged,
            ),
            const SizedBox(width: 8),
            DropdownButton<bool>(
              dropdownColor: Colors.black,
              value:         seatsAsc,
              items: const [
                DropdownMenuItem(value: true,  child: Text('Seats ↑', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: false, child: Text('Seats ↓', style: TextStyle(color: Colors.white))),
              ],
              onChanged: onSeatSortChanged,
            ),
          ],
        ),
      ],
    );
  }
}

/// --- EventTile ---

class EventTile extends StatefulWidget {
  final EventSummary                   summary;
  final bool                           isUser;
  final bool                           canManage;
  final Future<EventDetail> Function(int) loadDetail;
  final VoidCallback                   onBooked;
  final VoidCallback                   onReserved;

  const EventTile({
    Key? key,
    required this.summary,
    required this.isUser,
    required this.canManage,
    required this.loadDetail,
    required this.onBooked,
    required this.onReserved,
  }) : super(key: key);

  @override
  State<EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<EventTile> {
  late Future<EventDetail> _futureDetail;

  @override
  void initState() {
    super.initState();
    _futureDetail = widget.loadDetail(widget.summary.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return FutureBuilder<EventDetail>(
      future: _futureDetail,
      builder: (ctx, snap) {
        return ExpansionTile(
          backgroundColor:          Colors.grey.shade900,
          collapsedBackgroundColor: Colors.black,
          title: Text(
            s.sessionType.toString().split('.').last,
            style: const TextStyle(color: Colors.white),
          ),
          // —— UPDATED: show live availableSeats here
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.startDate.toLocal().toIso8601String().split("T")[0]} '
                '${s.startTime} – ${s.endTime}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'Available seats: ${s.availableSeats}',
                style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          children: [
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: Colors.white),
              )
            else if (snap.hasError)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Error loading details', style: TextStyle(color: Colors.white)),
              )
            else
              _DetailContent(
                detail:     snap.data!,
                isUser:     widget.isUser,
                canManage:  widget.canManage,
                onBooked:   widget.onBooked,
                onReserved: widget.onReserved,
              ),
          ],
        );
      },
    );
  }
}

/// --- DetailContent (with Remaining seats line) ---

class _DetailContent extends StatelessWidget {
  final EventDetail detail;
  final bool        isUser;
  final bool        canManage;
  final VoidCallback onBooked;
  final VoidCallback onReserved;

  const _DetailContent({
    required this.detail,
    required this.isUser,
    required this.canManage,
    required this.onBooked,
    required this.onReserved,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.description, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Text('Location: ${detail.locationName}', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Text('Seats: ${detail.totalSeats}', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          // —— NEW: show remaining seats after booking
          Text(
            'Remaining seats: ${detail.availableSeats.length}',
            style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: isUser
                  ? () => _showBookingDialog(context, detail, onBooked)
                  : canManage
                      ? () => _showReserveDialog(context, detail.id, onReserved)
                      : null,
              child: Text(isUser ? 'Book' : (canManage ? 'Reserve' : 'N/A')),
            ),
          ),
        ],
      ),
    );
  }

  /// booking dialog now takes (BuildContext, detail, onBooked)
  Future<void> _showBookingDialog(
    BuildContext context,
    EventDetail detail,
    VoidCallback onBooked,
  ) async {
    // pre-fetch children
    List<Map<String, dynamic>> children = [];
    try {
      final resp = await AuthHttpClient.get('/api/child');
      children = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
    } catch (_) {}

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        int?  selectedSeat;
        int?  selectedChild;
        bool canBeLeftAlone = false;

        return StatefulBuilder(
          builder: (sbCtx, setSbState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: const Text('Book for child', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    isExpanded:    true,
                    dropdownColor: Colors.black,
                    value:         selectedSeat,
                    hint:          const Text('Select seat', style: TextStyle(color: Colors.white70)),
                    items: detail.availableSeats.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text('Seat $s', style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (v) => setSbState(() => selectedSeat = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<int>(
                    isExpanded:    true,
                    dropdownColor: Colors.black,
                    value:         selectedChild,
                    hint:          const Text('Select child', style: TextStyle(color: Colors.white70)),
                    items: children.map((cData) {
                      final id = cData['childId'] as int;
                      final fn = cData['firstName'] as String? ?? '';
                      final ln = cData['lastName']  as String? ?? '';
                      return DropdownMenuItem(
                        value: id,
                        child: Text('$fn $ln', style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (v) => setSbState(() => selectedChild = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Can be left alone?', style: TextStyle(color: Colors.white)),
                      Switch(
                        value: canBeLeftAlone,
                        onChanged: (v) => setSbState(() => canBeLeftAlone = v),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateChildView()),
                    );
                  },
                  child: const Text('New Child', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: (selectedSeat != null && selectedChild != null)
                      ? () async {
                          Navigator.of(dialogCtx).pop();
                          try {
                            final dto = {
                              'eventId':        detail.id,
                              'seatNumber':     selectedSeat,
                              'isForChild':     true,
                              'childId':        selectedChild,
                              'canBeLeftAlone': canBeLeftAlone,
                            };
                            final resp = await AuthHttpClient.post('/api/Booking', body: dto);
                            final data = resp.body.isNotEmpty
                                ? jsonDecode(resp.body) as Map<String, dynamic>
                                : null;
                            final msg = data?['message'] as String? ?? 'Booked successfully';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg, style: const TextStyle(color: Colors.black)),
                                backgroundColor: Colors.white,
                              ),
                            );
                            onBooked();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Booking failed: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      : null,
                  child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// reserve dialog unchanged
  Future<void> _showReserveDialog(
    BuildContext context,
    int eventId,
    VoidCallback onReserved,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Reserve Seat', style: TextStyle(color: Colors.white)),
        content: const Text('Reserve a seat for this event?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await AuthHttpClient.post('/api/events/$eventId/reserve', body: {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reserved!', style: TextStyle(color: Colors.black)),
                    backgroundColor: Colors.white,
                  ),
                );
                onReserved();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reserve failed: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('RESERVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
