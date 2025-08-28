import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:barcode/barcode.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:open_filex/open_filex.dart';

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

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
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
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  session,
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 16),

                _pdfDetailRow('Location', detail.address),
                _pdfDetailRow('Date', dateLabel),
                _pdfDetailRow('Time', '${detail.startTime} – ${detail.endTime}'),
                _pdfDetailRow('Seat', widget.booking.seatNumber.toString().padLeft(2, '0')),
                // Only show for child bookings:
                if (widget.booking.isForChild)
                  _pdfDetailRow('Can be left alone?', widget.booking.canBeLeftAlone ? 'Yes' : 'No'),


                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),

                pw.Text('Description', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Text(detail.description, style: const pw.TextStyle(fontSize: 12)),

                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 16),

                // TRUE QR CODE IN PDF
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.BarcodeWidget(
                    barcode: Barcode.qrCode(), // ✅ QR format
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
              style: pw.TextStyle(color: PdfColors.grey600, fontSize: 12),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 12),
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

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM, yyyy').format(widget.booking.eventDate);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Ticket', style: TextStyle(color: Colors.white)),
        actions: [
          FutureBuilder<EventDetail>(
            future: _detailFuture,
            builder: (ctx, snap) {
              final enabled = snap.connectionState == ConnectionState.done && snap.hasData;
              return Row(
                children: [
                  IconButton(
                    tooltip: 'Share PDF',
                    onPressed: enabled ? () => _sharePdf(snap.data!) : null,
                    icon: const Icon(Icons.share, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Download PDF',
                    onPressed: enabled ? () => _downloadPdf(snap.data!) : null,
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
                  style: TextStyle(color: Colors.white, fontSize: 16),
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

            return Column(
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    widget.booking.attendeeName.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'WinnerSans',
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    friendlySession(detail.sessionType),
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _detailRow('Location', detail.address),
                          _detailRow('Date', dateLabel),
                          _detailRow('Time', '${detail.startTime} – ${detail.endTime}'),
                          _detailRow('Seat', widget.booking.seatNumber.toString().padLeft(2, '0')),
                          // Only show for child bookings:
                          if (widget.booking.isForChild)
                            _detailRow('Can be left alone?', widget.booking.canBeLeftAlone ? 'Yes' : 'No'),

                          const SizedBox(height: 16),
                          const Divider(color: Colors.black26),
                          const SizedBox(height: 8),
                          const Text(
                            'Description',
                            style: TextStyle(color: Colors.black54, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detail.description,
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.black26),
                          const SizedBox(height: 16),
                          // On-screen QR (remains QR format via qr_flutter)
                          Center(
                            child: QrImageView(
                              data: widget.booking.qrCodeData,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                if (canCancel)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _isCancelling
                        ? const CircularProgressIndicator(color: Colors.white)
                        : GestureDetector(
                            onTap: _cancelBooking,
                            child: const Text(
                              'Cancel Booking',
                              style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 14,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop<bool>(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: const Text(
                        'VIEW ALL TICKETS',
                        style: TextStyle(
                          fontFamily: 'WinnerSans',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
