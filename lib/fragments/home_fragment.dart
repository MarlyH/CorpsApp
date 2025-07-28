import 'dart:convert';
import 'package:corpsapp/views/login_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../views/booking_flow.dart';
import 'package:http/http.dart' as http;
import '../views/create_event_view.dart';
import '../models/event_summary.dart' as event_summary;
import 'package:flutter_dotenv/flutter_dotenv.dart';


/// Local model for /api/events/{id}
class EventDetail {
  final String description;
  final String address;
  EventDetail.fromJson(Map<String, dynamic> json)
      : description = json['description'] as String? ?? '',
        address     = json['address']     as String? ?? '';
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

  // four sort flags
  bool _dateAsc   = true;   // default: closest date first
  bool _dateDesc  = false;
  bool _seatsAsc  = false;
  bool _seatsDesc = false;

  @override
  void initState() {
    super.initState();
    _futureSummaries = _loadSummaries();
  }

  Future<List<event_summary.EventSummary>> _loadSummaries() async {
    final base = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final resp = await http.get(
      Uri.parse('$base/api/events'),
      headers: {'Content-Type':'application/json'},
    );
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
          initialSession:    _filterSessionType,
          initialDateAsc:    _dateAsc,
          initialDateDesc:   _dateDesc,
          initialSeatsAsc:   _seatsAsc,
          initialSeatsDesc:  _seatsDesc,
          onApply: (
            session,
            dateAsc,
            dateDesc,
            seatsAsc,
            seatsDesc,
          ) {
            setState(() {
              _filterSessionType = session;
              _dateAsc   = dateAsc;
              _dateDesc  = dateDesc;
              _seatsAsc  = seatsAsc;
              _seatsDesc = seatsDesc;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final canManage = auth.isAdmin || auth.isEventManager;
    final isUser    = auth.isUser  || auth.isStaff;
    final isGuest = !isUser || !canManage;

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: canManage
          ? Padding(
              padding: const EdgeInsets.only(bottom: 5.0),
              child: SizedBox(
                width: 70,
                height: 70,
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

            // APPLY FILTERS (rely solely on status from backend)
            final events = all.where((e) {
              if (e.status != event_summary.EventStatus.Available) return false;
              if (_filterLocation    != null && e.locationName != _filterLocation)    return false;
              if (_filterSessionType != null && e.sessionType   != _filterSessionType) return false;
              return true;
            }).toList()
              // APPLY SORTS
              ..sort((a, b) {
                if (_dateAsc) {
                  final c = a.startDate.compareTo(b.startDate);
                  if (c != 0) return c;
                } else if (_dateDesc) {
                  final c = b.startDate.compareTo(a.startDate);
                  if (c != 0) return c;
                }
                if (_seatsAsc) {
                  return a.availableSeats.compareTo(b.availableSeats);
                } else if (_seatsDesc) {
                  return b.availableSeats.compareTo(a.availableSeats);
                }
                return 0;
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
                          //isGuest: isGuest,
                          loadDetail: (id) => AuthHttpClient
                              .get('/api/events/$id')
                              .then((r) => EventDetail.fromJson(jsonDecode(r.body))),
                          onAction: _refresh,
                        ),
                        childCount: events.length,
                      ),
                    ),
                  // bottom padding so last card isn’t hidden
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            );
          },  
        ),
      ),
    );
  }
}

/// FILTER SHEET
class _FilterSheet extends StatefulWidget {
  final event_summary.SessionType? initialSession;
  final bool initialDateAsc;
  final bool initialDateDesc;
  final bool initialSeatsAsc;
  final bool initialSeatsDesc;
  final void Function(
    event_summary.SessionType?,
    bool, bool,
    bool, bool,
  ) onApply;

  const _FilterSheet({
    super.key,
    this.initialSession,
    required this.initialDateAsc,
    required this.initialDateDesc,
    required this.initialSeatsAsc,
    required this.initialSeatsDesc,
    required this.onApply,
  });

  @override
  __FilterSheetState createState() => __FilterSheetState();
}

class __FilterSheetState extends State<_FilterSheet> {
  late event_summary.SessionType? _session;
  late bool _dateAsc, _dateDesc, _seatsAsc, _seatsDesc;

  @override
  void initState() {
    super.initState();
    _session    = widget.initialSession;
    _dateAsc    = widget.initialDateAsc;
    _dateDesc   = widget.initialDateDesc;
    _seatsAsc   = widget.initialSeatsAsc;
    _seatsDesc  = widget.initialSeatsDesc;
  }

