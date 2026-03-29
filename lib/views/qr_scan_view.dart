import 'dart:convert';
import 'package:corpsapp/models/event_summary.dart' as event_summary;
import 'package:corpsapp/models/medical_condition.dart';
import 'package:corpsapp/providers/auth_provider.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/medical_tile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_http_client.dart';
import 'package:collection/collection.dart';

class QrScanView extends StatefulWidget {
  const QrScanView({super.key});

  @override
  State<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends State<QrScanView> with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  bool _lockedOnResult = false;
  static const String _selectedEventPrefKey = 'qr_scan_selected_event_id';
  int? _selectedEventId;
  _ActiveScanEvent? _selectedEvent;
  bool _selectionLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSelectionState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller!.pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _controller!.resumeCamera();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _controller?.pauseCamera();
    _controller?.resumeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    final c = _controller;
    if (c != null) {
      try {
        c.pauseCamera();   
      } catch (_) {}

      try {
        c.dispose();
      } catch (_) {}
    }

    super.dispose();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    _controller = ctrl;  

    _controller!.scannedDataStream.listen((scanData) async {
      if (_lockedOnResult) return;
      final raw = scanData.code;
      if (raw == null || raw.isEmpty) return;

      _lockedOnResult = true;
      await _controller?.pauseCamera();
      await _handleScan(raw);
      _lockedOnResult = false;
    });
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

