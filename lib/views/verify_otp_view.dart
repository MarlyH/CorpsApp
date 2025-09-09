import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/widgets/otp_field.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'reset_password_view.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';

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
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _focusNode.dispose();
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
    // if (_cooldown > Duration.zero || _resending) return;

    // setState(() => _resending = true);//start spinner

    // final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    // final url     = Uri.parse('$baseUrl/api/auth/resend-confirmation-email');

    // try {
    //   final resp = await http.post(
    //     url,
    //     headers: {'Content-Type': 'application/json'},
    //     body: jsonEncode({'email': emailCtrl.text.trim()}),
    //   );

    //   final data = jsonDecode(resp.body);
    //   final msg = data['message']?.toString() ??
    //       (resp.statusCode == 200
    //           ? 'Verification email resent'
    //           : 'Failed to resend'
    //       );

    //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    //   _startCooldown();

    // } catch (_) {
    //   ScaffoldMessenger.of(context)
    //       .showSnackBar(const SnackBar(content: Text('Network error')));
    // } finally {
    //   setState(() => _resending = false); // stop spinner     
    // }
    // identical to your _resend in register view but pointing at
    // /api/auth/resend-confirmation-email
    // left as an exercise...
  }

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
                    OtpField(
                      onSubmit: (code) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Verification Code"),
                            content: Text('Code entered is $code'),
                          ),
                        );
                      },
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
