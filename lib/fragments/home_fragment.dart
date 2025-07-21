import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../views/booking_flow.dart';
import '../views/create_event_view.dart';
import '../models/event_summary.dart' as event_summary;

/// Local model for /api/events/{id}
class EventDetail {
  final String description;
  final String address;
  EventDetail.fromJson(Map<String, dynamic> json)
      : description = json['description'] as String? ?? '',
        address = json['address'] as String? ?? '';
}

/// Extension to detect if an event’s end time has already passed.
extension EventSummaryX on event_summary.EventSummary {
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

/// Helper for formatting session types.
String friendlySession(event_summary.SessionType type) {
  switch (type) {
    case event_summary.SessionType.Ages8to11:
      return 'Ages 8 to 11';
    case event_summary.SessionType.Ages12to15:
      return 'Ages 12 to 15';
    default:
      return 'Ages 16+';
  }
}

/// Date formatter for the summary tiles.
String _formatDate(DateTime d) {
  const week = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  const mon  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${week[d.weekday-1]} ${d.day.toString().padLeft(2,'0')} '
         '${mon[d.month-1]} ${d.year}';
}

class HomeFragment extends StatefulWidget {
  const HomeFragment({super.key});
  @override
  _HomeFragmentState createState() => _HomeFragmentState();
}

class _HomeFragmentState extends State<HomeFragment> {
  late Future<List<event_summary.EventSummary>> _futureSummaries;

  String? _filterLocation;
  event_summary.SessionType? _filterSessionType;
  bool _dateAsc  = true;
  bool _seatsAsc = true;

  @override
  void initState() {
    super.initState();
    _futureSummaries = _loadSummaries();
  }

