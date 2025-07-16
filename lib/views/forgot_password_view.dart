import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'verify_otp_view.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> sendResetEmail() async {
    setState(() {
      _isLoading = true;
      _error     = null;
    });

    final base = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url  = Uri.parse('$base/api/password/forgot-password');
    final body = jsonEncode({'email': _emailCtrl.text.trim()});

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type':'application/json'},
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['resetPswdToken'] as String?;
        if (!mounted || token == null) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyOtpView(
              email: _emailCtrl.text.trim(),
              resetToken: token,
            ),
          ),
        );
      } else {
        final msg = jsonDecode(res.body)['message'] as String?;
        setState(() => _error = msg ?? 'Failed to send reset email.');
      }
    } catch (_) {
      setState(() => _error = 'Failed to connect to server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _boxField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('EMAIL',
          style: TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // allow body to resize when keyboard appears:
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            return SingleChildScrollView(
              // ensure scrolls up and adds padding for keyboard:
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Stack(children: [
                    // back arrow
                    Positioned(
                      top: 8,
                      left: 4,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    Column(
                      children: [
                        const Spacer(), // push graphic & form down

                        // graphic
                        Image.asset(
                          'assets/forgot_password.png',
                          height: 240,
                        ),
                        const SizedBox(height: 32),

                        // heading
                        const Text(
                          'FORGOT PASSWORD?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // subtext
                        const Text(
                          "Don't worry! We can help you reset it in a few steps.\n"
                          "Simply follow the instructions.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // email input
                        _boxField(),
                        const SizedBox(height: 24),

                        // error
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // send code button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : sendResetEmail,
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
                                    'SEND CODE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const Spacer(), // bottom space
                      ],
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
