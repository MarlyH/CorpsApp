import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../services/auth_http_client.dart';

class QrScanView extends StatefulWidget {
  final int? expectedEventId; // optional, can leave null

  const QrScanView({super.key, this.expectedEventId});

  @override
  State<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends State<QrScanView> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  bool _lockedOnResult = false;
  bool _flashOn = false; // flash state for FAB icon

  // App palette & button styles
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


  // Fix camera on hot reload
  @override
  void reassemble() {
    super.reassemble();
    _controller?.pauseCamera();
    _controller?.resumeCamera();
  }

  @override
  void dispose() {
    // Best-effort: turn off flash when leaving
    final c = _controller;
    if (c != null) {
      c
          .getFlashStatus()
          .then((on) {
            if (on == true) c.toggleFlash();
          })
          .catchError((_) {});
    }
    _controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    _controller = ctrl;

    // Initialize flash state (ignore errors on devices w/o flash)
    _controller!
        .getFlashStatus()
        .then((on) {
          if (mounted) setState(() => _flashOn = on ?? false);
        })
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
        final info = _BookingScanInfo.fromJson(data);
        if (!mounted) return;
        await _showResultSheet(info);
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

    // JSON payloads
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

    // raw token
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
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
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
                          // Turn off flash if on, then leave
                          final c = _controller;
                          if (c != null) {
                            c.getFlashStatus().then((on) {
                              if (on == true) c.toggleFlash();
                            });
                          }
                          Navigator.pop(context);
                        },
                        style: _pillMuted(),
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
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

  Future<void> _showResultSheet(_BookingScanInfo info) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool busy = false;
        _BookingScanInfo current = info;

        final bool wrongEvent =
            widget.expectedEventId != null &&
            widget.expectedEventId != current.eventId;

        String primaryLabel(String status) {
          switch (status) {
            case 'Booked':
              return 'Check In';
            case 'CheckedIn':
              return 'Check Out';
            default:
              return 'No Action';
          }
        }

        IconData primaryIcon(String status) {
          switch (status) {
            case 'Booked':
              return Icons.login;
            case 'CheckedIn':
              return Icons.logout;
            default:
              return Icons.block;
          }
        }

        bool primaryEnabled(String status) {
          if (wrongEvent) return false;
          return status == 'Booked' || status == 'CheckedIn';
        }

        Future<void> doPrimary(StateSetter setSB) async {
          if (!primaryEnabled(current.status)) return;

          try {
            setSB(() => busy = true);
            final isCheckIn = current.status == 'Booked';
            final path =
                isCheckIn ? '/api/booking/check-in' : '/api/booking/check-out';

            final resp = await AuthHttpClient.post(
              path,
              body: {'bookingId': current.bookingId},
            );

            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              final body = jsonDecode(resp.body) as Map<String, dynamic>;
              final newStatus =
                  (body['status'] as String?) ??
                  (isCheckIn ? 'CheckedIn' : 'CheckedOut');

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
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Network error'),
                  backgroundColor: Colors.redAccent,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Row(
                      children: const [
                        Icon(Icons.qr_code_scanner, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Booking Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                          'This booking is for event #${current.eventId}, not the expected event '
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

                    // Details card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kvRow('Attendee', current.attendeeName),
                          const SizedBox(height: 8),
                          _kvRow('Event ID', '#${current.eventId}'),
                          _kvRow('Session', current.sessionType ?? '—'),
                          _kvRow('Date', current.date ?? '—'),
                          _kvRow(
                            'Time',
                            '${current.startTime ?? '—'} - ${current.endTime ?? '—'}',
                          ),
                          _kvRow('Seat', current.seatNumber?.toString() ?? '—'),
                          const SizedBox(height: 12),
                          Row(
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Actions (responsive: primary full width, then two secondary side-by-side)
                    Column(
                      children: [
                        // Primary (Check In / Check Out / No Action) — full width
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

                        // Secondary row: Cancel + Scan Again
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () {
                                        Navigator.pop(ctx);
                                        // turn off flash if on, then exit
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
                                label: const Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'WinnerSans', fontSize: 12),
                                ),
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
                                label: const Text(
                                  'Scan Again',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'WinnerSans', fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  ],
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
          child: Text(
            k,
            style: const TextStyle(
              color: Colors.black54,
              fontFamily: 'WinnerSans',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontFamily: 'WinnerSans',
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  static Widget _statusChip(String status) {
    Color bg, fg;
    switch (status) {
      case 'Booked':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1976D2);
        break;
      case 'CheckedIn':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'CheckedOut':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFEF6C00);
        break;
      case 'Cancelled':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
      default:
        bg = Colors.black12;
        fg = Colors.black87;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontFamily: 'WinnerSans',
        ),
      ),
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
          style: TextStyle(color: Colors.white,fontWeight: FontWeight.w800,
          fontFamily: 'WinnerSans',),
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

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        // lift it up by 32px + safe-area
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

/// Local model for /api/booking/scan-info response
class _BookingScanInfo {
  final int bookingId;
  final int eventId;
  final String attendeeName;
  final String? sessionType;
  final String? date; // "yyyy-MM-dd"
  final String? startTime; // "HH:mm"
  final String? endTime; // "HH:mm"
  final int? seatNumber;
  final String status; // "Booked" | "CheckedIn" | "CheckedOut" | "Cancelled"

  _BookingScanInfo({
    required this.bookingId,
    required this.eventId,
    required this.attendeeName,
    required this.sessionType,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.seatNumber,
    required this.status,
  });

  _BookingScanInfo copyWith({String? status}) => _BookingScanInfo(
    bookingId: bookingId,
    eventId: eventId,
    attendeeName: attendeeName,
    sessionType: sessionType,
    date: date,
    startTime: startTime,
    endTime: endTime,
    seatNumber: seatNumber,
    status: status ?? this.status,
  );

  factory _BookingScanInfo.fromJson(Map<String, dynamic> j) {
    return _BookingScanInfo(
      bookingId: j['bookingId'] as int,
      eventId: j['eventId'] as int,
      attendeeName: (j['attendeeName'] ?? '—') as String,
      sessionType: j['sessionType'] as String?,
      date: j['date'] as String?,
      startTime: j['startTime'] as String?,
      endTime: j['endTime'] as String?,
      seatNumber: j['seatNumber'] as int?,
      status: (j['status'] ?? 'Booked') as String,
    );
  }
}
