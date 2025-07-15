import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../views/booking_flow.dart';
import '../models/event_summary.dart';

// Local model for /api/events/{id}
class EventDetail {
  final String description;
  final String address;
  EventDetail.fromJson(Map<String, dynamic> json)
      : description = json['description'] as String? ?? '',
        address     = json['address']     as String? ?? '';
}

// Extension to detect if an event’s end time has already passed.
extension EventSummaryX on EventSummary {
  bool get hasConcluded {
    final now = DateTime.now();
    final parts = endTime.split(':').map(int.parse).toList();
    final endDt = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      parts[0],
      parts[1],
    );
    return now.isAfter(endDt);
  }
}

// Helper for formatting session types.
String friendlySession(SessionType type) {
  switch (type) {
    case SessionType.Ages8to11:
      return 'Ages 8 to 11';
    case SessionType.Ages12to15:
      return 'Ages 12 to 15';
    default:
      return 'Ages 16+';
  }
}

// Date formatter for the summary tiles.
String _formatDate(DateTime d) {
  const week = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  const mon  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${week[d.weekday-1]} ${d.day.toString().padLeft(2,'0')} '
         '${mon[d.month-1]} ${d.year}';
}

class HomeFragment extends StatefulWidget {
  const HomeFragment({Key? key}) : super(key: key);
  @override
  _HomeFragmentState createState() => _HomeFragmentState();
}

class _HomeFragmentState extends State<HomeFragment> {
  late Future<List<EventSummary>> _futureSummaries;

  String?      _filterLocation;
  SessionType? _filterSessionType;
  bool         _dateAsc  = true;
  bool         _seatsAsc = true;

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

