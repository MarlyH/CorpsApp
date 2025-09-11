import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/views/login_view.dart';
import 'package:corpsapp/widgets/browser_help.dart';
import 'package:corpsapp/widgets/fab_create.dart';
import 'package:corpsapp/widgets/filter_sheet.dart';
import 'package:corpsapp/widgets/sliver_app_bar.dart';
import 'package:corpsapp/widgets/events_filter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../views/booking_flow.dart';
import '../views/create_event_view.dart';
import '../models/event_summary.dart' as event_summary;
import '../views/reserve_flow.dart';
import '../widgets/delayed_slide_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

/// Local model for /api/events/{id}
class EventDetail {
  final String description;
  final String address;
  EventDetail.fromJson(Map<String, dynamic> json)
    : description = json['description'] as String? ?? '',
      address = json['address'] as String? ?? '';
}

/// Date formatter for the summary tiles.
String _formatDate(DateTime d) {
  const week = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mon = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${week[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')} '
      '${mon[d.month - 1]} ${d.year}';
}

class HomeFragment extends StatefulWidget {
  const HomeFragment({super.key});
  @override
  _HomeFragmentState createState() => _HomeFragmentState();
}

class _HomeFragmentState extends State<HomeFragment> {
  late Future<List<event_summary.EventSummary>> _futureSummaries;
  int dropdownOpenTime = 0;

  String? _filterLocation;
  event_summary.SessionType? _filterSessionType;

  // four sort flags
  bool _dateAsc = true; // default: closest date first
  bool _dateDesc = false;
  bool _seatsAsc = false;
  bool _seatsDesc = false;

  @override
  void initState() {
    super.initState();
    _futureSummaries = _loadSummaries();
  }

  Future<List<event_summary.EventSummary>> _loadSummaries() async {
    final resp = await AuthHttpClient.getNoAuth('/api/events');
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

    DateTime eventEndDateTime(event_summary.EventSummary e) {
    // Be tolerant of formats like "09:30", "9:30", "9:30 AM"
    final t = (e.endTime).trim();
    final m = RegExp(r'^(\d{1,2})\s*:\s*(\d{2})\s*(AM|PM|am|pm)?').firstMatch(t);

    int hh = 0, mm = 0;
    String? ampm;

    if (m != null) {
      hh = int.tryParse(m.group(1) ?? '0') ?? 0;
      mm = int.tryParse(m.group(2) ?? '0') ?? 0;
      ampm = m.group(3);
    }

    // Handle 12-hour suffix if present
    if (ampm != null) {
      final mer = ampm.toLowerCase();
      if (mer == 'pm' && hh < 12) hh += 12;
      if (mer == 'am' && hh == 12) hh = 0;
    }

    final d = e.startDate; // assumed local date (no TZ)
    return DateTime(d.year, d.month, d.day, hh, mm);
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => SafeArea(
            child: FilterSheet(
              initialSession: _filterSessionType,
              initialDateAsc: _dateAsc,
              initialDateDesc: _dateDesc,
              initialSeatsAsc: _seatsAsc,
              initialSeatsDesc: _seatsDesc,
              onApply: (session, dateAsc, dateDesc, seatsAsc, seatsDesc) {
                setState(() {
                  _filterSessionType = session;
                  _dateAsc = dateAsc;
                  _dateDesc = dateDesc;
                  _seatsAsc = seatsAsc;
                  _seatsDesc = seatsDesc;
                });
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canManage = auth.isAdmin || auth.isEventManager;
    final isUser = auth.isUser;
    // final isGuest = !isUser || !canManage;

    final user = auth.userProfile ?? {};
    final bool isSuspended = (user['isSuspended'] as bool?) ?? false;

    // Try a few common keys for the end date; keep null-safe.
    DateTime? readDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }
    final DateTime? suspensionUntil = readDate(
      user['suspensionUntil'] ?? user['suspensionExpiresAt'] ?? user['suspensionEnd'],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: canManage ? CreateEventFAB() : null,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<event_summary.EventSummary>>(
          future: _futureSummaries,
          builder: (ctx, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final hasError = snap.hasError;
            final all = snap.data ?? [];

            // APPLY FILTERS (rely solely on status from backend)
            final now = DateTime.now();

            final events = all.where((e) {
              // keep only available events
              if (e.status != event_summary.EventStatus.Available) return false;

              // location/session filters
              if (_filterLocation != null && e.locationName != _filterLocation) return false;
              if (_filterSessionType != null && e.sessionType != _filterSessionType) return false;

              // EXCLUDE events that have finished
              if (!eventEndDateTime(e).isAfter(now)) return false;

              return true;
            }).toList()
              // sort using full start DateTime (date + time)
              ..sort((a, b) {
                final aStart = eventEndDateTime(a);
                final bStart = eventEndDateTime(b);

                if (_dateAsc) {
                  final c = aStart.compareTo(bStart);
                  if (c != 0) return c;
                } else if (_dateDesc) {
                  final c = bStart.compareTo(aStart);
                  if (c != 0) return c;
                }

                if (_seatsAsc) {
                  return a.availableSeatsCount.compareTo(b.availableSeatsCount);
                } else if (_seatsDesc) {
                  return b.availableSeatsCount.compareTo(a.availableSeatsCount);
                }

                return 0;
              }
            );

            final allLocations =
                all.map((e) => e.locationName).toSet().toList()..sort();

            return RefreshIndicator(
              color: Colors.white,
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  // STICKY FILTER BAR (hides on scroll down, snaps into view on slight up)
                  EventBrowserAppBar(
                    filterLocation: _filterLocation, 
                    onLocationChanged: (v) => setState(() => _filterLocation = v), 
                    allLocations: allLocations, 
                    //helpButton: (EventBrowserHelpButton()), 
                    onDropdownOpen: () {
                      setState(() {
                        dropdownOpenTime = DateTime.now().millisecondsSinceEpoch;
                      });
                    },
                  ),

                  SliverToBoxAdapter(
                    child: EventsFilter(
                      onTap: _showFilters,
                      filterSessionType: _filterSessionType,
                      friendlySession: friendlySession
                    ),
                  ),

                  // LOADING / ERROR / EMPTY
                  if (loading)
                    SliverFillRemaining(
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else if (hasError)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'Error: ${snap.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  else if (events.isEmpty)
                    SliverFillRemaining(
                      child: const Center(
                        child: Text(
                          'No sessions found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )

                  // SESSION LIST
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => EventTile(
                          summary: events[i],
                          isUser: isUser,
                          isSuspended: isSuspended,
                          suspensionUntil: suspensionUntil,
                          canManage: canManage,
                          //isGuest: isGuest,
                          loadDetail:
                              (id) => AuthHttpClient.getNoAuth(
                                '/api/events/$id',
                              ).then(
                                (r) => EventDetail.fromJson(jsonDecode(r.body)),
                              ),
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

// EVENT TILE
class EventTile extends StatefulWidget {
  final event_summary.EventSummary summary;
  final bool isUser, canManage;

  final bool isSuspended;
  final DateTime? suspensionUntil;

  final Future<EventDetail> Function(int) loadDetail;
  final VoidCallback onAction;

  const EventTile({
    super.key,
    required this.summary,
    required this.isUser,
    required this.canManage,
    required this.loadDetail,
    required this.onAction,
    required this.isSuspended,
    required this.suspensionUntil,
  });

  @override
  _EventTileState createState() => _EventTileState();
}


class _EventTileState extends State<EventTile> {
  bool _expanded = false;
  late Future<EventDetail> _detailFut;

  static const double _pillSize = 48.0;
  static const double _halfPill = _pillSize / 2;
  static const double _actionSize = 48.0;
  static const double _halfAction = _actionSize / 2;
  static const double _outerPadH = 16.0;
  static const double _outerPadB = 32.0;
  static const double _innerPad = 24.0;
  static const double _borderWidth = 4.0;
  static const double _outerRadius = 16.0;
  static const double _innerRadius = _outerRadius - _borderWidth;
  bool get _isFull => widget.summary.availableSeatsCount <= 0;
  // guard we only auto-clear once per “available” session render
  
  bool _isWaitlisted = false;
  bool _waitlistSubmitting = false;
  late final String _waitlistPrefKey;

  @override
  void initState() {
    super.initState();
    _detailFut = widget.loadDetail(widget.summary.eventId);

    // Build a stable per-user key so different users on the same device don't clash
    final auth = context.read<AuthProvider>();
    final uid = auth.userProfile?['email'] ??
                auth.userProfile?['userName'] ??
                'anon';
    _waitlistPrefKey = 'waitlist_${uid}_${widget.summary.eventId}';

    _loadWaitlistFlag();
  }

  bool _autoClearedBecauseNowAvailable = false;

  void _maybeAutoDisableWaitlist() {
    if (_autoClearedBecauseNowAvailable) return;
    if (!_isWaitlisted) return;
    if (widget.summary.availableSeatsCount > 0) {
      _autoClearedBecauseNowAvailable = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _setWaitlistEnabled(false);
      });
    }
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

  Future<void> _loadWaitlistFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_waitlistPrefKey) ?? false;
    if (!mounted) return;
    setState(() => _isWaitlisted = saved);
  }

  Future<bool> _setWaitlistEnabled(bool enable) async {
    final prefs = await SharedPreferences.getInstance();

    // TURN ON
    if (enable) {
      try {
        final r = await AuthHttpClient.joinWaitlist(widget.summary.eventId);
        if (r.statusCode == 200) {
          await prefs.setBool(_waitlistPrefKey, true);
          if (mounted) setState(() => _isWaitlisted = true);
          return true;
        }
        if (r.statusCode == 400) {
          final body = jsonDecode(r.body);
          final msg = (body['message'] as String?)?.toLowerCase() ?? '';
          final already = msg.contains('already') && msg.contains('waitlist');
          if (already) {
            await prefs.setBool(_waitlistPrefKey, true);
            if (mounted) setState(() => _isWaitlisted = true);
            return true;
          }
          // Seats still available (or other error) -> treat as failure
        }
        return false;
      } catch (_) {
        return false; // joining shouldntsilently succeed on network errors
      }
    }

    // TURN off
    // Optimistic local update first so the UI always lets the user opt out.
    await prefs.remove(_waitlistPrefKey);
    if (mounted) setState(() => _isWaitlisted = false);

    try {
      final r = await AuthHttpClient.leaveWaitlist(widget.summary.eventId);
      // 200 = removed, 404/400 = not on list already, also success
      return r.statusCode == 200 || r.statusCode == 404 || r.statusCode == 400;
    } catch (_) {
      // still keep the local “off”.
      return true; // idempotent-opt-out to trereat as success
    }
  }

  void _showNotifyOverlay({required bool isOn}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(.8),
      builder: (ctx) {
        bool working = false;
        bool done = false;
        String? error;
        final s = widget.summary;

        Future<void> _confirm(StateSetter setSB) async {
          setSB(() { working = true; error = null; });
          final ok = await _setWaitlistEnabled(!isOn);
          setSB(() {
            working = false;
            done = ok;
            if (!ok) error = 'Could not update notifications. Please try again.';
          }
        );
      }

      // const bgTop = Color(0xFF1A1B1E);
      // const bgBot = Color(0xFF111214);
      const border = Color(0x14FFFFFF);
      const titleStyle = TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      );
      const bodyStyle = TextStyle(color: Colors.white70, height: 1.35);
      const primary = Color(0xFF4C85D0);
      const danger  = Color(0xFFD01417);

      final detail =
          '${_weekdayFull(s.startDate)} • ${_formatDate(s.startDate)} • '
          '${s.startTime} @ ${s.locationName}';

      return StatefulBuilder(
        builder: (ctx, setSB) {
          final joining = !isOn;
          final iconData = joining ? Icons.block : Icons.notifications_off;
          final ctaLabel = joining ? 'JOIN WAITLIST' : 'LEAVE WAITLIST';
          final ctaColor = joining ? primary : danger;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.fromARGB(255, 0, 0, 0), Color.fromARGB(255, 0, 0, 0)],
                    ),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.45),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: done
                        // SUCCESS
                        ? Column(
                            key: const ValueKey('success'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('OK',
                                      style: TextStyle(color: Colors.white70)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // success icon
                              Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: primary, width: 2),
                                  color: primary.withOpacity(.08),
                                ),
                                child: Icon(
                                  joining ? Icons.notifications_active : Icons.check_circle,
                                  color: primary,
                                  size: 34,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                joining ? 'You’re on the waitlist' : 'Notifications turned off',
                                textAlign: TextAlign.center,
                                style: titleStyle,
                              ),
                              const SizedBox(height: 6),
                              Text(detail, textAlign: TextAlign.center, style: bodyStyle),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    shape: const StadiumBorder(),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('CLOSE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      )),
                                ),
                              ),
                            ],
                          )
                        // CONFIRM
                        : Column(
                            key: const ValueKey('confirm'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancel',
                                      style: TextStyle(color: Colors.white70)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // blue circle + slash icon
                              Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: primary,
                                    width: 2,
                                  ),
                                  color: primary.withOpacity(.08),
                                ),
                                child: Icon(iconData, color: primary, size: 34),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                joining ? 'No Seats Available' : 'Stop Notifications?',
                                textAlign: TextAlign.center,
                                style: titleStyle,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                joining
                                    ? "Don't worry! You may join the waitlist and we will inform you if a seat becomes available."
                                    : "You won’t receive alerts for this event anymore.",
                                textAlign: TextAlign.center,
                                style: bodyStyle,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event,
                                        size: 16, color: Colors.white70),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        detail,
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (error != null) ...[
                                const SizedBox(height: 10),
                                Text(error!,
                                    style: const TextStyle(
                                        color: danger, fontWeight: FontWeight.w600)),
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: working ? null : () => _confirm(setSB),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ctaColor,
                                    shape: const StadiumBorder(),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: working
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          ctaLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: .8,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  // notify button on event booked out
  Widget _notifyPill({
    required bool isOn,
    required bool busy,
    required VoidCallback onTap,
  }) {
    final main = isOn ? 'STOP NOTIFYING ME' : 'GET NOTIFIED';
    final sub  = isOn ? 'You won’t get alerts' : 'when seat is available';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF4C85D0),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  Icon(isOn ? Icons.notifications_off : Icons.notifications_active,
                      color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      main,
                      style: const TextStyle(
                        color: Colors.white,fontFamily: 'winnersans', fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(sub,
                      style: const TextStyle(color: Colors.white70, fontFamily: 'winnersans',fontSize: 10, height: 1.1)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _maybeAutoDisableWaitlist();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _outerPadH,
        _outerPadH,
        _outerPadH,
        _outerPadB,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _expanded = !_expanded),
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
            Padding(
              padding: const EdgeInsets.all(_borderWidth),
              child: _buildContentPanels(),
            ),

            // Action buttons when expanded
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

Widget _buildContentPanels() {
  final s = widget.summary;

  return Stack(
    clipBehavior: Clip.none, // allow notch to stick out
    children: [
      // Main content column: summary + details
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SUMMARY card
          ClipRRect(
            borderRadius: _expanded
                ? BorderRadius.vertical(top: Radius.circular(_innerRadius))
                : BorderRadius.circular(_innerRadius),
            child: Stack(
              clipBehavior: Clip.hardEdge, // keep overlays inside the card
              children: [
                // Card content
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: _innerPad,
                    vertical: _innerPad,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _summaryLeft(s)),
                      Expanded(child: _summaryRight(s)),
                    ],
                  ),
                ),

                // BOOKED OUT overlay
                if (_isFull)
                  const _CornerWedge(
                    inset: 0,
                    size: 80,
                    padding: 10,
                    perpPadding: 20,
                    text: 'BOOKED OUT',
                    showIcon: true,
                    icon: Icons.event_busy,
                    iconSize: 18,
                    iconTextGap: 4,
                  ),
              ],
            ),
          ),

          // DETAILS PANEL (only when expanded)
          if (_expanded)
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(_innerRadius),
                ),
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
      ),

      // “More / Less” notch — always on top
      Positioned(
        bottom: _expanded ? 138 : -_halfPill, // adjust as needed
        left: 0,
        right: 0,
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

  Widget _summaryRight(event_summary.EventSummary s) => Padding(
    padding: EdgeInsets.only(right: _isFull ? 0 : 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end, 
      children: [
        Text(friendlySession(s.sessionType),
            style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 8),
        Text('Starts ${s.startTime}', style: const TextStyle(color: Colors.black54)),
        Text('Ends   ${s.endTime}',   style: const TextStyle(color: Colors.black54)),
      ],
    ),
  );



  Widget _buildSeatsRow(event_summary.EventSummary s) => Row(
    children: [
      const Icon(Icons.event_seat, color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Text(
        '${s.availableSeatsCount} Seats Available',
        style: const TextStyle(color: Colors.white),
      ),
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
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        );
      }
      if (snap.hasError) {
        return const Text(
          'Error loading details',
          style: TextStyle(color: Colors.redAccent),
        );
      }
      return Text(
        snap.data!.description,
        style: const TextStyle(color: Colors.white70),
      );
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
          child:
              widget.canManage
                  ? _buildCancelReserveRow()
                  : _buildBookNowButton(),
        ),
      ),
    );
  }

  Widget _buildBookNowButton() {
    final s = widget.summary;
    final isSuspended =
        context.read<AuthProvider>().userProfile?['isSuspended'] == true;

    if (isSuspended) {
      return ElevatedButton(
        onPressed: () => _showSuspensionOverlay(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey, // disabled style
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: const Text('BOOK NOW (LOCKED)', style: TextStyle(
            fontFamily: 'WinnerSans',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      );
    }

    if (s.availableSeatsCount > 0) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4C85D0),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        onPressed: () {
          if (widget.isUser) {
            Navigator.push(context,
              MaterialPageRoute(builder: (_) => BookingFlow(event: widget.summary)));
          } else {
            _showRequireLoginModal(context);
          }
        },
        child: const Text('BOOK NOW',
          style: TextStyle(fontFamily: 'WinnerSans', color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }

    return _notifyPill(
      isOn: _isWaitlisted,
      busy: _waitlistSubmitting,
      onTap: () {
        if (!widget.isUser) { _showRequireLoginModal(context); return; }
        _showNotifyOverlay(isOn: _isWaitlisted);
      },
    );
  }

  void _showSuspensionOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bookings Locked', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your account is suspended for 90 days due to 3 attendance strikes. '
          'If you believe this is a mistake, you can submit an appeal from your Profile.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelReserveRow() => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFF9E9E9E),
            side: const BorderSide(color: Colors.grey),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: _cancelEvent,
          child: const Text('CANCEL', 
            style: const TextStyle(
              fontFamily: 'WinnerSans',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),

      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFF4C85D0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReserveFlow(eventId: widget.summary.eventId),
              ),
            );
          },
          child: const Text('RESERVE', 
            style: const TextStyle(
              fontFamily: 'WinnerSans',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );

  String _weekdayFull(DateTime d) {
    const week = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return week[d.weekday - 1];
  }


  void showSuspendedOverlay() {
    final until = widget.suspensionUntil;
    final now = DateTime.now();
    final daysLeft = until != null ? (until.difference(now).inDays).clamp(0, 9999) : null;

    final String details = until == null
        ? "Booking is suspended for 90 days from the date you received your third strike."
        : "Booking is suspended for 90 days from your third strike.\n"
          "Access will be restored on ${_formatDate(until)}"
          "${daysLeft != null ? " (${daysLeft} day${daysLeft == 1 ? '' : 's'} left)" : ""}.";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Booking Locked', style: TextStyle(color: Colors.white)),
        content: Text(
          "You have reached 3 attendance strikes.\n\n$details",
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
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
              const Text('Login Required', style: TextStyle(
                fontFamily: 'WinnerSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 8),
              const Text('Please sign in to start booking and'),
              const Text('getting notified for events.'),
              ElevatedButton(
                child: const Text('Sign In', style: TextStyle(
                  fontFamily: 'WinnerSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white
                )),
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const LoginView()));
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(c).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
                ),
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
              style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
              decoration: InputDecoration(
                hintText:
                    'Add explanation. This message will be sent to people with an active booking.',
                hintStyle: const TextStyle(color: Color.fromARGB(100, 0, 0, 0)),
                filled: true,
                fillColor: const Color.fromARGB(255, 255, 255, 255),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'CANCEL EVENT',
                  style: TextStyle(color: Colors.white, letterSpacing: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerWedge extends StatelessWidget {
  const _CornerWedge({
    this.size = 92,
    this.inset = 0,
    this.padding = 14,
    this.perpPadding = 6,
    this.centerText = true,
    this.color = const Color(0xFFD01417),
    this.text = 'BOOKED OUT',
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      letterSpacing: .6,
      fontSize: 11,
    ),
    this.showIcon = true,
    this.icon = Icons.event_busy,
    this.iconSize = 18,
    this.iconTextGap = 4,
    this.iconColor, // defaults to textStyle.color
  });

  final double size, inset, padding, perpPadding;
  final bool centerText;
  final Color color;
  final String text;
  final TextStyle textStyle;

  // NEW icon knobs
  final bool showIcon;
  final IconData? icon;
  final double iconSize;
  final double iconTextGap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: inset,
      right: inset,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CornerWedgePainter(
            color: color,
            text: text,
            textStyle: textStyle,
            padding: padding,
            perpPadding: perpPadding,
            centerText: centerText,
            showIcon: showIcon,
            icon: icon,
            iconSize: iconSize,
            iconTextGap: iconTextGap,
            iconColor: iconColor ?? textStyle.color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CornerWedgePainter extends CustomPainter {
  _CornerWedgePainter({
    required this.color,
    required this.text,
    required this.textStyle,
    required this.padding,
    this.perpPadding = 6,
    this.centerText = true,
    // NEW icon knobs
    this.showIcon = true,
    this.icon,
    this.iconSize = 18,
    this.iconTextGap = 4,
    this.iconColor = Colors.white,
  });

  final Color color;
  final String text;
  final TextStyle textStyle;
  final double padding;
  final double perpPadding;
  final bool centerText;

  final bool showIcon;
  final IconData? icon;
  final double iconSize;
  final double iconTextGap;
  final Color iconColor;

  @override
  void paint(Canvas canvas, Size s) {
    // Draw the triangular wedge in the top-right corner.
    final wedge = Path()
      ..moveTo(s.width, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(wedge, Paint()..color = color);

    // Keep all painting clipped inside the wedge.
    canvas.save();
    canvas.clipPath(wedge);

    // Diagonal line endpoints (inset from both corners).
    final start = Offset(padding, padding);
    final end   = Offset(s.width - padding, s.height - padding);

    final vx = end.dx - start.dx;
    final vy = end.dy - start.dy;
    final len = math.sqrt(vx*vx + vy*vy);

    // Unit directions: along the slope (u) and inward normal (n).
    final ux = vx / len,  uy = vy / len;
    final nx =  vy / len, ny = -vx / len;

    // Shift inward away from the slope by `perpPadding`.
    final startShifted = Offset(
      start.dx + nx * perpPadding,
      start.dy + ny * perpPadding,
    );

    // Rotate so +X runs along the slope.
    final angle = math.atan2(vy, vx);
    canvas.translate(startShifted.dx, startShifted.dy);
    canvas.rotate(angle);

    // --- Layout text
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(minWidth: 0, maxWidth: len);

    // --- Layout icon (as a font glyph so we can paint on canvas)
    TextPainter? ip;
    if (showIcon && icon != null) {
      ip = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon!.codePoint),
          style: TextStyle(
            fontFamily: icon!.fontFamily,
            package: icon!.fontPackage,
            fontSize: iconSize,
            color: iconColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final iconW = ip?.width ?? 0;
    final iconH = ip?.height ?? 0;
    final textW = tp.width;
    final textH = tp.height;

    // Group dimensions: stack icon above text (along +Y after rotation).
    final groupW = math.max(iconW, textW);
    final groupH = (ip != null ? iconH : 0) +
                   (ip != null && text.isNotEmpty ? iconTextGap : 0) +
                   (text.isNotEmpty ? textH : 0);

    // Center the whole group along the diagonal.
    final xGroup = centerText ? (len - groupW) / 2 : 0;

    // Paint icon (if any), centered within the group width.
    double yCursor = -groupH / 2;
    if (ip != null) {
      final xIcon = xGroup + (groupW - iconW) / 2;
      ip.paint(canvas, Offset(xIcon, yCursor));
      yCursor += iconH + iconTextGap;
    }

    // Paint text, centered within the group width.
    final xText = xGroup + (groupW - textW) / 2;
    tp.paint(canvas, Offset(xText, yCursor));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CornerWedgePainter old) =>
      old.color != color ||
      old.text != text ||
      old.textStyle != textStyle ||
      old.padding != padding ||
      old.perpPadding != perpPadding ||
      old.centerText != centerText ||
      old.showIcon != showIcon ||
      old.icon != icon ||
      old.iconSize != iconSize ||
      old.iconTextGap != iconTextGap ||
      old.iconColor != iconColor;
}