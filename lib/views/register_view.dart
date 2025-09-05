import 'dart:async';
import 'dart:convert';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Two-step registration + success flow with resend countdown.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  _RegisterViewState createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  int _step = 0; // 0 = form, 1 = success

  final _formKey      = GlobalKey<FormState>();
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl  = TextEditingController();
  final userNameCtrl  = TextEditingController();
  final emailCtrl     = TextEditingController();
  final dobCtrl       = TextEditingController();
  final passwordCtrl  = TextEditingController();
  final confirmCtrl   = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  // Resend‐confirmation cooldown
  Timer? _resendTimer;
  Duration _cooldown = Duration.zero;

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var c in [
      firstNameCtrl,
      lastNameCtrl,
      userNameCtrl,
      emailCtrl,
      dobCtrl,
      passwordCtrl,
      confirmCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$m:$s';
  }

  void _startCooldown() {
    setState(() => _cooldown = Duration(minutes: 5));
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final secs = _cooldown.inSeconds - 1;
      if (secs > 0) {
        setState(() => _cooldown = Duration(seconds: secs));
      } else {
        t.cancel();
        setState(() => _cooldown = Duration.zero);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Age check
    final dob = DateTime.tryParse(dobCtrl.text);
    if (dob != null) {
      final now = DateTime.now();
      final age = now.year -
          dob.year -
          ((now.month < dob.month ||
                  (now.month == dob.month && now.day < dob.day))
              ? 1
              : 0);
      if (age < 13) {
        await showDialog(
          context: context,
          builder: (context) => CustomAlertDialog(
            title: 'Parent or Guardian Required',
            info: 'Accounts for users under the age of 13 must be created by a parent or legal guardian. '
                  'Please have them register their own account to make bookings on your behalf.'
          ),
        );
        return;
      }
    }

    // Password match
    if (passwordCtrl.text != confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    //Capitalsie names
    String capitalize(String input) {
      if (input.isEmpty) return input;
      return input[0].toUpperCase() + input.substring(1).toLowerCase();
    }

    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url     = Uri.parse('$baseUrl/api/auth/register');
    final body    = jsonEncode({
      'firstName':   capitalize(firstNameCtrl.text.trim()),
      'lastName':    capitalize(lastNameCtrl.text.trim()),
      'userName':    userNameCtrl.text.trim(),
      'email':       emailCtrl.text.trim(),
      'dateOfBirth': dobCtrl.text.trim(),
      'password':    passwordCtrl.text,
    });

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      final data = jsonDecode(resp.body);

      if (resp.statusCode == 200) {
        // go straight to success without starting cooldown
        setState(() {
          _step = 1;
          _cooldown = Duration.zero;
        });
      } else {
        if (resp.statusCode == 400 && data['errors'] != null) {
          final errs = (data['errors'] as Map<String, dynamic>)
              .values
              .expand((e) => List<String>.from(e))
              .join('\n');
          setState(() => _error = errs);
        } else {
          setState(() =>
              _error = data['message']?.toString() ?? 'Registration failed');
        }
      }
    } catch (_) {
      setState(() => _error = 'Failed to connect to server');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > Duration.zero) return;

    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url     = Uri.parse('$baseUrl/api/auth/resend-confirmation-email');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': emailCtrl.text.trim()}),
      );
      final data = jsonDecode(resp.body);
      final msg = data['message']?.toString() ??
          (resp.statusCode == 200
              ? 'Verification email resent'
              : 'Failed to resend');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _startCooldown();
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Network error')));
    }
  }

  Widget _boxedField({
    required String label,
    required String hint,
    required TextEditingController ctrl,
    TextInputType? keyboard,
    bool obscure = false,
    VoidCallback? onTap,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          obscureText: obscure,
          onTap: onTap,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          validator: validator ?? (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 32),
            Row(children: [
              BackButton(color: Colors.white),
              const SizedBox(width: 8),
              const Text('REGISTER',
                  style: TextStyle(
                      color: Colors.white, 
                      fontSize: 24, 
                      fontFamily: 'WinnerSans', 
                      fontWeight: FontWeight.bold)
                      ),
            ]),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                children: [
                  const TextSpan(text: 'Create an account to start booking free events!\n'),
                  TextSpan(
                    text: 'Already have one? Log in',
                    style: const TextStyle(
                        decoration: TextDecoration.underline, color: Colors.white),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.pushNamed(context, '/login');
                      },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: _boxedField(
                    label: 'First Name', hint: 'Your first name', ctrl: firstNameCtrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _boxedField(
                    label: 'Last Name', hint: 'Your last name', ctrl: lastNameCtrl),
              ),
            ]),
            const SizedBox(height: 16),
            _boxedField(
                label: 'Username', hint: 'Choose a username', ctrl: userNameCtrl),
            const SizedBox(height: 16),
            _boxedField(
                label: 'Email',
                hint: 'you@example.com',
                ctrl: emailCtrl,
                keyboard: TextInputType.emailAddress,
                validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email'),
            const SizedBox(height: 16),
            _boxedField(
              label: 'Date of Birth',
              hint: 'YYYY-MM-DD',
              ctrl: dobCtrl,
              onTap: () async {
                final dt = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2005, 1, 1),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (dt != null) {
                  dobCtrl.text = dt.toIso8601String().split('T').first;
                }
              },
              suffix: const Icon(Icons.calendar_today, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _boxedField(
              label: 'Password',
              hint: 'Enter password',
              ctrl: passwordCtrl,
              obscure: _obscure,
              suffix: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 16),
            _boxedField(
                label: 'Confirm Password',
                hint: 'Re-enter password',
                ctrl: confirmCtrl,
                obscure: _obscure),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('NEXT', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 12),
                children: [
                  const TextSpan(text: 'By registering you agree to our '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: const TextStyle(decoration: TextDecoration.underline, color: Colors.white),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launcher.launchUrl(
                          Uri.parse('https://www.yourcorps.co.nz/terms-and-conditions'),
                          mode: launcher.LaunchMode.externalApplication,
                        );
                      },
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(decoration: TextDecoration.underline, color: Colors.white),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launcher.launchUrl(
                          Uri.parse('https://www.yourcorps.co.nz/privacy-policy'),
                          mode: launcher.LaunchMode.externalApplication,
                        );
                      },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: Color(0xFF8EF9B3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 72, color: Colors.black),
          ),
          const SizedBox(height: 32),
          const Text(
            'A verification link has been sent to your email.\n'
            'Please check your inbox to activate your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 24),
          // _cooldown is zero on first display, so this link is active immediately
          if (_cooldown > Duration.zero)
            Text('Retry in ${_formatDuration(_cooldown)}',
                style: const TextStyle(color: Colors.white, fontSize: 14))
          else
            GestureDetector(
              onTap: _resend,
              child: const Text(
                "Didn't receive email? Resend",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          const Spacer(flex: 1),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('DONE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _step == 0 ? _buildForm() : _buildSuccess()),
    );
  }
}
