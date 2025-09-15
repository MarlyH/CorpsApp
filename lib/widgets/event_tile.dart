import 'dart:convert';
import 'package:corpsapp/cancellation_dialog.dart';
import 'package:corpsapp/fragments/home_fragment.dart';
import 'package:corpsapp/models/event_summary.dart' as event_summary;
import 'package:corpsapp/providers/auth_provider.dart';
import 'package:corpsapp/services/auth_http_client.dart';
import 'package:corpsapp/views/booking_flow.dart';
import 'package:corpsapp/views/reserve_flow.dart';
import 'package:corpsapp/widgets/corner_wedge.dart';
import 'package:corpsapp/widgets/login_modal.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      builder: (_) => CancellationDialog(controller: ctrl),
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
                  margin: const EdgeInsets.symmetric(horizontal: 50),
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
        //event tiles list padding
        0,
        _outerPadH,
        0,
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
                  const CornerWedge(
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
        Text(event_summary.friendlySession(s.sessionType),
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
            showModalBottomSheet<void>(
              context: context,
              builder: (_) => const RequireLoginModal(),
            );
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
        if (!widget.isUser) { 
          showModalBottomSheet<void>(
            context: context,
            builder: (_) => const RequireLoginModal(),
          );
          return; 
        }
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
          "${daysLeft != null ? " ($daysLeft day${daysLeft == 1 ? '' : 's'} left)" : ""}.";

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
  
}