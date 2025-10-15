import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/widgets/EventExpandableCard/event_details.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/fragments/home_fragment.dart';
import 'package:corpsapp/models/event_summary.dart' as event_summary;
import 'package:corpsapp/providers/auth_provider.dart';
import 'package:corpsapp/services/auth_http_client.dart';
import 'package:corpsapp/views/booking_flow.dart';
import 'package:corpsapp/views/reserve_flow.dart';
import 'package:corpsapp/widgets/EventExpandableCard/event_summary.dart';
import 'package:corpsapp/widgets/login_modal.dart';
import 'package:corpsapp/widgets/Modals/event_cancellation.dart';
import 'package:corpsapp/widgets/snackbox.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


class EventTile extends StatefulWidget {
  final event_summary.EventSummary summary;
  final bool isUser, canManage, isStaff;

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
    required this.isStaff
  });

  @override
  EventTileState createState() => EventTileState();
}


class EventTileState extends State<EventTile> {
  bool _expanded = false;
  late Future<EventDetail> _detailFut;

  static const double _actionSize = 48.0;
  static const double _halfAction = _actionSize / 2;

  bool get _isFull => widget.summary.availableSeatsCount <= 0;
  // guard we only auto-clear once per “available” session render
  
  bool _isWaitlisted = false;
  final bool _waitlistSubmitting = false;
  late final String _waitlistPrefKey;
  bool _autoClearedBecauseNowAvailable = false;


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
    final msg = await showModalBottomSheet<String>(
      isDismissible: false,
      isScrollControlled: true, 
      context: context,
      builder: (_) => EventCancellationModal(controller: ctrl),
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
            backgroundColor: AppColors.errorColor,
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
    builder: (ctx) {
      bool working = false;
      final s = widget.summary;

      Future<void> confirm(StateSetter setSB) async {
        setSB(() {
          working = true;
        });

        final ok = await _setWaitlistEnabled(!isOn);

        setSB(() {
          working = false;
        });

        // Show the appropriate SnackBar after closing the dialog
        if (ok) {
          final joining = !isOn;
          CustomSnackBar.show(
            context: context,
            dialogContext: ctx,
            icon: joining ? 'assets/icons/notify.svg' : 'assets/icons/success.svg',
            message: joining ? "You've joined the waitlist!" : "You've left the waitlist.",
          );
        } else {
          // ERROR: show SnackBar after dialog closes
          CustomSnackBar.show(
            context: context,
            dialogContext: ctx,
            message: 'Could not update notifications. Please try again.'
          );        
        }
      }

      return StatefulBuilder(
        builder: (ctx, setSB) {
          final joining = !isOn;

          return CustomAlertDialog(
            title: joining ? 'No Available Seats' : 'Leave Waitlist',
            info: joining
                ? "Don't worry! You may join the waitlist and we will inform you if a seat becomes available."
                : "You won't receive alerts for this event anymore.",
            extraContentText:
                '${friendlySession(s.sessionType)} • ${_formatDate(s.startDate)} • ${s.startTime} @ ${s.locationName}',
            buttonLabel: joining ? 'JOIN WAITLIST' : 'LEAVE WAITLIST',
            buttonAction: working ? null : () => confirm(setSB),
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

    final main = isOn ? 'Leave Waitlist' : 'Join Waitlist';

    return Button(
      label: main, 
      onPressed: onTap,
      loading: busy,
      radius: 100,
    );
}

  @override
  Widget build(BuildContext context) {
    _maybeAutoDisableWaitlist();

    return Padding(
      padding: EdgeInsets.fromLTRB(0,8,0, _expanded ? 32 : 16),

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
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(3),
              child: _buildContentPanels(),
            ),

            // Action buttons when expanded
            if(!widget.isStaff)
              _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildContentPanels() {
    final s = widget.summary;

    return Stack(
      children: [
        // Main content column: summary + details
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SUMMARY card
            EventSummaryCard(summary: s, isFull: _isFull, isExpanded: _expanded),

            // DETAILS PANEL (only when expanded)
            if (_expanded)
              EventDetailsCard(summary: s, detailFut: _detailFut),           
          ],
        ),
      ],
    );
  }

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

    //do not allow user to make bookings or join waitlsit if suspended
    if (isSuspended) {
      return Button(
        label: s.availableSeatsCount > 0 ? 'Book Now': 'Join Waitlist', 
        onPressed: () => _showSuspensionOverlay(context, DateTime.now().add(Duration(days: 90))),
        buttonColor: AppColors.disabled,
        radius: 100,
      );
    }

    //if there are available seats allow users to book
    if (s.availableSeatsCount > 0) {
      return Button(
        label: 'Book Now', 
        onPressed: () {
          if (widget.isUser) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BookingFlow(event: widget.summary)));
          } else {
            showModalBottomSheet<void>(
              context: context,
              builder: (_) => const RequireLoginModal(),
            );
          }
        },        
        radius: 100,
      );
    }

    //if there are no available seats, allow users to join waitlist
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

  void _showSuspensionOverlay(BuildContext context, DateTime unsuspendDate) {
    final formattedDate = DateFormat('MMM d, yyyy').format(unsuspendDate);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CustomAlertDialog(
        title: 'Account Suspended Till $formattedDate',
        info: 'Your account is suspended from booking events due to 3 attendance strikes. '
            'If you believe this is a mistake, you can submit an appeal through Profile -> Appeal Ban.',
      ),
    );
  }

  Widget _buildCancelReserveRow() => Row(
    children: [
      Expanded(
        child: Button(
          label: 'Cancel', 
          onPressed: _cancelEvent,
          buttonColor: AppColors.disabled,
          radius: 100,
        ),
      ),

      const SizedBox(width: 8),

      Expanded(
        child: Button(
          label: 'Reserve', 
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReserveFlow(eventId: widget.summary.eventId),
              ),
            );
          },
          radius: 100,
        )
      )
    ],
  );
  
  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final eventDate = d.day.toString(); 
    final eventMonth = months[d.month - 1];
    final eventYear = d.year;
    
    return '$eventMonth $eventDate, $eventYear';
  } 


  String formatTime(String time) {
    // Parse from "HH:mm:ss"
    final parsed = DateFormat("HH:mm:ss").parse(time);
    // Format to "hh:mm a" -> 12-hour with AM/PM
    return DateFormat("hh:mma").format(parsed);
  }
}