import 'dart:convert';
import 'package:flutter/material.dart';
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

  // Palette & shared buttons
  static const _primary = Color(0xFF4C85D0);
  static const _muted = Color(0xFF9E9E9E);
  static const _outline = Colors.white24;

  ButtonStyle _pillPrimary() => ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'WinnerSans',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ).merge(
        ButtonStyle(minimumSize: MaterialStateProperty.all(const Size.fromHeight(44))),
      );

  ButtonStyle _pillMuted() => ElevatedButton.styleFrom(
        backgroundColor: _muted,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'WinnerSans',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ).merge(
        ButtonStyle(minimumSize: MaterialStateProperty.all(const Size.fromHeight(44))),
      );

  ButtonStyle _pillOutline() => OutlinedButton.styleFrom(
        side: const BorderSide(color: _outline),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'WinnerSans',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ).merge(
        ButtonStyle(minimumSize: MaterialStateProperty.all(const Size.fromHeight(44))),
      );

  // Hot-reload camera fix
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
          backgroundColor: Colors.redAccent,
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
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Scan Error',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _controller?.resumeCamera();
                        },
                        style: _pillOutline(),
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scan Again'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          final c = _controller;
                          if (c != null) {
                            c.getFlashStatus().then((on) {
                              if (on == true) c.toggleFlash();
                            });
                          }
                          Navigator.pop(context);
                        },
                        style: _pillMuted(),
                        icon: const Icon(Icons.close, size: 18, color: Colors.white),
                        label: const Text('Cancel'),
                      ),
                    ),
                  ],
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool busy = false;
        _BookingScanDetail current = info;

        final bool wrongEvent = widget.expectedEventId != null && widget.expectedEventId != current.eventId;

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

        IconData primaryIcon(BookingStatusX s) {
          switch (s) {
            case BookingStatusX.booked:
              return Icons.login;
            case BookingStatusX.checkedIn:
              return Icons.logout;
            default:
              return Icons.block;
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
                  SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
                );
              }
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Network error'), backgroundColor: Colors.redAccent),
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
            final icon = primaryIcon(current.status);

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Row(
                        children: const [
                          Icon(Icons.qr_code_scanner, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Booking Details',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (wrongEvent) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            border: Border.all(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'This booking is for event #${current.eventId}, not the expected '
                            '#${widget.expectedEventId}. Actions are disabled.',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'WinnerSans',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Core details
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _kvRow('Attendee', current.attendeeName),
                            if ((current.eventName ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _kvRow('Event', current.eventName!),
                            ],
                            const SizedBox(height: 8),
                            _kvRow('Event ID', '#${current.eventId}'),
                            if ((current.locationName ?? '').isNotEmpty)
                              _kvRow('Location', current.locationName!),
                            if ((current.address ?? '').isNotEmpty)
                              _kvRow('Address', current.address!),
                            _kvRow('Session', current.sessionType ?? '—'),
                            _kvRow('Date', current.eventDateText),
                            _kvRow('Time', '${current.startTime ?? '—'} - ${current.endTime ?? '—'}'),
                            _kvRow('Seat', current.seatNumber?.toString() ?? '—'),

                            
                            if (current.isForChild)
                              _kvRow('Can Be Left Alone', current.canBeLeftAlone ? 'Yes' : 'No'),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text('Status:', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                _statusChip(current.status),
                              ],
                            ),

                          ],
                        ),
                      ),

                      // Child block
                      if (current.child != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Child', style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              _kvRow('Name', current.child!.fullName),
                              _kvRow('DOB', current.child!.dobText),
                              _kvRow('Age', '${current.child!.age}'),
                              _kvRow('Emergency', '${current.child!.emergencyContactName} • ${current.child!.emergencyContactPhone}'),
                            ],
                          ),
                        ),
                      ],

                      // User mini block
                      if (current.user != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('User', style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              _kvRow('Name', current.user!.fullName),
                              _kvRow('Email', current.user!.email ?? '—'),
                              _kvRow('Strikes', '${current.user!.attendanceStrikeCount}'
                                  '${current.user!.isSuspended ? ' (SUSPENDED)' : ''}'),
                              if (current.user!.dateOfLastStrike != null)
                                _kvRow('Last Strike', current.user!.dateOfLastStrike!),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Actions
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: busy || !enabled ? null : () => doPrimary(setSB),
                              style: _pillPrimary(),
                              icon: busy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(icon, size: 16, color: Colors.white),
                              label: Text(busy ? 'Working…' : label),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () {
                                          Navigator.pop(ctx);
                                          final c = _controller;
                                          if (c != null) {
                                            c.getFlashStatus().then((on) {
                                              if (on == true) c.toggleFlash();
                                            });
                                          }
                                          Navigator.pop(context);
                                        },
                                  style: _pillMuted(),
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                  label: const Text('Cancel',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'WinnerSans', fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () {
                                          Navigator.pop(ctx);
                                          _controller?.resumeCamera();
                                        },
                                  style: _pillOutline(),
                                  icon: const Icon(Icons.qr_code_scanner, size: 16, color: Colors.white),
                                  label: const Text('Scan Again',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'WinnerSans', fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  // UI helpers

  static Widget _kvRow(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(k, style: const TextStyle(color: Colors.black54, fontFamily: 'WinnerSans')),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontFamily: 'WinnerSans'),
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
        label = 'CheckedIn';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case BookingStatusX.checkedOut:
        label = 'CheckedOut';
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
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontFamily: 'WinnerSans')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cutOut = MediaQuery.of(context).size.width * 0.8;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'WinnerSans'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: Colors.white,
                borderRadius: 12,
                borderLength: 30,
                borderWidth: 8,
                cutOutSize: cutOut,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                _lockedOnResult
                    ? 'Hold on…'
                    : (widget.expectedEventId == null
                        ? 'Align the QR code inside the box.'
                        : 'Scanning for event #${widget.expectedEventId}…'),
                style: const TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'WinnerSans'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + 32),
        child: FloatingActionButton(
          heroTag: 'qr_flash_fab',
          onPressed: _toggleFlash,
          backgroundColor: _primary,
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

  _ScanChildDto({
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.age,
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

    return _ScanChildDto(
      childId: (j['childId'] ?? j['ChildId'] ?? 0) as int,
      firstName: (j['firstName'] ?? j['FirstName'] ?? '').toString(),
      lastName: (j['lastName'] ?? j['LastName'] ?? '').toString(),
      dateOfBirth: parseDob(j['dateOfBirth'] ?? j['DateOfBirth']),
      emergencyContactName: (j['emergencyContactName'] ?? j['EmergencyContactName'] ?? '').toString(),
      emergencyContactPhone: (j['emergencyContactPhone'] ?? j['EmergencyContactPhone'] ?? '').toString(),
      age: (j['age'] ?? j['Age'] ?? 0) as int,
    );
  }

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();
  String get dobText => _yyyyMmDd(dateOfBirth);
}

class _ScanUserMini {
  final String id;
  final String? email;
  final String firstName;
  final String lastName;
  final int attendanceStrikeCount;
  final String? dateOfLastStrike; // keep text for display
  final bool isSuspended;

  _ScanUserMini({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.attendanceStrikeCount,
    required this.dateOfLastStrike,
    required this.isSuspended,
  });

  factory _ScanUserMini.fromJson(Map<String, dynamic> j) => _ScanUserMini(
        id: (j['id'] ?? '').toString(),
        email: j['email']?.toString(),
        firstName: (j['firstName'] ?? '').toString(),
        lastName: (j['lastName'] ?? '').toString(),
        attendanceStrikeCount: (j['attendanceStrikeCount'] as int?) ?? 0,
        dateOfLastStrike: j['dateOfLastStrike']?.toString(),
        isSuspended: j['isSuspended'] == true,
      );

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

  String get eventDateText => _yyyyMmDd(eventDate);

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
      child: j['child'] == null ? null : _ScanChildDto.fromJson(j['child'] as Map<String, dynamic>),
      user: j['user'] == null ? null : _ScanUserMini.fromJson(j['user'] as Map<String, dynamic>),
    );
  }
}