  Future<void> _clearSelectedEventId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedEventPrefKey);
    if (!mounted) return;
    setState(() => _selectedEventId = null);
  }

  Future<void> _refreshSelectedEventValidity() async {
  if (_selectedEventId == null) return;

  try {
    final events = await _getCurrentAvailableEvents();

    final match = events.firstWhereOrNull(
      (e) => e.eventId == _selectedEventId,
    );

    if (match == null) {
      await _clearSelectedEventId();
    } else {
      setState(() {
        _selectedEvent = match;
      });
    }
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

  Future<void> _handleScan(String rawPayload) async {
    final code = _extractQrCode(rawPayload);
    if (code == null) {
      await _showErrorSheet('Couldn’t read this QR code.');
      _controller?.resumeCamera();
      return;
    }

    try {
      final resp = await AuthHttpClient.post(
        '/api/booking/scan-info',
        body: {'qrCodeData': code},
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final detail = _BookingScanDetail.fromJson(data);

        if (_selectedEventId != null &&
            detail.eventId != _selectedEventId) {
          await _showErrorSheet(
            'This scanner is locked to event #$_selectedEventId. '
            'Scanned ticket belongs to event #${detail.eventId}.',
          );
          _controller?.resumeCamera();
          return;
        }

        if (!mounted) return;

        await _showResultSheet(detail);
      } else {
        final msg = _tryGetMessage(resp.body) ?? 'Booking not found (404).';
        if (!mounted) return;
        await _showErrorSheet(msg);
        _controller?.resumeCamera();
      }
    } catch (e) {
      if (!mounted) return;
      await _showErrorSheet('Network or parsing error.\n\n$e');
      _controller?.resumeCamera();
    }
  }

  String? _extractQrCode(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // JSON object payloads
    try {
      final m = jsonDecode(s);
      if (m is Map) {
        for (final k in ['qrCodeData', 'qr', 'code', 'id']) {
          final v = m[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
    } catch (_) {}

    // URLs
    try {
      final uri = Uri.parse(s);
      if (uri.hasQuery) {
        for (final k in ['qr', 'qrCodeData', 'code', 'id']) {
          final v = uri.queryParameters[k];
          if (v != null && v.trim().isNotEmpty) return v.trim();
        }
      }
      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last.trim();
        if (last.isNotEmpty) return last;
      }
    } catch (_) {}

    // Fallback raw token
    return s;
  }

  String? _tryGetMessage(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openEventLockSheet() async {
    final events = await _getCurrentAvailableEvents(); 

    if (!mounted) return;

    final selected = await showModalBottomSheet<_ActiveScanEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventLockSheet(
        events: events,
        selectedEventId: _selectedEventId,
      ),
    );

    if (selected != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_selectedEventPrefKey, selected.eventId);

      if (!mounted) return;
      setState(() {
        _selectedEventId = selected.eventId;
        _selectedEvent = selected; 
      });
    }
  }

  Future<void> _showErrorSheet(String message) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: AppPadding.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Scan Error',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Button(
                  label: 'Scan Again',
                  onPressed: () {
                    Navigator.pop(ctx);
                    _controller?.resumeCamera();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showResultSheet(_BookingScanDetail info) async {
    await showModalBottomSheet(
      barrierColor: Colors.white54,
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),

      builder: (ctx) {
        bool busy = false;
        _BookingScanDetail current = info;

        String primaryLabel(BookingStatusX s) {
          switch (s) {
            case BookingStatusX.booked:
              return 'Check In';
            case BookingStatusX.checkedIn:
              return 'Check Out';
            default:
              return 'No Action';
          }
        }

        bool primaryEnabled(BookingStatusX s) {
          return s == BookingStatusX.booked || s == BookingStatusX.checkedIn;
        }

        Future<void> doPrimary(StateSetter setSB) async {
          if (!primaryEnabled(current.status)) return;
          try {
            setSB(() => busy = true);
            final isCheckIn = current.status == BookingStatusX.booked;
            final path =
                isCheckIn ? '/api/booking/check-in' : '/api/booking/check-out';

            final resp = await AuthHttpClient.post(
              path,
              body: {'bookingId': current.bookingId},
            );
            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              final body = jsonDecode(resp.body) as Map<String, dynamic>;
              final statusText =
                  (body['status'] as String?) ??
                  (isCheckIn ? 'CheckedIn' : 'CheckedOut');
              final newStatus = _statusFromDynamic(statusText);
              setSB(() {
                current = current.copyWith(status: newStatus);
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isCheckIn ? 'Checked in.' : 'Checked out.'),
                  ),
                );
              }
            } else {
              final msg =
                  _tryGetMessage(resp.body) ??
                  'Action failed (HTTP ${resp.statusCode}).';
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: AppColors.errorColor,
                  ),
                );
              }
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Network error'),
                  backgroundColor: AppColors.errorColor,
                ),
              );
            }
          } finally {
            if (ctx.mounted) setSB(() => busy = false);
          }
        }

        return StatefulBuilder(
          builder: (ctx, setSB) {
            final enabled = primaryEnabled(current.status);
            final label = primaryLabel(current.status);
            final auth = context.watch<AuthProvider>();

            return SizedBox(
              height: 800,
              child: Padding(
                padding: AppPadding.screen,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed:
                                busy
                                    ? null
                                    : () {
                                      Navigator.pop(ctx);
                                      _controller?.resumeCamera();
                                    },
                            icon: Icon(
                              Icons.close_rounded,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // Title
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '#${current.seatNumber} ${current.attendeeName.toUpperCase()}',
                            style: TextStyle(
                              fontFamily: 'WinnerSans',
                              fontSize: 24,
                            ),
                          ),
                          Text(
                            current.sessionType!,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Button(
                        label: busy ? 'Working…' : label,
                        onPressed:
                            busy || !enabled ? null : () => doPrimary(setSB),
                      ),

                      const SizedBox(height: 16),

                      // Core details
                      Container(
                        width: double.infinity,
                        padding: AppPadding.screen,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Status:',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _statusChip(current.status),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(
                              height: 2,
                              color: Colors.black12,
                              thickness: 2,
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'Booking Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.normalText
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 8),

                            if ((current.address ?? '').isNotEmpty)
                              _kvRow('Address', current.address!),

                            const SizedBox(height: 4),

                            if ((current.locationName ?? '').isNotEmpty)
                              _kvRow('Location', current.locationName!),

                            const SizedBox(height: 4),

                            _kvRow('Date', current.eventDateText),

                            const SizedBox(height: 4),

                            _kvRow(
                              'Time',
                              '${current.startTime ?? '—'} - ${current.endTime ?? '—'}',
                            ),

                            const SizedBox(height: 4),

                            _kvRow(
                              'Ticket #',
                              current.seatNumber?.toString() ?? '—',
                            ),

                            const SizedBox(height: 4),

                            if (current.isForChild) ...[
                              _kvRow(
                                'MUST the attendee be picked up?',
                                current.canBeLeftAlone ? 'Yes' : 'No',
                              ),

                              const SizedBox(height: 16),
                              const Divider(
                                height: 2,
                                color: Colors.black12,
                                thickness: 2,
                              ),
                              const SizedBox(height: 8),

                              if (!auth.isUser || !auth.isGuest) ...[
                                Text(
                                  'Emergency Contact Info',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.normalText
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 8),

                                _kvRow(
                                  'Name',
                                  current.child!.emergencyContactName,
                                ),

                                const SizedBox(height: 4),

                                _kvRow(
                                  'Phone Number',
                                  current.child!.emergencyContactPhone,
                                ),

                                const SizedBox(height: 16),
                                const Divider(
                                  height: 2,
                                  color: Colors.black12,
                                  thickness: 2,
                                ),
                                const SizedBox(height: 8),

                                const SizedBox(height: 8),

                                Text(
                                  'Guardian Info',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.normalText
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 8),

                                //guardian information
                                _kvRow('Name', current.user!.fullName),
                                _kvRow(
                                  'Phone Number',
                                  current.user?.phoneNumber ?? '-',
                                ),
                                _kvRow('Email', current.user!.email ?? '-'),

                                const SizedBox(height: 16),
                                const Divider(
                                  height: 2,
                                  color: Colors.black12,
                                  thickness: 2,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],

                            //medical information
                            _medicalBlock(
                              title: 'Medical / Allergy Info',
                              hasAny:
                                  current.isForChild
                                      ? current.child!.hasMedicalConditions
                                      : current.user!.hasMedicalConditions,
                              items:
                                  current.isForChild
                                      ? current.child!.medicalConditions
                                      : current.user!.medicalConditions,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ====== Small UI helpers ======

  static Widget _kvRow(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  static Widget _statusChip(BookingStatusX status) {
    late Color bg, fg;
    late String label;

    switch (status) {
      case BookingStatusX.booked:
        label = 'Booked';
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1976D2);
        break;
      case BookingStatusX.checkedIn:
        label = 'Checked In';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case BookingStatusX.checkedOut:
        label = 'Checked Out';
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFEF6C00);
        break;
      case BookingStatusX.cancelled:
        label = 'Cancelled';
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
      case BookingStatusX.striked:
        label = 'Striked';
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontFamily: 'WinnerSans',
        ),
      ),
    );
  }

  // Medical block UI
  static Widget _medicalBlock({
    required String title,
    required bool hasAny,
    required List<MedicalCondition> items,
  }) {
    final hasItems = items.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black54,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (!hasAny || !hasItems)
          const Text(
            'None reported',
            style: TextStyle(
              color: Colors.black45,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                items
                    .map((m) => MedicalTile(m, useWhiteBackground: true))
                    .toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cutOut = MediaQuery.of(context).size.width * 0.8;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        await _controller?.pauseCamera();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: ProfileAppBar(title: 'Scan QR Code'),
        body: Padding(
          padding: AppPadding.screen.copyWith(bottom: bottomInset),
          child: Column(
            children: [
              Expanded(
                flex: 4,
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    overlayColor: AppColors.background,
                    borderColor: Colors.white,
                    borderRadius: 12,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: cutOut,
                  ),
                ),
              ),

              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    _lockedOnResult
                        ? 'HOLD ON…'
                        : 'ALIGN THE QR CODE WITHIN THE FRAME',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontFamily: 'WinnerSans',
                    ),
                  ),
                ),
              ),     

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.primaryColor, width: 1.5),
                    ),
                  ),
                  onPressed: _openEventLockSheet, 
                  child: Text(
                    _selectedEventId != null
                        ? 'Locked to event #$_selectedEventId ${_selectedEvent?.title} ${_selectedEvent?.sessionLabel} \n (CHANGE)'
                        : 'Select Event',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: "WinnerSans",
                    ),
                    textAlign: TextAlign.center,
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

/* ============================
 * Models for /api/booking/scan-info
 * (extended with Medical data)
 * ============================ */

enum BookingStatusX { booked, checkedIn, checkedOut, cancelled, striked }

BookingStatusX _statusFromDynamic(dynamic v) {
  if (v is int) {
    switch (v) {
      case 1:
        return BookingStatusX.checkedIn;
      case 2:
        return BookingStatusX.checkedOut;
      case 3:
        return BookingStatusX.cancelled;
      case 4:
        return BookingStatusX.striked;
      case 0:
      default:
        return BookingStatusX.booked;
    }
  }
  final s = v?.toString().toLowerCase() ?? '';
  switch (s) {
    case 'checkedin':
      return BookingStatusX.checkedIn;
    case 'checkedout':
      return BookingStatusX.checkedOut;
    case 'cancelled':
      return BookingStatusX.cancelled;
    case 'striked':
      return BookingStatusX.striked;
    case 'booked':
    default:
      return BookingStatusX.booked;
  }
}

String _yyyyMmDd(DateTime? d) {
  if (d == null) return '—';
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

class _ScanChildDto {
  final int childId;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final int age;

  // NEW: medical
  final bool hasMedicalConditions;
  final List<MedicalCondition> medicalConditions;

  _ScanChildDto({
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.age,
    required this.hasMedicalConditions,
    required this.medicalConditions,
  });

  factory _ScanChildDto.fromJson(Map<String, dynamic> j) {
    DateTime? parseDob(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      try {
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
          final p = s.split('-').map(int.parse).toList();
          return DateTime(p[0], p[1], p[2]);
        }
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    final medsRaw =
        (j['medicalConditions'] ?? j['MedicalConditions']) as List<dynamic>? ??
        const [];
    final meds =
        medsRaw
            .whereType<Map<String, dynamic>>()
            .map(MedicalCondition.fromJson)
            .toList();

    return _ScanChildDto(
      childId: (j['childId'] ?? j['ChildId'] ?? 0) as int,
      firstName: (j['firstName'] ?? j['FirstName'] ?? '').toString(),
      lastName: (j['lastName'] ?? j['LastName'] ?? '').toString(),
      dateOfBirth: parseDob(j['dateOfBirth'] ?? j['DateOfBirth']),
      emergencyContactName:
          (j['emergencyContactName'] ?? j['EmergencyContactName'] ?? '')
              .toString(),
      emergencyContactPhone:
          (j['emergencyContactPhone'] ?? j['EmergencyContactPhone'] ?? '')
              .toString(),
      age: (j['age'] ?? j['Age'] ?? 0) as int,
      hasMedicalConditions:
          (j['hasMedicalConditions'] ?? j['HasMedicalConditions']) == true ||
          meds.isNotEmpty,
      medicalConditions: meds,
    );
  }

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();
  String get dobText => _yyyyMmDd(dateOfBirth);
}

class _ScanUserMini {
  final String id;
  final String? email;
  final String? phoneNumber;
  final String firstName;
  final String lastName;
  final int attendanceStrikeCount;
  final String? dateOfLastStrike; // keep text for display
  final bool isSuspended;

  // NEW: medical
  final bool hasMedicalConditions;
  final List<MedicalCondition> medicalConditions;

  _ScanUserMini({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.attendanceStrikeCount,
    required this.dateOfLastStrike,
    required this.isSuspended,
    required this.hasMedicalConditions,
    required this.medicalConditions,
  });

  factory _ScanUserMini.fromJson(Map<String, dynamic> j) {
    final medsRaw =
        (j['medicalConditions'] ?? j['MedicalConditions']) as List<dynamic>? ??
        const [];
    final meds =
        medsRaw
            .whereType<Map<String, dynamic>>()
            .map(MedicalCondition.fromJson)
            .toList();

    return _ScanUserMini(
      id: (j['id'] ?? '').toString(),
      email: j['email']?.toString(),
      phoneNumber: j['phoneNumber']?.toString(),
      firstName: (j['firstName'] ?? '').toString(),
      lastName: (j['lastName'] ?? '').toString(),
      attendanceStrikeCount: (j['attendanceStrikeCount'] as int?) ?? 0,
      dateOfLastStrike: j['dateOfLastStrike']?.toString(),
      isSuspended: j['isSuspended'] == true,
      hasMedicalConditions:
          (j['hasMedicalConditions'] ?? j['HasMedicalConditions']) == true ||
          meds.isNotEmpty,
      medicalConditions: meds,
    );
  }

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();
}

class _BookingScanDetail {
  // Booking + Event
  final int bookingId;
  final int eventId;
  final String? eventName; // Location.Name per backend dto
  final DateTime? eventDate; // from DateOnly string "yyyy-MM-dd"
  final String? startTime; // "hh:mm"
  final String? endTime; // "hh:mm"
  final String? sessionType;
  final String? locationName;
  final String? address;

  // Booking fields
  final int? seatNumber;
  final BookingStatusX status;
  final bool canBeLeftAlone;
  final String qrCodeData;
  final bool isForChild;
  final String attendeeName;

  // Optional related
  final _ScanChildDto? child;
  final _ScanUserMini? user;

  _BookingScanDetail({
    required this.bookingId,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.sessionType,
    required this.locationName,
    required this.address,
    required this.seatNumber,
    required this.status,
    required this.canBeLeftAlone,
    required this.qrCodeData,
    required this.isForChild,
    required this.attendeeName,
    required this.child,
    required this.user,
  });

  String get eventDateText => DateFormat('d MMM, yyyy').format(eventDate!);

  _BookingScanDetail copyWith({BookingStatusX? status}) => _BookingScanDetail(
    bookingId: bookingId,
    eventId: eventId,
    eventName: eventName,
    eventDate: eventDate,
    startTime: startTime,
    endTime: endTime,
    sessionType: sessionType,
    locationName: locationName,
    address: address,
    seatNumber: seatNumber,
    status: status ?? this.status,
    canBeLeftAlone: canBeLeftAlone,
    qrCodeData: qrCodeData,
    isForChild: isForChild,
    attendeeName: attendeeName,
    child: child,
    user: user,
  );

  factory _BookingScanDetail.fromJson(Map<String, dynamic> j) {
    DateTime? parseDateOnly(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      try {
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
          final p = s.split('-').map(int.parse).toList();
          return DateTime(p[0], p[1], p[2]);
        }
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    return _BookingScanDetail(
      bookingId: (j['bookingId'] ?? 0) as int,
      eventId: (j['eventId'] ?? 0) as int,
      eventName: j['eventName']?.toString(),
      eventDate: parseDateOnly(j['eventDate']),
      startTime: j['startTime']?.toString(),
      endTime: j['endTime']?.toString(),
      sessionType: j['sessionType']?.toString(),
      locationName: j['locationName']?.toString(),
      address: j['address']?.toString(),
      seatNumber: j['seatNumber'] as int?,
      status: _statusFromDynamic(j['status']),
      canBeLeftAlone: j['canBeLeftAlone'] == true,
      qrCodeData: (j['qrCodeData'] ?? '').toString(),
      isForChild: j['isForChild'] == true,
      attendeeName: (j['attendeeName'] ?? '').toString(),
      child:
          j['child'] == null
              ? null
              : _ScanChildDto.fromJson(j['child'] as Map<String, dynamic>),
      user:
          j['user'] == null
              ? null
              : _ScanUserMini.fromJson(j['user'] as Map<String, dynamic>),
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
                'LOCK SCANNING TO AN EVENT',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'WinnerSans',
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Only available-status events are shown.',
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.sessionLabel.isNotEmpty)
                              Text(
                                item.sessionLabel,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

