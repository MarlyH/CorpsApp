import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/back_button.dart';
import 'package:corpsapp/widgets/button.dart';
import '../widgets/date_picker.dart';
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

  Future<void> _generateReport() async {
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Please select both start and end dates.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // fetch report data from API
      final resp = await AuthHttpClient.generateReport(
        startDate: _startDate!,
        endDate: _endDate!,
      );

      // parse response
      final data = jsonDecode(resp.body);
      final report = EventReport.fromJson(data);

      if (!mounted) return;

      // generate and share PDF
      await ReportService.generateAndSharePdf(report);

    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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
                onTap: () async {
                  final dt = await DatePickerUtil.pickDate(context, initialDate: DateTime(2025, 1, 1));
                  if (dt != null) {
                    setState(() {
                      _startDate = dt;
                      _startCtrl.text = dt.toIso8601String().split('T').first;
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
                onTap: () async {
                  final dt = await DatePickerUtil.pickDate(context, initialDate: DateTime.now());
                  if (dt != null) {
                    setState(() {
                      _endDate = dt;
                      _endCtrl.text = dt.toIso8601String().split('T').first;
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

              Button(
                label: 'GENERATE',
                onPressed: _loading ? null : _generateReport,
                loading: _loading,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