  Future<List<event_summary.EventSummary>> _loadSummaries() async {
    final resp = await AuthHttpClient.get('/api/events');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(event_summary.EventSummary.fromJson)
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
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: _FilterSheet(
          initialSession:  _filterSessionType,
          initialDateAsc:  _dateAsc,
          initialSeatsAsc: _seatsAsc,
          onApply: (session, dateAsc, seatsAsc) {
            setState(() {
              _filterSessionType = session;
              _dateAsc           = dateAsc;
              _seatsAsc          = seatsAsc;
            });
            // Navigator.pop(context); this is handled in _FilterSheet
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth       = context.watch<AuthProvider>();
    final canManage  = auth.isAdmin || auth.isEventManager;
    final isUser     = auth.isUser   || auth.isStaff;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,

      //  FAB for event creation
      floatingActionButton: canManage
    ? Padding(
        padding: const EdgeInsets.only(bottom: 200.0, right: 5.0),
        child: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            shape: const CircleBorder(),
            backgroundColor: const Color(0xFF4C85D0),
            child: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateEventView()),
              );
            },
          ),
        ),
      )
    : null,

      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<event_summary.EventSummary>>(
          future: _futureSummaries,
          builder: (ctx, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final hasError = snap.hasError;
            final all      = snap.data ?? [];

            // Apply filters & sorting
            final events = all.where((e) {
              if (e.status != event_summary.EventStatus.Available) return false;
              if (e.hasConcluded) return false;
              if (_filterLocation    != null && e.locationName != _filterLocation)    return false;
              if (_filterSessionType != null && e.sessionType   != _filterSessionType) return false;
              return true;
            }).toList()
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

            final allLocations = all
                .map((e) => e.locationName)
                .toSet()
                .toList()
                  ..sort();

            return RefreshIndicator(
              color: Colors.white,
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  // LOCATION HEADER
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _filterLocation,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                          dropdownColor: Colors.grey[900],
                          isExpanded: true,
                          hint: const Text(
                            'All Locations',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All Locations',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...allLocations.map((loc) => DropdownMenuItem<String?>(
                              value: loc,
                              child: Text(
                                loc.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )),
                          ],
                          onChanged: (v) => setState(() {
                            _filterLocation = v;
                          }),
                        ),
                      ),
                    ),
                  ),

                  // SESSIONS PILL
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: GestureDetector(
                        onTap: _showFilters,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.filter_list, color: Colors.black54),
                              const SizedBox(width: 8),
                              Text(
                                _filterSessionType == null
                                    ? 'All Sessions'
                                    : friendlySession(_filterSessionType!),
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // LOADING / ERROR / EMPTY
                  if (loading)
                    SliverFillRemaining(
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    )
                  else if (hasError)
                    SliverFillRemaining(
                      child: Center(
                        child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.white)),
                      ),
                    )
                  else if (events.isEmpty)
                    SliverFillRemaining(
                      child: const Center(
                        child: Text('No sessions found', style: TextStyle(color: Colors.white70)),
                      ),
                    )
                  // SESSION LIST
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => EventTile(
                          summary:    events[i],
                          isUser:     isUser,
                          canManage:  canManage,
                          loadDetail: (id) => AuthHttpClient
                              .get('/api/events/$id')
                              .then((r) => EventDetail.fromJson(jsonDecode(r.body))),
                          onAction: _refresh,
                        ),
                        childCount: events.length,
                      ),
                    ),

                  // bottom padding so last card isn’t hidden
                  SliverToBoxAdapter(
                    child: SizedBox(height: 16),
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

// FILTER SHEET
class _FilterSheet extends StatefulWidget {
  final event_summary.SessionType? initialSession;
  final bool initialDateAsc;
  final bool initialSeatsAsc;
  final void Function(event_summary.SessionType?, bool, bool) onApply;

  const _FilterSheet({
    super.key,
    this.initialSession,
    required this.initialDateAsc,
    required this.initialSeatsAsc,
    required this.onApply,
  });

  @override
  __FilterSheetState createState() => __FilterSheetState();
}

class __FilterSheetState extends State<_FilterSheet> {
  late event_summary.SessionType? _session;
  late bool _dateAsc;
  late bool _seatsAsc;

  @override
  void initState() {
    super.initState();
    _session  = widget.initialSession;
    _dateAsc  = widget.initialDateAsc;
    _seatsAsc = widget.initialSeatsAsc;
  }

  @override
  Widget build(BuildContext c) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(c).viewInsets.bottom + 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Filter & Sort',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        const Divider(color: Colors.white54),

        // Session Dropdown
        ListTile(
          title: const Text('Session Type', style: TextStyle(color: Colors.white70)),
          trailing: DropdownButton<event_summary.SessionType?>(
            dropdownColor: Colors.grey[800],
            value: _session,
            hint: const Text('All', style: TextStyle(color: Colors.white)),
            items: [
              const DropdownMenuItem(value: null, child: Text('All', style: TextStyle(color: Colors.white))),
              ...event_summary.SessionType.values.map((st) => DropdownMenuItem(
                value: st,
                child: Text(friendlySession(st), style: const TextStyle(color: Colors.white)),
              )),
            ],
            onChanged: (v) => setState(() => _session = v),
          ),
        ),

        // Date switch
        SwitchListTile(
          activeColor: Colors.blue,
          title: Text('Date ${_dateAsc ? "↑" : "↓"}', style: const TextStyle(color: Colors.white70)),
          value: _dateAsc,
          onChanged: (v) => setState(() => _dateAsc = v),
        ),

        // Seats switch
        SwitchListTile(
          activeColor: Colors.blue,
          title: Text('Seats ${_seatsAsc ? "↑" : "↓"}', style: const TextStyle(color: Colors.white70)),
          value: _seatsAsc,
          onChanged: (v) => setState(() => _seatsAsc = v),
        ),

        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: () {
            widget.onApply(_session, _dateAsc, _seatsAsc);
            Navigator.of(context).pop(); // Close the filter sheet only if apply is pressed
            // Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}


// EVENT TILE
class EventTile extends StatefulWidget {
  final event_summary.EventSummary       summary;
  final bool                            isUser, canManage;
  final Future<EventDetail> Function(int) loadDetail;
  final VoidCallback                    onAction;

  const EventTile({
    super.key,
    required this.summary,
    required this.isUser,
    required this.canManage,
    required this.loadDetail,
    required this.onAction,
  });

  @override
  _EventTileState createState() => _EventTileState();
}

class _EventTileState extends State<EventTile> {
  bool _expanded = false;
  late Future<EventDetail> _detailFut;

  static const double _pillSize   = 48.0;
  static const double _halfPill   = _pillSize / 2;
  static const double _actionSize = 48.0;
  static const double _halfAction = _actionSize / 2;
  static const double _padH       = 16.0;
  static const double _padB       = 32.0;

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(_padH, _padH, _padH, _padB),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Card container
          Container(
            decoration: BoxDecoration(
              border: _expanded
                  ? Border.all(color: Colors.white, width: 4)
                  : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SUMMARY STACK
                Padding(
                  padding: EdgeInsets.only(bottom: _halfPill),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.locationName,
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _weekdayFull(s.startDate),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(s.startDate),
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    friendlySession(s.sessionType),
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Starts ${s.startTime}', style: const TextStyle(color: Colors.black54)),
                                  Text('Ends   ${s.endTime}',   style: const TextStyle(color: Colors.black54)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // pill button
                      Positioned(
                        bottom: -_halfPill,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => setState(() => _expanded = !_expanded),
                            child: Container(
                              width: _pillSize,
                              height: _pillSize,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _expanded ? 'Less' : 'More',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // DETAILS PANEL
                if (_expanded)
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                    ),
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + _halfAction),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Icon(Icons.event_seat, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text('${s.availableSeats} Seats Available', style: const TextStyle(color: Colors.white)),
                        ]),
                        const SizedBox(height: 16),
                        FutureBuilder<EventDetail>(
                          future: _detailFut,
                          builder: (ctx, snap) {
                            final addr = snap.data?.address ?? '';
                            return Text(addr, style: const TextStyle(color: Colors.white));
                          },
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<EventDetail>(
                          future: _detailFut,
                          builder: (ctx, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                            }
                            if (snap.hasError) {
                              return const Text('Error loading details', style: TextStyle(color: Colors.redAccent));
                            }
                            return Text(snap.data!.description, style: const TextStyle(color: Colors.white70));
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ACTION BUTTON(S)
          if (_expanded)
            Positioned(
              bottom: -_halfAction,
              left: 0,
              right: 0,
              child: Center(
                child: widget.isUser
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookingFlow(event: widget.summary)),
                          );
                        },
                        child: const Text('BOOK NOW', style: TextStyle(color: Colors.white)),
                      )
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _cancelEvent,
                          child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {},
                          child: const Text('RESERVE', style: TextStyle(color: Colors.black)),
                        ),
                      ]),
              ),
            ),
        ],
      ),
    );
  }

  String _weekdayFull(DateTime d) {
    const week = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return week[d.weekday - 1];
  }
}

// Dialog for event cancellation reason
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
          const SizedBox(height: 8),
          const Icon(Icons.warning, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          const Text('Event Cancellation',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Are you sure you want to cancel?\nThis cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Explain the cancellation (sent to attendees).',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white12,
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
            child: const Text('CANCEL EVENT', style: TextStyle(color: Colors.white, letterSpacing: 1.2)),
          ),
        ]),
      ),
    );
  }
}