  @override
  Widget build(BuildContext c) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(c).viewInsets.bottom + 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Filter & Sort', style: TextStyle(color: Colors.white, fontSize: 18)),
        const Divider(color: Colors.white54),

        // Session Type
        ListTile(
          title: const Text('Session Type', style: TextStyle(color: Colors.white70)),
          trailing: DropdownButton<event_summary.SessionType?>(
            dropdownColor: Colors.grey[800],
            value: _session,
            hint: const Text('All', style: TextStyle(color: Colors.white)),
            items: [
              const DropdownMenuItem(value: null, child: Text('All', style: TextStyle(color: Colors.white))),
              for (var st in event_summary.SessionType.values)
                DropdownMenuItem(
                  value: st,
                  child: Text(friendlySession(st), style: const TextStyle(color: Colors.white)),
                ),
            ],
            onChanged: (v) => setState(() => _session = v),
          ),
        ),

        // Date Ascending
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Colors.blue,
          title: const Text('Date Ascending', style: TextStyle(color: Colors.white70)),
          value: _dateAsc,
          onChanged: (v) {
            setState(() {
              _dateAsc  = v!;
              if (v) _dateDesc = false;
            });
          },
        ),
        // Date Descending
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Colors.blue,
          title: const Text('Date Descending', style: TextStyle(color: Colors.white70)),
          value: _dateDesc,
          onChanged: (v) {
            setState(() {
              _dateDesc = v!;
              if (v) _dateAsc = false;
            });
          },
        ),

        // Seats Ascending
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Colors.blue,
          title: const Text('Seats Ascending', style: TextStyle(color: Colors.white70)),
          value: _seatsAsc,
          onChanged: (v) {
            setState(() {
              _seatsAsc  = v!;
              if (v) _seatsDesc = false;
            });
          },
        ),
        // Seats Descending
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Colors.blue,
          title: const Text('Seats Descending', style: TextStyle(color: Colors.white70)),
          value: _seatsDesc,
          onChanged: (v) {
            setState(() {
              _seatsDesc = v!;
              if (v) _seatsAsc = false;
            });
          },
        ),

        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: () {
            widget.onApply(
              _session,
              _dateAsc, _dateDesc,
              _seatsAsc, _seatsDesc,
            );
            Navigator.of(context).pop();
          },
          child: const Text('APPLY'),
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
    // required this.isGuest,
    required this.loadDetail,
    required this.onAction,
  });

  @override
  _EventTileState createState() => _EventTileState();
}

class _EventTileState extends State<EventTile> {
  bool _expanded = false;
  late Future<EventDetail> _detailFut;

  static const double _pillSize    = 48.0;
  static const double _halfPill    = _pillSize / 2;
  static const double _actionSize  = 48.0;
  static const double _halfAction  = _actionSize / 2;
  static const double _outerPadH   = 16.0;
  static const double _outerPadB   = 32.0;
  static const double _innerPad    = 24.0;
  static const double _borderWidth = 4.0;
  static const double _outerRadius = 16.0;
  static const double _innerRadius = _outerRadius - _borderWidth;

  @override
  void initState() {
    super.initState();
    _detailFut = widget.loadDetail(widget.summary.eventId);
  }

  Future<void> _cancelEvent() async {
    final ctrl = TextEditingController();
    final msg = await showDialog<String>(
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
          const SnackBar(
            content: Text('Event cancelled'),
            backgroundColor: Color.fromARGB(255, 255, 255, 255),
          ),
        );
        widget.onAction();
        setState(() => _expanded = false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancel failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
Widget build(BuildContext context) {
  final s = widget.summary;

  return Padding(
    padding: const EdgeInsets.fromLTRB(_outerPadH, _outerPadH, _outerPadH, _outerPadB),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // Outer border
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: _borderWidth),
              borderRadius: BorderRadius.circular(_outerRadius),
            ),
          ),
        ),

        // Content panels inset by borderWidth
        Padding(
          padding: const EdgeInsets.all(_borderWidth),
          child: _buildContentPanels(),
        ),

        // Action buttons when expanded
        _buildActionButtons(),
      ],
    ),
  );
}

