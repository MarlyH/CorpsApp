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
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:barcode/barcode.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../models/booking_model.dart';
import '../services/auth_http_client.dart';

enum SessionType { Kids, Teens, Adults }

SessionType sessionTypeFromRaw(dynamic raw) {
  if (raw is int && raw >= 0 && raw < SessionType.values.length) {
    return SessionType.values[raw];
  }
  if (raw is String) {
    return SessionType.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == raw.toLowerCase(),
      orElse: () => SessionType.Kids,
    );
  }
  return SessionType.Kids;
}

String friendlySession(SessionType s) {
  switch (s) {
    case SessionType.Kids:
      return 'Ages 8 to 11';
    case SessionType.Teens:
      return 'Ages 12 to 15';
    case SessionType.Adults:
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

  // ---------- PDF BUILD (shared by Share & Download) ----------
  Future<Uint8List> _buildPdfBytes(EventDetail detail) async {
    final pdf = pw.Document();

    final dateLabel = DateFormat('d MMM, yyyy').format(widget.booking.eventDate);
    final session = friendlySession(detail.sessionType);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(16),
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  widget.booking.attendeeName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  session,
                  style: pw.TextStyle(fontSize: 20, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 16),

                _pdfDetailRow('Location', widget.booking.eventName),
                _pdfDetailRow('Address', detail.address),
                _pdfDetailRow('Date', dateLabel),
                _pdfDetailRow('Time', '${_format12h(detail.startTime)} to ${_format12h(detail.endTime)}'),
                _pdfDetailRow('Ticket', widget.booking.seatNumber.toString().padLeft(2, '0')),
                // Only show for child bookings:
                if (widget.booking.isForChild)
                  _pdfDetailRow('Does the attendee require a Parent/Guardian to be present on event conclusion?', widget.booking.canBeLeftAlone ? 'Yes' : 'No'),


                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),

                pw.Text('Description', style: pw.TextStyle(fontSize: 20, color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Text(detail.description, style: const pw.TextStyle(fontSize: 20)),

                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 16),

                // TRUE QR CODE IN PDF
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.BarcodeWidget(
                    barcode: Barcode.qrCode(),
                    data: widget.booking.qrCodeData,
                    width: 200,
                    height: 200,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  String _sanitize(String s) => s.replaceAll(RegExp(r'[^\w\d\-]+'), '_');

  pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(color: PdfColors.grey600, fontSize: 20),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
  // ---------- /PDF BUILD ----------

  // ---------- SHARE ----------
  Future<void> _sharePdf(EventDetail detail) async {
    try {
      final bytes = await _buildPdfBytes(detail);
      final fileName =
          'YourCorps_Ticket_${_sanitize(widget.booking.attendeeName)}_${DateFormat('yyyy-MM-dd').format(widget.booking.eventDate)}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share PDF: $e')),
      );
    }
  }

  // ---------- DOWNLOAD (shows native folder/location picker on iOS & Android) ----------
  Future<void> _downloadPdf(EventDetail detail) async {
    try {
      final bytes = await _buildPdfBytes(detail);
      final fileName =
          'YourCorps_Ticket_${_sanitize(widget.booking.attendeeName)}_${DateFormat('yyyy-MM-dd').format(widget.booking.eventDate)}.pdf';

      final params = SaveFileDialogParams(
        data: bytes,
        fileName: fileName,
        mimeTypesFilter: const ['application/pdf'],
      );

      // This opens the native “Save to…” dialog:
      final savedPath = await FlutterFileDialog.saveFile(params: params);

      if (!mounted) return;

      if (savedPath != null && savedPath.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $savedPath'),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () => OpenFilex.open(savedPath),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save canceled')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: $e')),
      );
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
                                widget.booking.attendeeName,
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
