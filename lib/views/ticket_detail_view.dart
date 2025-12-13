import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/booking_model.dart';
import '../services/auth_http_client.dart';

enum SessionType { kids, teens, adults }

SessionType sessionTypeFromRaw(dynamic raw) {
  if (raw is int && raw >= 0 && raw < SessionType.values.length) {
    return SessionType.values[raw];
  }
  if (raw is String) {
    return SessionType.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == raw.toLowerCase(),
      orElse: () => SessionType.kids,
    );
  }
  return SessionType.kids;
}

String friendlySession(SessionType s) {
  switch (s) {
    case SessionType.kids:
      return 'Ages 8 to 11';
    case SessionType.teens:
      return 'Ages 12 to 15';
    case SessionType.adults:
      return 'Ages 16+';
  }
}

class EventDetail {
  final String description;
  final String address;
  final SessionType sessionType;
  final DateTime startDate;
  final String startTime;
  final String endTime;

  EventDetail({
    required this.description,
    required this.address,
    required this.sessionType,
    required this.startDate,
    required this.startTime,
    required this.endTime,
  });

  factory EventDetail.fromJson(Map<String, dynamic> json) {
    return EventDetail(
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      sessionType: sessionTypeFromRaw(json['sessionType']),
      startDate: DateTime.parse(json['startDate'] as String),
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
    );
  }
}

class TicketDetailView extends StatefulWidget {
  final Booking booking;
  final bool allowCancel;

  const TicketDetailView({
    super.key,
    required this.booking,
    required this.allowCancel,
  });

  @override
  State<TicketDetailView> createState() => _TicketDetailViewState();
}

class _TicketDetailViewState extends State<TicketDetailView> {
  late Future<EventDetail> _detailFuture;
  bool _isCancelling = false;
  final GlobalKey _ticketKey = GlobalKey();


  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  String _format12h(String? raw) {
    if (raw == null) return '—';
    final s = raw.trim();
    if (s.isEmpty) return '—';

    // Accept HH:mm or HH:mm:ss (and lenient like "0:05")
    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(s);
    if (m == null) return s; // fallback: show as-is

    final h = int.tryParse(m.group(1)!) ?? 0;
    final min = int.tryParse(m.group(2)!) ?? 0;

    // any date works; we just want the time formatting
    final dt = DateTime(2000, 1, 1, h, min);
    return DateFormat('h:mma').format(dt); // e.g., 1:05 PM
  }


  Future<EventDetail> _loadDetail() async {
    final resp = await AuthHttpClient.get('/api/events/${widget.booking.eventId}');
    if (resp.statusCode != 200) {
      throw Exception('Failed to load event');
    }
    return EventDetail.fromJson(jsonDecode(resp.body));
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('NO', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('YES', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    final resp = await AuthHttpClient.put('/api/booking/cancel/${widget.booking.bookingId}');

    setState(() => _isCancelling = false);

    if (resp.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking successfully cancelled.')),
      );
      Navigator.of(context).pop<bool>(true);
    } else {
      String msg = 'Cancellation failed.';
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        msg = data['message'] ?? msg;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
  
  // ---------- /DOWNLOAD ----------

  Future<Uint8List?> _captureTicketImage() async {
    try {
      final boundary = _ticketKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to capture ticket: $e')));
      return null;
    }
  }

  Future<void> _shareTicketImage() async {
    final pngBytes = await _captureTicketImage();
    if (pngBytes == null) return;

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/ticket_${widget.booking.bookingId}.png';
    final file = File(filePath);
    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles([XFile(filePath)], text: 'My Event Ticket');
  }

  Future<void> _saveTicketImage() async {
    final pngBytes = await _captureTicketImage();
    if (pngBytes == null) return;

    try {
      // Request permission (important on Android & iOS)
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission to access photos is required.')),
        );
        return;
      }

      // Save to gallery
      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        name: "YourCorps_Ticket_${widget.booking.bookingId}",
        quality: 100,
      );

      final isSuccess = result['isSuccess'] ?? false;

      if (!mounted) return;
      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket saved to gallery!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save image to gallery.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM, yyyy').format(widget.booking.eventDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          FutureBuilder<EventDetail>(
            future: _detailFuture,
            builder: (ctx, snap) {
              final enabled = snap.connectionState == ConnectionState.done && snap.hasData;
              return Row(
                children: [
                  IconButton(
                    tooltip: 'Share PDF',
                    onPressed: enabled ? _shareTicketImage : null,
                    icon: const Icon(Icons.share, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Download PDF',
                    onPressed: enabled ? _saveTicketImage : null,
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<EventDetail>(
          future: _detailFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            if (snap.hasError) {
              return const Center(
                child: Text(
                  'Error loading event',
                  style: TextStyle(fontSize: 16),
                ),
              );
            }
            final detail = snap.data!;
            // Parse HH:mm or HH:mm:ss safely
            final parts = detail.startTime.split(':');
            int h = 0, m = 0;
            if (parts.isNotEmpty) h = int.tryParse(parts[0]) ?? 0;
            if (parts.length > 1) m = int.tryParse(parts[1]) ?? 0;

            final eventStart = DateTime(
              detail.startDate.year,
              detail.startDate.month,
              detail.startDate.day,
              h,
              m,
            );
            final canCancel = widget.allowCancel && DateTime.now().isBefore(eventStart);

            return Padding(
              padding: AppPadding.screen.copyWith(top: 0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    RepaintBoundary(
                      key: _ticketKey,
                      child: Container(
                        color: AppColors.background,
                        child: Column(
                          children: [

                            Center(
                              child: Text(
                                widget.booking.attendeeName.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'WinnerSans',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            Center(
                              child: Text(
                                friendlySession(detail.sessionType),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.all(20),                       
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _detailRow('Address', detail.address),
                                  _detailRow('Location', widget.booking.eventName),
                                  _detailRow('Date', dateLabel),
                                  _detailRow('Time',
                                      '${_format12h(detail.startTime)} to ${_format12h(detail.endTime)}'),
                                  _detailRow('Ticket', widget.booking.seatNumber.toString().padLeft(2, '0')),
                                  if (widget.booking.isForChild)
                                    _detailRow(
                                        'MUST the attendee be picked up?',
                                        widget.booking.canBeLeftAlone ? 'Yes' : 'No'),
                                  const Divider(color: Color(0xFFA2A2A2)),
                                  if (detail.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Description',
                                      style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      detail.description,
                                      style: const TextStyle(
                                          color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    const Divider(color: Color(0xFFA2A2A2)),
                                  ],
                                  Center(
                                    child: QrImageView(
                                      data: widget.booking.qrCodeData,
                                      version: QrVersions.auto,
                                      size: 300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Cancel button outside RepaintBoundary, but still inside scrollable column
                    if (canCancel)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _isCancelling
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Button(
                                label: 'Cancel Booking',
                                onPressed: _cancelBooking,
                                isCancelOrBack: true,
                              ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.normalText, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
