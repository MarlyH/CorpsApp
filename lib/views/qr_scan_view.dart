import 'dart:convert';
import 'package:corpsapp/models/medical_condition.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/medical_tile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../services/auth_http_client.dart';

class QrScanView extends StatefulWidget {
  final int? expectedEventId; // optional filter (disables actions if mismatch)

  const QrScanView({super.key, this.expectedEventId});

  @override
  State<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends State<QrScanView> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  bool _lockedOnResult = false;
  bool _flashOn = false;

  @override
  void reassemble() {
    super.reassemble();
    _controller?.pauseCamera();
    _controller?.resumeCamera();
  }

  @override
  void dispose() {
    final c = _controller;
    if (c != null) {
      c.getFlashStatus().then((on) {
        if (on == true) c.toggleFlash();
      }).catchError((_) {});
    }
    _controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    _controller = ctrl;

    _controller!
        .getFlashStatus()
        .then((on) => mounted ? setState(() => _flashOn = on ?? false) : null)
        .catchError((_) {});

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

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.toggleFlash();
      final on = await c.getFlashStatus();
      if (mounted) setState(() => _flashOn = on ?? false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flash not available on this device'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
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
                    const Icon(Icons.error_outline, color: AppColors.errorColor, size: 20),
                    const SizedBox(width: 4),
                    const Text(
                      'Scan Error',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),

                Text(message, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),

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

        final bool wrongEvent =
            widget.expectedEventId != null && widget.expectedEventId != current.eventId;

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
          if (wrongEvent) return false;
          return s == BookingStatusX.booked || s == BookingStatusX.checkedIn;
        }

        Future<void> doPrimary(StateSetter setSB) async {
          if (!primaryEnabled(current.status)) return;
          try {
            setSB(() => busy = true);
            final isCheckIn = current.status == BookingStatusX.booked;
            final path = isCheckIn ? '/api/booking/check-in' : '/api/booking/check-out';

            final resp = await AuthHttpClient.post(path, body: {'bookingId': current.bookingId});
            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              final body = jsonDecode(resp.body) as Map<String, dynamic>;
              final statusText = (body['status'] as String?) ?? (isCheckIn ? 'CheckedIn' : 'CheckedOut');
              final newStatus = _statusFromDynamic(statusText);
              setSB(() {
                current = current.copyWith(status: newStatus);
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isCheckIn ? 'Checked in.' : 'Checked out.')),
                );
              }
            } else {
              final msg = _tryGetMessage(resp.body) ?? 'Action failed (HTTP ${resp.statusCode}).';
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg), backgroundColor: AppColors.errorColor),
                );
              }
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Network error'), backgroundColor: AppColors.errorColor),
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
                              busy ? null
                                   : () { Navigator.pop(ctx);
                                          _controller?.resumeCamera(); }, 
                            icon: Icon(Icons.close_rounded, fontWeight: FontWeight.bold,))  
                        ],
                      ),

                      // Title
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            current.attendeeName,
                            style: TextStyle(
                              fontFamily: 'WinnerSans',
                              fontSize: 24
                            ),
                          ), 
                          Text(
                            current.sessionType!,
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold
                            ),
                          ), 
                        ],
                      ),                                 

                      const SizedBox(height: 16),

                      if (wrongEvent) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            border: Border.all(color: AppColors.errorColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'This ticket is not for the current event.',
                            style: const TextStyle(
                              color: AppColors.errorColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 16
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Button(
                        label: busy ? 'Working…' : label, 
                        onPressed: busy || !enabled ? null : () => doPrimary(setSB)
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [   
                          
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Status:',
                                    style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                _statusChip(current.status),
                              ],
                            ),                           

                            const SizedBox(height: 16),
                            const Divider(height: 2, color: Colors.black12, thickness: 2),
                            const SizedBox(height: 16),
                             
                            if ((current.address ?? '').isNotEmpty)
                              _kvRow('Address', current.address!),

                            const SizedBox(height: 4),

                            if ((current.locationName ?? '').isNotEmpty)
                              _kvRow('Location', current.locationName!),

                            const SizedBox(height: 4),
                            
                            _kvRow('Date', current.eventDateText),

                            const SizedBox(height: 4),

                            _kvRow('Time', '${current.startTime ?? '—'} - ${current.endTime ?? '—'}'),

                            const SizedBox(height: 4),

                            _kvRow('Ticket', current.seatNumber?.toString() ?? '—'),

                            const SizedBox(height: 4),

                            if (current.isForChild) ... [
                              _kvRow(
                                'MUST the attendee be picked up?',
                                current.canBeLeftAlone ?  'Yes' : 'No' ,
                              ),
                               const SizedBox(height: 16),
                              const Divider(height: 2, color: Colors.black12, thickness: 2),
                              const SizedBox(height: 16),

                              _kvRow('Emergency Contact', current.child!.emergencyContactName),

                              const SizedBox(height: 4),

                              _kvRow('Emergency Phone', current.child!.emergencyContactPhone),

                              const SizedBox(height: 16),
                              const Divider(height: 2, color: Colors.black12, thickness: 2),
                              const SizedBox(height: 16),  
                          
                              //guardian information
                              _kvRow('Guardian', current.user!.fullName),
                              _kvRow('Phone Number', current.user?.phoneNumber ?? '-'),
                              _kvRow('Email', current.user!.email ?? '-'),
                            ],

                            const SizedBox(height: 16),
                            const Divider(height: 2, color: Colors.black12, thickness: 2),
                            const SizedBox(height: 16),  

                            //medical information
                            _medicalBlock(
                              title: 'Medical / Allergy Info',
                              hasAny: current.isForChild ? current.child!.hasMedicalConditions : current.user!.hasMedicalConditions,
                              items: current.isForChild ? current.child!.medicalConditions : current.user!.medicalConditions,
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
            style: const TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold)
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontFamily: 'WinnerSans')),
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
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 16)),
        const SizedBox(height: 8),
        if (!hasAny || !hasItems)
          const Text('None reported',
              style: TextStyle(color: Colors.black45, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, fontSize: 14))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((m) => MedicalTile(m, useWhiteBackground: true)).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cutOut = MediaQuery.of(context).size.width * 0.8;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Scan QR Code'),
      body: Padding(
        padding: AppPadding.screen,
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
                      ? 'Hold on…'
                      : (widget.expectedEventId == null
                          ? 'Align the QR code inside the box'
                          : 'Scanning for event #${widget.expectedEventId}…'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontFamily: 'WinnerSans',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Keep FAB within padding bounds
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          right: AppPadding.screen.right,
          bottom: AppPadding.screen.bottom + bottomInset + 32,
        ),
        child: FloatingActionButton(
          heroTag: 'qr_flash_fab',
          onPressed: _toggleFlash,
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          tooltip: _flashOn ? 'Turn Flash Off' : 'Turn Flash On',
          child: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
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

    final medsRaw = (j['medicalConditions'] ?? j['MedicalConditions']) as List<dynamic>? ?? const [];
    final meds = medsRaw
        .whereType<Map<String, dynamic>>()
        .map(MedicalCondition.fromJson)
        .toList();

    return _ScanChildDto(
      childId: (j['childId'] ?? j['ChildId'] ?? 0) as int,
      firstName: (j['firstName'] ?? j['FirstName'] ?? '').toString(),
      lastName: (j['lastName'] ?? j['LastName'] ?? '').toString(),
      dateOfBirth: parseDob(j['dateOfBirth'] ?? j['DateOfBirth']),
      emergencyContactName: (j['emergencyContactName'] ?? j['EmergencyContactName'] ?? '').toString(),
      emergencyContactPhone: (j['emergencyContactPhone'] ?? j['EmergencyContactPhone'] ?? '').toString(),
      age: (j['age'] ?? j['Age'] ?? 0) as int,
      hasMedicalConditions: (j['hasMedicalConditions'] ?? j['HasMedicalConditions']) == true || meds.isNotEmpty,
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
    final medsRaw = (j['medicalConditions'] ?? j['MedicalConditions']) as List<dynamic>? ?? const [];
    final meds = medsRaw
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
      hasMedicalConditions: (j['hasMedicalConditions'] ?? j['HasMedicalConditions']) == true || meds.isNotEmpty,
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
      child: j['child'] == null
          ? null
          : _ScanChildDto.fromJson(j['child'] as Map<String, dynamic>),
      user: j['user'] == null
          ? null
          : _ScanUserMini.fromJson(j['user'] as Map<String, dynamic>),
    );
  }
}
