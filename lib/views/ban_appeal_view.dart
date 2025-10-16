import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../providers/auth_provider.dart';

class BanAppealView extends StatefulWidget {
  const BanAppealView({super.key});

  @override
  State<BanAppealView> createState() => _BanAppealViewState();
}

class _BanAppealViewState extends State<BanAppealView> {
  static String get _appealsEmail =>
      dotenv.env['APPEALS_EMAIL'] ??
      dotenv.env['SUPPORT_EMAIL'] ??
      'yourcorps@yourcorps.co.nz';

  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_messageCtrl.text.trim().isEmpty) {
      _snack('Please enter a message before sending.');
      return;
    }

    setState(() => _sending = true);
    try {
      final auth = context.read<AuthProvider>();
      final profile = auth.userProfile ?? const <String, dynamic>{};
      final handle = (profile['userName'] ?? '').toString();
      final email = (profile['email'] ?? '').toString();
      final suspended = auth.isSuspended;

      final to = _appealsEmail;
      final subject = 'Ban Appeal Request';
      final body = [
        'Reason / context for appeal:\n${_messageCtrl.text.trim()}\n',
        '---',
        'Account Information:',
        '• Username: ${handle.isEmpty ? '(unknown)' : handle}',
        '• Email: ${email.isEmpty ? '(unknown)' : email}',
        '• Currently suspended: ${suspended ? 'Yes' : 'No'}',
      ].join('\n');

      // 1) Native mail app
      final mailUri = Uri(
        scheme: 'mailto',
        path: to,
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );
      if (await canLaunchUrl(mailUri)) {
        await launchUrl(mailUri, mode: LaunchMode.externalApplication);
        return;
      }

      // 2) Fallback: copy to clipboard
      _copyToClipboard(to: to, subject: subject, body: body);
      _snack('Could not open an email app. A ready-to-send message was copied to your clipboard.');
    } catch (_) {
      _copyToClipboard(
        to: _appealsEmail,
        subject: 'Ban Appeal Request',
        body: _messageCtrl.text,
      );
      _snack('Something went wrong. The message was copied to your clipboard.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _copyToClipboard({
    required String to,
    required String subject,
    required String body,
  }) {
    final formatted = 'To: $to\nSubject: $subject\n\n$body';
    Clipboard.setData(ClipboardData(text: formatted));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
    );
  }

  // —————————————————————————————— UI ——————————————————————————————

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.userProfile ?? const <String, dynamic>{};
    final handle = (profile['userName'] ?? '').toString();
    final email = (profile['email'] ?? '').toString();
    final strikes = auth.attendanceStrikeCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Ban Appeal'),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.screen,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    const Text(
                      'Request a Review',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Your account has been temporarily suspended after receiving three strikes under the attendance policy. '
                      'Please use the form below to open your email app and submit a ban appeal request.',
                      style: TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 24),

                    // Read-only account info
                    _readonlyRow('Username', handle),
                    _readonlyRow('Email', email),
                    _readonlyRow('Strikes', '$strikes'),

                    const SizedBox(height: 24),

                    // Message field
                    InputField(
                      label: 'Reason or Context',
                      hintText: 'Please describe briefly what happened, any misunderstandings, or why you believe the suspension should be lifted.',
                      controller: _messageCtrl,
                      maxLines: 8,
                    ),
                  ],
                ),
              ),

              // Fixed button at the bottom
              Button(
                label: _sending ? 'Opening...' : 'Send Email',
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readonlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '(unknown)' : value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
