import 'dart:convert';

import 'package:corpsapp/models/event_summary.dart' as event_summary;
import 'package:corpsapp/services/auth_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../views/qr_scan_view.dart';

class QrScanFab extends StatefulWidget {
  final double diameter;
  final double borderWidth;
  final int? expectedEventId;

  const QrScanFab({
    super.key,
    required this.diameter,
    required this.borderWidth,
    this.expectedEventId,
  });

  @override
  State<QrScanFab> createState() => _QrScanFabState();
}

class _QrScanFabState extends State<QrScanFab>
    with SingleTickerProviderStateMixin {
  static const String _selectedEventPrefKey = 'qr_scan_selected_event_id';

  late final AnimationController _shimmerController;
  int? _selectedEventId;
  bool _selectionLoaded = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _initializeSelectionState();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedEventId() async {
    if (_selectionLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _selectedEventId = prefs.getInt(_selectedEventPrefKey);
    _selectionLoaded = true;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeSelectionState() async {
    await _loadSelectedEventId();
    await _refreshSelectedEventValidity();
  }

  Future<void> _setSelectedEventId(int eventId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedEventPrefKey, eventId);
    if (!mounted) return;
    setState(() => _selectedEventId = eventId);
  }

  Future<void> _clearSelectedEventId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedEventPrefKey);
    if (!mounted) return;
    setState(() => _selectedEventId = null);
  }

  Future<void> _refreshSelectedEventValidity() async {
    if (widget.expectedEventId != null) return;
    if (_selectedEventId == null) return;

    try {
      final events = await _getCurrentAvailableEvents();
      await _syncSelectedEventWithCurrent(events);
    } catch (e) {
      debugPrint('Unable to refresh selected QR event lock: $e');
    }
  }

  Future<List<_ActiveScanEvent>> _getCurrentAvailableEvents() async {
    final response = await AuthHttpClient.get('/api/events');
    if (response.statusCode != 200) return const <_ActiveScanEvent>[];

    final List<dynamic> events = jsonDecode(response.body) as List<dynamic>;
    final now = DateTime.now();
    final List<_ActiveScanEvent> currentEvents = <_ActiveScanEvent>[];

    for (final event in events) {
      if (event is! Map<String, dynamic>) continue;

      try {
        final int eventId = _toInt(event['eventId']);
        if (eventId <= 0) continue;

        final DateTime start = DateTime.parse(
          '${event['startDate']}T${event['startTime']}',
        );
        final DateTime endRaw = DateTime.parse(
          '${event['startDate']}T${event['endTime']}',
        );
        final DateTime adjustedEnd =
            endRaw.isBefore(start)
                ? endRaw.add(const Duration(days: 1))
                : endRaw;
        final event_summary.EventStatus status = event_summary.statusFromRaw(
          _toInt(event['status']),
        );
        final DateTime lockWindowEnd = adjustedEnd.add(
          const Duration(hours: 6),
        );

        // Selection is status-driven with Fallback window that hide event 6+ hours after its end time.
        if (status != event_summary.EventStatus.available ||
            !now.isBefore(lockWindowEnd)) {
          continue;
        }

        final String locationName =
            (event['locationName'] ?? 'Event #$eventId').toString().trim();
        final String sessionType = _sessionTypeLabel(event['sessionType']);
        final String dateLabel = DateFormat('EEE, d MMM yyyy').format(start);
        final String timeLabel = _formatTimeRange(start, adjustedEnd);

        currentEvents.add(
          _ActiveScanEvent(
            eventId: eventId,
            title: locationName.isEmpty ? 'Event #$eventId' : locationName,
            sessionLabel: sessionType == 'Session' ? '' : sessionType,
            dateLabel: dateLabel,
            timeLabel: timeLabel,
            start: start,
            end: adjustedEnd,
          ),
        );
      } catch (e) {
        debugPrint('Error parsing event for QR selector: $e');
      }
    }

    currentEvents.sort((a, b) {
      final bool aActive = now.isAfter(a.start) && now.isBefore(a.end);
      final bool bActive = now.isAfter(b.start) && now.isBefore(b.end);

      if (aActive != bActive) {
        return aActive ? -1 : 1;
      }

      if (aActive && bActive) {
        final int endCmp = a.end.compareTo(b.end);
        if (endCmp != 0) return endCmp;
      }

      // For non-active
      return a.start.compareTo(b.start);
    });

    return currentEvents;
  }

  Future<void> _syncSelectedEventWithCurrent(
    List<_ActiveScanEvent> events,
  ) async {
    await _loadSelectedEventId();
    final selected = _selectedEventId;
    if (selected == null) return;

    final bool stillActive = events.any((e) => e.eventId == selected);
    if (!stillActive) {
      await _clearSelectedEventId();
    }
  }

  Future<void> _openScanner() async {
    if (!mounted) return;

    int? eventIdForScan = widget.expectedEventId;

    if (eventIdForScan == null) {
      final activeEvents = await _getCurrentAvailableEvents();
      await _syncSelectedEventWithCurrent(activeEvents);

      if (activeEvents.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No available event found.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final selected = _selectedEventId;
      if (selected != null && activeEvents.any((e) => e.eventId == selected)) {
        eventIdForScan = selected;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hold scanner button to select an event first.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrScanView(expectedEventId: eventIdForScan),
      ),
    );
  }

  Future<void> _handleLongPress() async {
    HapticFeedback.mediumImpact();
    _shimmerController.repeat();

    try {
      final activeEvents = await _getCurrentAvailableEvents();
      await _syncSelectedEventWithCurrent(activeEvents);

      if (!mounted) return;
      if (activeEvents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No available events found.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final selectedEvent = await showModalBottomSheet<_ActiveScanEvent>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (ctx) => _EventLockSheet(
              events: activeEvents,
              selectedEventId: _selectedEventId,
            ),
      );

      if (selectedEvent == null) return;

      await _setSelectedEventId(selectedEvent.eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanner locked to selected event.'),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      _shimmerController.stop();
      _shimmerController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showSelectHint =
        widget.expectedEventId == null &&
        _selectionLoaded &&
        _selectedEventId == null;

    return GestureDetector(
      onLongPress: _handleLongPress,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color.fromARGB(255, 18, 18, 18),
            width: widget.borderWidth,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF512728),
              width: widget.borderWidth,
            ),
          ),
          child: SizedBox(
            width: widget.diameter,
            height: widget.diameter,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  heroTag: null,
                  backgroundColor: const Color(0xFFD01417),
                  elevation: 4,
                  onPressed: _openScanner,
                  shape: const CircleBorder(),
                  child: SvgPicture.asset(
                    'assets/icons/scanner.svg',
                    width: 32,
                    height: 32,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      if (!_shimmerController.isAnimating) {
                        return const SizedBox.shrink();
                      }
                      final slide = -1.8 + (_shimmerController.value * 3.6);
                      return ClipOval(
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment(slide - 0.5, -1),
                              end: Alignment(slide + 0.5, 1),
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.45),
                                Colors.transparent,
                              ],
                              stops: const [0.35, 0.5, 0.65],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcATop,
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_selectedEventId != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (_selectedEventId == null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amberAccent, width: 1),
                      ),
                      child: const Icon(
                        Icons.lock_open,
                        size: 11,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ),
                if (showSelectHint)
                  Positioned(
                    top: -30,
                    left: -8,
                    right: -8,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Text(
                            'HOLD TO SELECT EVENT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventLockSheet extends StatelessWidget {
  final List<_ActiveScanEvent> events;
  final int? selectedEventId;

  const _EventLockSheet({required this.events, required this.selectedEventId});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 24),
            child: child,
          ),
        );
      },
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Lock Scanner To Event',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'WinnerSans',
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Only available-status events are shown. You can change this later by long-pressing again.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(right: 12),
                    itemCount: events.length,
                    separatorBuilder:
                        (_, __) =>
                            const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (ctx, index) {
                      final item = events[index];
                      final bool selected = item.eventId == selectedEventId;
                      return ListTile(
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).pop(item),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.sessionLabel.isNotEmpty)
                              Text(
                                item.sessionLabel,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            Text(
                              item.dateLabel,
                              style: const TextStyle(color: Colors.white60),
                            ),
                            Text(
                              item.timeLabel,
                              style: const TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                        trailing:
                            selected
                                ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.greenAccent,
                                )
                                : Text(
                                  '#${item.eventId}',
                                  style: const TextStyle(color: Colors.white38),
                                ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveScanEvent {
  final int eventId;
  final String title;
  final String sessionLabel;
  final String dateLabel;
  final String timeLabel;
  final DateTime start;
  final DateTime end;

  const _ActiveScanEvent({
    required this.eventId,
    required this.title,
    required this.sessionLabel,
    required this.dateLabel,
    required this.timeLabel,
    required this.start,
    required this.end,
  });
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _sessionTypeLabel(dynamic raw) {
  final int value = _toInt(raw);
  switch (value) {
    case 0:
      return 'Ages 8 to 11';
    case 1:
      return 'Ages 12 to 15';
    case 2:
      return 'Ages 16+';
    default:
      return 'Session';
  }
}

String _formatTimeRange(DateTime start, DateTime end) {
  final String startText = DateFormat('h:mm a').format(start).toUpperCase();
  final String endText = DateFormat('h:mm a').format(end).toUpperCase();

  final bool crossesDay =
      start.year != end.year ||
      start.month != end.month ||
      start.day != end.day;

  if (crossesDay) {
    return '$startText - $endText (+1 day)';
  }
  return '$startText - $endText';
}
