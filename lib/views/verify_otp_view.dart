import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'reset_password_view.dart';

class VerifyOtpView extends StatefulWidget {
  final String email;
  final String resetToken;

  const VerifyOtpView({
    super.key,
    required this.email,
    required this.resetToken,
  });

  @override
  State<VerifyOtpView> createState() => _VerifyOtpViewState();
}

class _VerifyOtpViewState extends State<VerifyOtpView> {
  final TextEditingController _otpCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final base = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url = Uri.parse('$base/api/password/verify-otp');
    final body = jsonEncode({'email': widget.email, 'otp': otp});

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (!mounted) return;

      if (resp.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordView(
              email: widget.email,
              resetToken: widget.resetToken,
            ),
          ),
        );
      } else {
        final msg = jsonDecode(resp.body)['message'] as String?;
        setState(() => _error = msg ?? 'Invalid code, please try again.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Network error – please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    // identical to your _resend in register view but pointing at
    // /api/auth/resend-confirmation-email
    // left as an exercise...
  }

  Widget _buildOtpBoxes() {
    final text = _otpCtrl.text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (i) {
        final char = (i < text.length) ? text[i] : '';
        return Container(
          width:  fortyFive,
          height: sixty,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white, width: 2),
            ),
          ),
          child: Text(
            char,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        );
      }),
    );
  }

  void _openOtpEntry() {
    // as before, pop up a full‐width TextField,
    // or simply focus a hidden field. For brevity
    // I'm just showing a dialog approach again:
    FocusScope.of(context).unfocus();
    final tmp = TextEditingController(text: _otpCtrl.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        content: TextField(
          controller: tmp,
          autofocus: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: const InputDecoration(
            hintText: 'Enter code',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
          ),
          onChanged: (v) {
            if (v.length <= 6) _otpCtrl.text = v;
            if (v.length == 6) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  static const double fortyFive = 45;
  static const double sixty = 60;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: bottomInset + 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back arrow
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    const Spacer(),

                    // Illustration
                    Image.asset('assets/otp.jpg', height: 240),
                    const SizedBox(height: 32),

                    // Heading
                    const Text(
                      'CHECK YOUR EMAIL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    const Text(
                      'We’ve sent you an email with a one-time code.\n'
                      'Please check your inbox or spam folder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    // OTP boxes
                    GestureDetector(
                      onTap: _openOtpEntry,
                      child: _buildOtpBoxes(),
                    ),
                    const SizedBox(height: 16),

                    // Error
                    if (_error != null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Resend link
                    TextButton(
                      onPressed: _isLoading ? null : _resendCode,
                      child: const Text(
                        "Didn't receive email? Resend",
                        style: TextStyle(
                          color: Colors.white70,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'SUBMIT CODE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
