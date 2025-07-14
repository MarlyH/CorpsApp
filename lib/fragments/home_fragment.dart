import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';

//Models & Parsing

enum SessionType { Kids, Teens, Adults }
SessionType _parseSessionType(dynamic raw) {
  if (raw is int) {
    return SessionType.values[raw.clamp(0, SessionType.values.length - 1)];
  } else if (raw is String) {
    return SessionType.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == raw.toLowerCase(),
      orElse: () => SessionType.Kids,
    );
  }
  return SessionType.Kids;
}

enum EventStatus { Available, Unavailable, Cancelled, Concluded }
EventStatus _parseStatus(int raw) {
  switch (raw) {
    case 1:
      return EventStatus.Unavailable;
    case 2:
      return EventStatus.Cancelled;
    case 3:
      return EventStatus.Concluded;
    default:
      return EventStatus.Available;
  }
}

class EventSummary {
  final int         id;
  final SessionType sessionType;
  final DateTime    startDate;
  final String      startTime;
  final String      endTime;
  final String      locationName;
  final int         availableSeats;
  final EventStatus status;

  EventSummary.fromJson(Map<String, dynamic> json)
      : id             = json['eventId'] as int,
        sessionType    = _parseSessionType(json['sessionType']),
        startDate      = DateTime.parse(json['startDate'] as String),
        startTime      = json['startTime'] as String,
        endTime        = json['endTime'] as String,
        locationName   = json['locationName'] as String,
        availableSeats = json['availbleSeatsCount'] as int,
        status         = _parseStatus(json['status'] as int? ?? 0);
}

class EventDetail {
  final String description, address, locationName;
  final int    totalSeats;
  final List<int> availableSeats;

  EventDetail.fromJson(Map<String, dynamic> json)
      : description    = json['description'] ?? '',
        address        = json['address'] ?? '',
        locationName   = json['locationName'] ?? '',
        totalSeats     = json['totalSeatsCount'] ?? 0,
        availableSeats = (json['availableSeats'] as List<dynamic>?)
                ?.cast<int>() ??
            [];
}

class HomeFragment extends StatefulWidget {
  const HomeFragment({Key? key}) : super(key: key);
  @override
  State<HomeFragment> createState() => _HomeFragmentState();
}

class _HomeFragmentState extends State<HomeFragment> {
  late Future<List<EventSummary>> _futureSummaries;

  // our filters
  String?        _filterLocation;
  SessionType?   _filterSessionType;
  bool           _dateAsc  = true;
  bool           _seatsAsc = true;

  @override
  void initState() {
    super.initState();
    _futureSummaries = _loadSummaries();
  }

  Future<List<EventSummary>> _loadSummaries() async {
    final resp = await AuthHttpClient.get('/api/events');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>()
        .map(EventSummary.fromJson)
        .toList();
  }

  Future<EventDetail> _loadDetail(int id) async {
    final resp = await AuthHttpClient.get('/api/events/$id');
    return EventDetail.fromJson(jsonDecode(resp.body));
  }

  void _refresh() => setState(() => _futureSummaries = _loadSummaries());

