import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/back_button.dart';
import 'package:corpsapp/widgets/button.dart';
import '../utils/date_picker.dart';
import '../widgets/input_field.dart';
import '../services/auth_http_client.dart';
import '../models/event_report.dart';
import '../services/gen_report_pdf_service.dart';

class ReportGenerationView extends StatefulWidget {
  const ReportGenerationView({super.key});

  @override
  State<ReportGenerationView> createState() => _ReportGenerationViewState();
}

class _ReportGenerationViewState extends State<ReportGenerationView> {
  final TextEditingController _startCtrl = TextEditingController();
  final TextEditingController _endCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  String? _error;

  Future<EventReport> fetchReport() async {
    final resp = await AuthHttpClient.generateReport(
      startDate: _startDate!,
      endDate: _endDate!,
    );
    final data = jsonDecode(resp.body);
    return EventReport.fromJson(data);
  }

  bool validateDates() {
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Please select both start and end dates.');
      return false;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _error = 'End date must be after start date.');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  Future<void> shareReport() async {
    if (!validateDates()) return;
    setState(() => _loading = true);
    try {
      final report = await fetchReport();
      await ReportService.generateAndSharePdf(
        report,
        fileName: 'Your_Corps_Event_Report_${DateTime.now()}.pdf',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> downloadReport() async {
    if (!validateDates()) return;
    setState(() => _loading = true);
    try {
      final report = await fetchReport();
      final file = await ReportService.generateAndSavePdf(
        report,
        fileName: 'Your_Corps_Event_Report_${DateTime.now()}.pdf',
      );
      await ReportService.openPdf(file.path);
            if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to: ${file.path}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => ReportService.openPdf(file.path),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppPadding.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CustomBackButton(),
              const SizedBox(height: 24),
              const Text(
                'GENERATE REPORT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'WinnerSans',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the date range you want to generate a report for.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Start Date
              InputField(
                label: 'Start Date',
                hintText: 'Select start date',
                controller: _startCtrl,
                isReadOnly: true, // avoid keyboard
                onTap: () async {
                  final now = DateTime.now();
                  final startOfYear = DateTime(now.year, 1, 1);

                  final dt = await DatePickerUtil.pickDate(
                    context,
                    initialDate: _startDate ?? startOfYear, // show Jan 1 (or previously chosen)
                  );

                  if (dt != null) {
                    setState(() {
                      _startDate = dt;
                      _startCtrl.text = dt.toIso8601String().split('T').first; // only after selection
                    });
                  }
                },

                suffixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SvgPicture.asset(
                    'assets/icons/calendar.svg',
                    width: 12,
                    height: 12,
                    colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // End Date
              InputField(
                label: 'End Date',
                hintText: 'Select end date',
                controller: _endCtrl,
                isReadOnly: true, // avoid keyboard
                onTap: () async {
                  final dt = await DatePickerUtil.pickDate(
                    context,
                    initialDate: _endDate ?? (DateTime.now()),
                  );
                  if (dt != null) {
                    setState(() {
                      _endDate = DateTime(dt.year, dt.month, dt.day);
                      _endCtrl.text = _endDate!.toIso8601String().split('T').first;
                    });
                  }
                },
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SvgPicture.asset(
                    'assets/icons/calendar.svg',
                    width: 12,
                    height: 12,
                    colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.errorColor, fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              Button(
                label: 'SHARE PDF',
                onPressed: _loading ? null : shareReport,
                loading: _loading,
              ),
              const SizedBox(height: 12),
              Button(
                label: 'DOWNLOAD PDF',
                onPressed: _loading ? null : downloadReport,
                loading: false, // share button shows spinner; keep this simple
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