Widget _buildContentPanels() {
  final s = widget.summary;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // SUMMARY and PILL Section
      Padding(
        padding: const EdgeInsets.only(bottom: _halfPill),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Summary card with small centered image
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: _expanded
                    ? BorderRadius.vertical(top: Radius.circular(_innerRadius))
                    : BorderRadius.circular(_innerRadius),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: _innerPad,
                vertical: _innerPad,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // small, faint background logo, safe against missing asset
                  Opacity(
                    opacity: 0.5,
                    child: Image.asset(
                      s.locationAssetPath,
                      width: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stack) => const SizedBox.shrink(),
                    ),
                  ),

                  // summary text
                  Row(
                    children: [
                      Expanded(child: _summaryLeft(s)),
                      Expanded(child: _summaryRight(s)),
                    ],
                  ),
                ],
              ),
            ),

            // “More” / “Less” pill notch
            Positioned(
              bottom: -_halfPill,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  width: _pillSize,
                  height: _pillSize,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: _borderWidth),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _expanded ? 'Less' : 'More',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // DETAILS PANEL (only when expanded)
      if (_expanded)
        Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(_innerRadius)),
          ),
          padding: EdgeInsets.only(
            top: _innerPad,
            bottom: _innerPad + _halfAction,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _padded(child: _buildSeatsRow(s)),
              const SizedBox(height: 16),
              _padded(child: _buildAddress()),
              const SizedBox(height: 16),
              _padded(child: _buildDescription()),
            ],
          ),
        ),
    ],
  );
}


  Widget _summaryLeft(event_summary.EventSummary s) => Column(
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
      );

  Widget _summaryRight(event_summary.EventSummary s) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            friendlySession(s.sessionType),
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text('Starts ${s.startTime}', style: const TextStyle(color: Colors.black54)),
          Text('Ends   ${s.endTime}', style: const TextStyle(color: Colors.black54)),
        ],
      );

  Widget _buildSeatsRow(event_summary.EventSummary s) => Row(
        children: [
          const Icon(Icons.event_seat, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('${s.availableSeats} Seats Available',
              style: const TextStyle(color: Colors.white)),
        ],
      );

  Widget _buildAddress() => FutureBuilder<EventDetail>(
        future: _detailFut,
        builder: (ctx, snap) {
          final addr = snap.data?.address ?? '';
          return Text(addr, style: const TextStyle(color: Colors.white));
        },
      );

  Widget _buildDescription() => FutureBuilder<EventDetail>(
        future: _detailFut,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2));
          }
          if (snap.hasError) {
            return const Text('Error loading details',
                style: TextStyle(color: Colors.redAccent));
          }
          return Text(snap.data!.description,
              style: const TextStyle(color: Colors.white70));
        },
      );

  Padding _padded({required Widget child}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: _innerPad),
        child: child,
      );

  Widget _buildActionButtons() {
    if (!_expanded) return const SizedBox.shrink();
    return Positioned(
      bottom: -_halfAction,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          //display book now button for any users that do not have managing permissions
          child: widget.canManage ? _buildCancelReserveRow() : _buildBookNowButton() ,
        ),
      ),
    );
  }

  Widget _buildBookNowButton() => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4C85D0),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        onPressed: () {
          if (widget.isUser) {
            Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BookingFlow(event: widget.summary)),
            );
          } else {
              _showRequireLoginModal(context); 
          }
        },
        child: const Text('BOOK NOW', style: TextStyle(color: Colors.white)),
      );

  Widget _buildCancelReserveRow() => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF9E9E9E),
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _cancelEvent,
              child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF4C85D0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () {},
              child: const Text('RESERVE', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );

  String _weekdayFull(DateTime d) {
    const week = [
      'Monday','Tuesday','Wednesday',
      'Thursday','Friday','Saturday','Sunday'
    ];
    return week[d.weekday - 1];
  }
}

void _showRequireLoginModal(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext context) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Login Required'),
              const Text('Please sign in to start booking events.'),
              ElevatedButton(
                child: const Text('Sign In'),
                onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginView()),
                    );
                  },
              ),
            ],
          ),
        ),
      );
    },
  );
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
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => Navigator.of(c).pop(),
              child: const Text('Close', style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
            ),
          ),
          const SizedBox(height: 8),
          const Icon(Icons.warning, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          const Text(
            'Event Cancellation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Are you sure you want to cancel?\nThis cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add explanation. This message will be sent to people with an active booking.',
              hintStyle: const TextStyle(color: Color.fromARGB(100, 0, 0, 0)),
              filled: true,
              fillColor: const Color.fromARGB(255, 255, 255, 255),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(c).pop(controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text(
                'CANCEL EVENT',
                style: TextStyle(color: Colors.white, letterSpacing: 1.2),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

