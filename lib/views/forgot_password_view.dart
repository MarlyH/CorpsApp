import 'dart:convert';
import 'dart:io';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/back_button.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> sendResetEmail() async {
      // Clear any previous server error immediately
    if (mounted) setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            return SingleChildScrollView(
              // ensure scrolls up and adds padding for keyboard:
              padding: AppPadding.screen,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Stack(children: [
                    // back arrow
                    CustomBackButton(),

                    Column(
                      children: [
                        const Spacer(), // push graphic & form down

                        // graphic
                        Image.asset(
                          'assets/forgot_password.png',
                          height: 360
                        ),

                        // heading
                        const Text(
                          'FORGOT PASSWORD?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'WinnerSans'
                          ),
                        ),

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

                        const SizedBox(height: 24),

                        // email input
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              InputField(
                                label: 'EMAIL', 
                                hintText: 'Enter your email', 
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  // null or empty
                                  if (v == null || v.isEmpty) return 'Required';

                                  // not null or empty, validate email format
                                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                  if (!emailRegex.hasMatch(v)) return 'Invalid email address';

                                  // Valid
                                  return null;
                                },
                              ),
                            ]
                          )
                        ),
                        
                        const SizedBox(height: 24),

                        // error
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: TextStyle(color: AppColors.errorColor, fontSize: 12),
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 16),
                        ],

                        Button(
                          label: 'SEND CODE', 
                          onPressed: sendResetEmail, 
                          loading: _isLoading
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
