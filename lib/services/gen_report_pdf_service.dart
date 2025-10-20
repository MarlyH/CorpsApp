import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/event_report.dart';

class ReportService {
  // --- helpers ---
  static String _timestamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

  static String _sanitizeFileName(String name) {
    final invalid = RegExp(r'[\\/:*?"<>|]');
    var out = name.trim().replaceAll(invalid, '_');
    if (!out.toLowerCase().endsWith('.pdf')) out += '.pdf';
    return out;
  }

  static pw.Document _build(EventReport report) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'Event Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Overview', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            data: [
              ['Metric', 'Value'],
              ['Total Events', '${report.totalEvents}'],
              ['Total Users', '${report.totalUsers}'],
              ['Total Bookings', '${report.totalBookings}'],
              ['Total Turnout', '${report.totalTurnout}'],
              ['Unique Attendees', '${report.uniqueAttendees}'],
              ['Recurring Attendees', '${report.recurringAttendees}'],
              ['Average Attendees / Event', report.averageAttendeesPerEvent.toStringAsFixed(2)],
              ['Attendance Rate Overall', '${report.attendanceRateOverall.toStringAsFixed(2)}%'],
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('Events per Location', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            data: [
              ['Location', 'Count'],
              ...report.eventsPerLocation.map((e) => [e.location, e.count.toString()]),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Share sheet; lets you control the name shown in the sheet.
  static Future<void> generateAndSharePdf(
    EventReport report, {
    String? fileName, // e.g. "Corps_Report_Q1_2025.pdf"
  }) async {
    final pdf = _build(report);
    final name = _sanitizeFileName(fileName ?? 'event_report_${_timestamp()}.pdf');
    await Printing.sharePdf(bytes: await pdf.save(), filename: name);
  }

  /// Save to app documents; lets you control the saved filename.
  static Future<File> generateAndSavePdf(
    EventReport report, {
    String? fileName,
  }) async {
    final pdf = _build(report);
    final bytes = await pdf.save();

    final dir = await getApplicationDocumentsDirectory();
    final name = _sanitizeFileName(fileName ?? 'event_report_${_timestamp()}.pdf');
    final path = '${dir.path}/$name';

    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> openPdf(String path) async {
    await OpenFilex.open(path);
  }
}