  Future<void> _refresh() async {
    setState(() {
      _futureSummaries = _loadSummaries();
    });
    await _futureSummaries;
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FilterSheet(
        initialSession:  _filterSessionType,
        initialDateAsc:  _dateAsc,
        initialSeatsAsc: _seatsAsc,
        onApply: (session, dateAsc, seatsAsc) {
          setState(() {
            _filterSessionType = session;
            _dateAsc           = dateAsc;
            _seatsAsc          = seatsAsc;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final canManage = auth.isAdmin || auth.isEventManager;
    final isUser    = auth.isUser   || auth.isStaff;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<EventSummary>>(
          future: _futureSummaries,
          builder: (ctx, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final hasError = snap.hasError;
            final all      = snap.data ?? [];

            // apply filter & sort on the raw list
            final events = all
                .where((e) {
                  if (e.status != EventStatus.Available) return false;
                  if (e.hasConcluded) return false;
                  if (_filterLocation   != null && e.locationName  != _filterLocation)   return false;
                  if (_filterSessionType!= null && e.sessionType   != _filterSessionType) return false;
                  return true;
                })
                .toList()
                  ..sort((a, b) {
                    final dateComp = _dateAsc
                        ? a.startDate.compareTo(b.startDate)
                        : b.startDate.compareTo(a.startDate);
                    if (a.availableSeats != b.availableSeats) {
                      return _seatsAsc
                          ? a.availableSeats.compareTo(b.availableSeats)
                          : b.availableSeats.compareTo(a.availableSeats);
                    }
                    return dateComp;
                  });

            return RefreshIndicator(
              color: Colors.white,
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  // Location selector
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: _LocationSelector(
                        locations: all.map((e) => e.locationName).toSet().toList()..sort(),
                        selected:  _filterLocation,
                        onChanged: (v) => setState(() => _filterLocation = v),
                      ),
                    ),
                  ),

                  // Filter button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[850],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        icon: const Icon(Icons.filter_list, color: Colors.white),
                        label: const Text('Filter', style: TextStyle(color: Colors.white)),
                        onPressed: _showFilters,
                      ),
                    ),
                  ),

                  // Spacer
                  SliverToBoxAdapter(child: const SizedBox(height: 8)),

                  // Loading state
                  if (loading)
                    SliverFillRemaining(
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  // Error state
                  else if (hasError)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'Error: ${snap.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  // Empty state
                  else if (events.isEmpty)
                    SliverFillRemaining(
                      child: const Center(
                        child: Text('No sessions found', style: TextStyle(color: Colors.white70)),
                      ),
                    )
                  // Actual list
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final s = events[i];
                          return EventTile(
                            key: ValueKey(s.eventId),
                            summary:    s,
                            isUser:     isUser,
                            canManage:  canManage,
                            loadDetail: (id) => AuthHttpClient
                                .get('/api/events/$id')
                                .then((r) => EventDetail.fromJson(jsonDecode(r.body))),
                            onAction:   _refresh,
                          );
                        },
                        childCount: events.length,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}


// Location dropdown
class _LocationSelector extends StatelessWidget {
  final List<String> locations;
  final String?      selected;
  final void Function(String?) onChanged;

  const _LocationSelector({
    Key? key,
    required this.locations,
    required this.selected,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext c) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        isExpanded:    true,
        dropdownColor: Colors.grey[900],
        value:         selected,
        hint: const Text(
          'All Locations',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text(
              'All Locations',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          ...locations.map((loc) => DropdownMenuItem(
            value: loc,
            child: Text(loc, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

// Filter & Sort bottom sheet
class _FilterSheet extends StatelessWidget {
  final SessionType? initialSession;
  final bool initialDateAsc;
  final bool initialSeatsAsc;
  final void Function(SessionType?, bool, bool) onApply;

  const _FilterSheet({
    Key? key,
    this.initialSession,
    required this.initialDateAsc,
    required this.initialSeatsAsc,
    required this.onApply,
  }) : super(key: key);

  @override
  Widget build(BuildContext c) {
    var _session   = initialSession;
    var _dateAsc   = initialDateAsc;
    var _seatsAsc  = initialSeatsAsc;

    return StatefulBuilder(builder: (_, setSb) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Filter & Sort', style: TextStyle(color: Colors.white, fontSize: 18)),
          const Divider(color: Colors.white54),
          ListTile(
            title: const Text('Session Type', style: TextStyle(color: Colors.white70)),
            trailing: DropdownButton<SessionType?>(
              dropdownColor: Colors.grey[800],
              value: _session,
              hint: const Text('All', style: TextStyle(color: Colors.white)),
              items: [
                const DropdownMenuItem(value: null, child: Text('All', style: TextStyle(color: Colors.white))),
                ...SessionType.values.map((st) => DropdownMenuItem(
                  value: st,
                  child: Text(friendlySession(st), style: const TextStyle(color: Colors.white)),
                )),
              ],
              onChanged: (v) => setSb(() => _session = v),
            ),
          ),
          SwitchListTile(
            activeColor: Colors.blue,
            title: const Text('Date ↑', style: TextStyle(color: Colors.white70)),
            value: _dateAsc,
            onChanged: (v) => setSb(() => _dateAsc = v),
          ),
          SwitchListTile(
            activeColor: Colors.blue,
            title: const Text('Seats ↑', style: TextStyle(color: Colors.white70)),
            value: _seatsAsc,
            onChanged: (v) => setSb(() => _seatsAsc = v),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: () => onApply(_session, _dateAsc, _seatsAsc),
            child: const Text('Apply'),
          ),
        ]),
      );
    });
  }
}

/// The in-file EventTile
/// (unchanged from your last version except for using friendlySession)
class EventTile extends StatefulWidget {
  final EventSummary                    summary;
  final bool                            isUser, canManage;
  final Future<EventDetail> Function(int) loadDetail;
  final VoidCallback                    onAction;

  const EventTile({
    Key? key,
    required this.summary,
    required this.isUser,
    required this.canManage,
    required this.loadDetail,
    required this.onAction,
  }) : super(key: key);

  @override
  _EventTileState createState() => _EventTileState();
}

class _EventTileState extends State<EventTile> {
  bool _expanded = false;
  late Future<EventDetail> _detailFut;

  @override
  void initState() {
    super.initState();
    _detailFut = widget.loadDetail(widget.summary.eventId);
  }

  Future<void> _cancelEvent() async {
    final ctrl = TextEditingController();
    final msg  = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CancellationDialog(controller: ctrl),
    );
    if (msg != null) {
      try {
        await AuthHttpClient.put(
          '/api/events/${widget.summary.eventId}/cancel',
          body: {'cancellationMessage': msg},
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event cancelled'), backgroundColor: Colors.green),
        );
        widget.onAction();
        setState(() => _expanded = false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancel failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final s = widget.summary;
    const pillSize = 48.0, overlap = pillSize / 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal:16, vertical:8),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            // summary panel
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.locationName, style: const TextStyle(color: Colors.black54, fontSize:12)),
                    const SizedBox(height:8),
                    Text(_formatDate(s.startDate),
                        style: const TextStyle(color: Colors.black87, fontSize:20, fontWeight: FontWeight.bold)),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children:[
                  Text(friendlySession(s.sessionType), style: const TextStyle(color: Colors.black54, fontSize:12)),
                  const SizedBox(height:8),
                  Text('Starts ${s.startTime}', style: const TextStyle(color: Colors.black54)),
                  Text('Ends   ${s.endTime}',   style: const TextStyle(color: Colors.black54)),
                ]),
              ]),
            ),

            // detail panel
            if (_expanded)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
                padding: const EdgeInsets.fromLTRB(16,24,16,16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children:[
                  Row(children:[
                    const Icon(Icons.event_seat, color: Colors.white, size:16),
                    const SizedBox(width:6),
                    Text('${s.availableSeats} Seats Available',
                        style: const TextStyle(color: Colors.white, fontSize:14)),
                    const Spacer(),
                    const Icon(Icons.location_on, color: Colors.white, size:16),
                    const SizedBox(width:6),
                    FutureBuilder<EventDetail>(
                      future: _detailFut,
                      builder:(ctx,snap) {
                        final addr = snap.data?.address ?? '';
                        return Text(addr, style: const TextStyle(color: Colors.white, fontSize:14));
                      },
                    ),
                  ]),
                  const SizedBox(height:12),
                  FutureBuilder<EventDetail>(
                    future: _detailFut,
                    builder:(ctx,snap){
                      if (snap.connectionState==ConnectionState.waiting) {
                        return const Center(child:CircularProgressIndicator(color: Colors.white, strokeWidth:2));
                      }
                      if (snap.hasError) {
                        return const Text('Error loading details', style: TextStyle(color: Colors.redAccent));
                      }
                      return Text(snap.data!.description,
                        style: const TextStyle(color: Colors.white70, fontSize:14));
                    },
                  ),
                  const SizedBox(height:16),

                  if (widget.isUser)
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal:40, vertical:12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookingFlow(event: s)),
                          );
                        },
                        child: const Text('BOOK NOW', style: TextStyle(color: Colors.white)),
                      ),
                    )
                  else if (widget.canManage)
                    Row(children:[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical:12),
                          ),
                          onPressed: _cancelEvent,
                          child: const Text('CANCEL EVENT', style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                      const SizedBox(width:8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical:12),
                          ),
                          onPressed: () {/* reserve seat */},
                          child: const Text('RESERVE SEAT', style: TextStyle(color: Colors.black)),
                        ),
                      ),
                    ]),
                ]),
              ),
          ]),
        ),

        // centered toggle pill
        Positioned(
          bottom: -overlap,
          left: 0, right: 0,
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              width: pillSize, height: pillSize,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white),
              ),
              alignment: Alignment.center,
              child: Text(
                _expanded ? 'Less' : 'More',
                style: const TextStyle(color: Colors.white, fontSize:14),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// Cancellation dialog
class _CancellationDialog extends StatelessWidget {
  final TextEditingController controller;
  const _CancellationDialog({required this.controller});

  @override
  Widget build(BuildContext c) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children:[
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => Navigator.of(c).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(height:8),
          const Icon(Icons.warning, color: Colors.red, size:48),
          const SizedBox(height:8),
          const Text('Event Cancellation',
              style: TextStyle(color: Colors.white, fontSize:18, fontWeight: FontWeight.bold)),
          const SizedBox(height:8),
          const Text(
            'Are you sure you want to cancel?\nThis cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height:16),
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Explain the cancellation (sent to attendees).',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: Colors.white12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal:12, vertical:14),
            ),
          ),
          const SizedBox(height:16),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal:32, vertical:12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('CANCEL EVENT', style: TextStyle(color: Colors.white, letterSpacing:1.2)),
          ),
        ]),
      ),
    );
  }
}