  void _openFilterMenu(List<EventSummary> allSummaries) {
    // temporary vars so we don't apply until "Apply" pressed
    SessionType? tmpSession = _filterSessionType;
    bool tmpDate = _dateAsc, tmpSeats = _seatsAsc;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSb) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Filter Options',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                const Divider(color: Colors.white54),
                // Session Type
                ListTile(
                  title: const Text('Session Type',
                      style: TextStyle(color: Colors.white70)),
                  trailing: DropdownButton<SessionType?>(
                    dropdownColor: Colors.grey[800],
                    value: tmpSession,
                    hint: const Text('All', style: TextStyle(color: Colors.white)),
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child:
                              Text('All', style: TextStyle(color: Colors.white))),
                      ...SessionType.values.map((st) {
                        final label = st.toString().split('.').last;
                        return DropdownMenuItem(
                          value: st,
                          child: Text(label, style: const TextStyle(color: Colors.white)),
                        );
                      })
                    ],
                    onChanged: (v) => setSb(() => tmpSession = v),
                  ),
                ),
                // Date sort
                SwitchListTile(
                  activeColor: Colors.blue,
                  title: const Text('Date Ascending',
                      style: TextStyle(color: Colors.white70)),
                  value: tmpDate,
                  onChanged: (v) => setSb(() => tmpDate = v),
                ),
                // Seats sort
                SwitchListTile(
                  activeColor: Colors.blue,
                  title: const Text('Seats Ascending',
                      style: TextStyle(color: Colors.white70)),
                  value: tmpSeats,
                  onChanged: (v) => setSb(() => tmpSeats = v),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () {
                    setState(() {
                      _filterSessionType = tmpSession;
                      _dateAsc           = tmpDate;
                      _seatsAsc          = tmpSeats;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply Filters'),
                )
              ]),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth         = context.watch<AuthProvider>();
    final canManage    = auth.isAdmin || auth.isEventManager;
    final isUserOrStaff = auth.isUser || auth.isStaff;
    final showAll      = canManage;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Location Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: FutureBuilder<List<EventSummary>>(
                future: _futureSummaries,
                builder: (ctx, snap) {
                  final all = snap.data ?? [];
                  final locs = all.map((e) => e.locationName).toSet().toList()
                    ..sort();
                  return DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      dropdownColor: Colors.grey[900],
                      value: _filterLocation,
                      hint: const Text('All Locations',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Locations',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                        ),
                        ...locs.map((loc) => DropdownMenuItem(
                              value: loc,
                              child: Text(loc,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                            )),
                      ],
                      onChanged: (v) => setState(() => _filterLocation = v),
                    ),
                  );
                },
              ),
            ),

            // Single “Filter” Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FutureBuilder<List<EventSummary>>(
                future: _futureSummaries,
                builder: (ctx, snap) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[850],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      onPressed: () =>
                          _openFilterMenu(snap.data ?? <EventSummary>[]),
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      label:
                          const Text('Filter', style: TextStyle(color: Colors.white)),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Event List
            Expanded(
              child: FutureBuilder<List<EventSummary>>(
                future: _futureSummaries,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  }
                  if (snap.hasError) {
                    return Center(
                        child: Text('Error: ${snap.error}',
                            style: const TextStyle(color: Colors.white)));
                  }

                  var events = snap.data!
                      .where((e) {
                        if (!showAll && e.status != EventStatus.Available)
                          return false;
                        if (_filterLocation != null &&
                            e.locationName != _filterLocation) return false;
                        if (_filterSessionType != null &&
                            e.sessionType != _filterSessionType) return false;
                        return true;
                      })
                      .toList()
                        ..sort((a, b) {
                          final dc = _dateAsc
                              ? a.startDate.compareTo(b.startDate)
                              : b.startDate.compareTo(a.startDate);
                          if (a.availableSeats != b.availableSeats) {
                            return _seatsAsc
                                ? a.availableSeats.compareTo(b.availableSeats)
                                : b.availableSeats
                                    .compareTo(a.availableSeats);
                          }
                          return dc;
                        });

                  if (events.isEmpty) {
                    return const Center(
                        child: Text('No sessions found',
                            style: TextStyle(color: Colors.white70)));
                  }

                  return RefreshIndicator(
                    color: Colors.white,
                    onRefresh: () async {
                      _refresh();
                      await _futureSummaries;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: events.length,
                      itemBuilder: (ctx, i) => EventTile(
                        summary: events[i],
                        isUser: isUserOrStaff,
                        canManage: canManage,
                        loadDetail: _loadDetail,
                        onAction: _refresh,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── EventTile ───

class EventTile extends StatefulWidget {
  final EventSummary                   summary;
  final bool                           isUser, canManage;
  final Future<EventDetail> Function(int) loadDetail;
  final VoidCallback                   onAction;

  const EventTile({
    Key? key,
    required this.summary,
    required this.isUser,
    required this.canManage,
    required this.loadDetail,
    required this.onAction,
  }) : super(key: key);

  @override
  State<EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<EventTile> {
  bool _expanded = false;
  late Future<EventDetail> _detailFut;

  @override
  void initState() {
    super.initState();
    _detailFut = widget.loadDetail(widget.summary.id);
  }

  String _formatDate(DateTime d) {
    const week = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mon  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${week[d.weekday-1]} ${d.day.toString().padLeft(2,'0')} ${mon[d.month-1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    const pillSize = 32.0;
    const overlap  = pillSize/2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            // White summary
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(14)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.locationName,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(_formatDate(s.startDate),
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(s.sessionType.toString().split('.').last,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('Starts ${s.startTime}',
                      style: const TextStyle(color: Colors.black54)),
                  Text('Ends   ${s.endTime}',
                      style: const TextStyle(color: Colors.black54)),
                ]),
              ]),
            ),

            // Black details
            if (_expanded)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.event_seat,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text('${s.availableSeats} Seats Available',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                      const Spacer(),
                      const Icon(Icons.location_on,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      FutureBuilder<EventDetail>(
                        future: _detailFut,
                        builder: (ctx, snap) {
                          final addr = snap.data?.address ?? '';
                          return Text(addr,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14));
                        },
                      ),
                    ]),
                    const SizedBox(height: 12),
                    FutureBuilder<EventDetail>(
                      future: _detailFut,
                      builder: (ctx, snap) {
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2));
                        }
                        if (snap.hasError) {
                          return const Text('Error loading details',
                              style:
                                  TextStyle(color: Colors.redAccent));
                        }
                        return Text(snap.data!.description,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14));
                      },
                    ),
                    const SizedBox(height: 16),
                    if (widget.isUser)
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 12),
                          ),
                          onPressed: () {/* book */},
                          child:
                              const Text('BOOK NOW', style: TextStyle(color: Colors.white)),
                        ),
                      )
                    else if (widget.canManage)
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {/* cancel */},
                            child: const Text('CANCEL EVENT',
                                style:
                                    TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {/* reserve */},
                            child: const Text('RESERVE SEAT',
                                style:
                                    TextStyle(color: Colors.black)),
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
          ]),
        ),

        // More/Less pill
        Positioned(
          bottom: -overlap,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                width: pillSize,
                height: pillSize,
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                alignment: Alignment.center,
                child: Text(_expanded ? 'Less' : 'More',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
