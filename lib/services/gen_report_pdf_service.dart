import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/event_report.dart';

class ReportService {
  static Future<void> generateAndSharePdf(EventReport report) async {
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

    // save/share option
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'event_report.pdf');
  }
}
