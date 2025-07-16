import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Full-screen dialog shown when the user is under 13.
class ParentGuardianRequiredDialog extends StatelessWidget {
  const ParentGuardianRequiredDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 64, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Parent or Guardian Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Accounts for users under 13 must be created by a parent or legal guardian. '
                'Please ask them to register their own account to make bookings for you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1877F2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-step registration + success flow.
class RegisterView extends StatefulWidget {
  const RegisterView({Key? key}) : super(key: key);

  @override
  _RegisterViewState createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  int _step = 0; // 0 = form, 1 = success screen

  // Form controllers
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

  @override
  void dispose() {
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
          barrierDismissible: false,
          builder: (_) => const ParentGuardianRequiredDialog(),
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

    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url = Uri.parse('$baseUrl/api/auth/register');
    final body = jsonEncode({
      'firstName':    firstNameCtrl.text.trim(),
      'lastName':     lastNameCtrl.text.trim(),
      'userName':     userNameCtrl.text.trim(),
      'email':        emailCtrl.text.trim(),
      'dateOfBirth':  dobCtrl.text.trim(),
      'password':     passwordCtrl.text,
    });

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      final data = jsonDecode(resp.body);

      if (resp.statusCode == 200) {
        setState(() => _step = 1);
      } else {
        if (resp.statusCode == 400 && data['errors'] != null) {
          final errs = (data['errors'] as Map<String, dynamic>)
              .values
              .expand((e) => List<String>.from(e))
              .join('\n');
          setState(() => _error = errs);
        } else {
          setState(() => _error =
              data['message']?.toString() ?? 'Registration failed');
        }
      }
    } catch (_) {
      setState(() => _error = 'Failed to connect to server');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url = Uri.parse('$baseUrl/api/auth/resend-verification');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': emailCtrl.text.trim()}),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resp.statusCode == 200
                ? 'Verification email resent!'
                : 'Failed to resend verification',
          ),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error')),
      );
    }
  }

  // Reusable white input box
  Widget _boxField({
    required String label,
    required String hint,
    required TextEditingController ctrl,
    TextInputType? keyboard,
    bool obscure = false,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          readOnly: readOnly,
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
          validator: validator ??
              (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header
            Row(
              children: [
                BackButton(color: Colors.white),
                const SizedBox(width: 8),
                const Text('REGISTER',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Create an account to start booking free events!\nAlready have one? Log in',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // First + Last Name
            Row(
              children: [
                Expanded(
                  child: _boxField(
                      label: 'First Name',
                      hint: 'Enter your first name',
                      ctrl: firstNameCtrl),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _boxField(
                      label: 'Last Name',
                      hint: 'Enter your last name',
                      ctrl: lastNameCtrl),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Username
            _boxField(
                label: 'Username',
                hint: 'Enter a unique username',
                ctrl: userNameCtrl),
            const SizedBox(height: 16),

            // Email
            _boxField(
              label: 'Email',
              hint: 'Enter your valid email',
              ctrl: emailCtrl,
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Date of Birth
            _boxField(
              label: 'Date of birth',
              hint: 'YYYY-MM-DD',
              ctrl: dobCtrl,
              readOnly: true,
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

            // Password
            _boxField(
              label: 'Password',
              hint: 'Enter a password',
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

            // Confirm Password
            _boxField(
              label: 'Confirm Password',
              hint: 'Confirm the password',
              ctrl: confirmCtrl,
              obscure: _obscure,
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],

            // NEXT button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('NEXT', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),

            // Terms & Privacy
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                children: [
                  const TextSpan(text: 'By registering you agree to our '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: const TextStyle(decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launcher.launchUrl(
                          Uri.parse(
                              'https://www.yourcorps.co.nz/terms-and-conditions'),
                          mode: launcher.LaunchMode.externalApplication,
                        );
                      },
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launcher.launchUrl(
                          Uri.parse(
                              'https://www.yourcorps.co.nz/privacy-policy'),
                          mode: launcher.LaunchMode.externalApplication,
                        );
                      },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return SizedBox.expand(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 72, color: Colors.white),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'A verification link has been sent to your email.\n'
              'Please check your inbox to activate your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),  
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _resend,
              child: const Text(
                "Didn't receive email? Resend",
                style: TextStyle(
                  color: Color(0xFF1877F2),
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('DONE', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
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
