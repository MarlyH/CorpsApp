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
      'admin@admin.com';

  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController(text: 'Ban Appeal');
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _seedTemplate();
  }

  void _seedTemplate() {
    final auth = context.read<AuthProvider>();
    final profile = auth.userProfile ?? const <String, dynamic>{};
    final handle = (profile['userName'] ?? '').toString();
    final email  = (profile['email'] ?? '').toString();
    final strikes = auth.attendanceStrikeCount;
    final suspended = auth.isSuspended;

    _messageCtrl.text = [
      'Hi Admin team,',
      '',
      'I would like to appeal my booking suspension.',
      '',
      'Account:',
      '— Username: ${handle.isEmpty ? '(unknown)' : handle}',
      '— Email:    ${email.isEmpty ? '(unknown)' : email}',
      '— Strikes recorded: $strikes',
      '— Currently suspended: ${suspended ? 'Yes' : 'No'}',
      '',
      'Reason / context for appeal:',
      '(Please describe briefly what happened, any misunderstandings, or why you believe the suspension should be lifted.)',
      '',
      'Thank you.',
    ].join('\n');
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      final to = _appealsEmail;
      final subject = _subjectCtrl.text.trim();
      final body = _messageCtrl.text.trim();

      // 1) Native mail app
      final mailUri = Uri(
        scheme: 'mailto',
        path: to,
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );
      if (await canLaunchUrl(mailUri)) {
        if (await launchUrl(mailUri, mode: LaunchMode.externalApplication)) return;
      }

      // 2) Gmail web
      final gmailUri = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1'
        '&to=${Uri.encodeComponent(to)}'
        '&su=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}',
      );
      if (await canLaunchUrl(gmailUri)) {
        if (await launchUrl(gmailUri, mode: LaunchMode.externalApplication)) return;
      }

      // 3) Outlook web
      final outlookUri = Uri.parse(
        'https://outlook.office.com/mail/deeplink/compose'
        '?to=${Uri.encodeComponent(to)}'
        '&subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}',
      );
      if (await canLaunchUrl(outlookUri)) {
        if (await launchUrl(outlookUri, mode: LaunchMode.externalApplication)) return;
      }

      // 4) Clipboard fallback
      _copyToClipboard(to: to, subject: subject, body: body);
      _snack('Could not open an email app. A ready-to-send message was copied to your clipboard.');
    } catch (_) {
      _copyToClipboard(
        to: _appealsEmail,
        subject: _subjectCtrl.text,
        body: _messageCtrl.text,
      );
      _snack('Something went wrong. A ready-to-send message was copied to your clipboard.');
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
    final theme = Theme.of(context);

    // height to clear: keyboard inset + fixed button height + some spacing
    final kb = MediaQuery.of(context).viewInsets.bottom;
    const buttonHeight = 56.0; // matches ElevatedButton typical height
    final bottomPad = kb + buttonHeight + 32;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Ban Appeal',
          style: TextStyle(
            fontFamily: 'WinnerSans',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),

      // unchanged: fixed CTA at bottom
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_sending ? 'Opening…' : 'Send Email'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4C85D0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              textStyle: const TextStyle(
                fontFamily: 'WinnerSans',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),

      // NOTE: bottom: false here to avoid double-safe-area squeeze
      body: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPad),
              children: [
                Text(
                  'Request a review',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account is temporarily suspended due to attendance policy. '
                  'Send us an appeal below—this will open your email app with a pre-filled message.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),

                // email row (tap to open compose)
                InkWell(
                  onTap: _sending ? null : _send,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email, color: Color(0xFF4C85D0)),
                      const SizedBox(width: 8),
                      Text(
                        _appealsEmail,
                        style: const TextStyle(
                          color: Color(0xFF4C85D0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Subject label + field
                const Text(
                  'Subject',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _subjectCtrl,
                  style: const TextStyle(color: Colors.black),
                  decoration: _fieldDecoration(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 16),

                // Message label + field (shorter)
                const Text(
                  'Message',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageCtrl,
                  style: const TextStyle(color: Colors.black),
                  minLines: 6,
                  maxLines: 10,
                  decoration: _fieldDecoration(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // labels live above inputs; field is plain white
  InputDecoration _fieldDecoration() => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Colors.black45),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF40C4FF)),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}
