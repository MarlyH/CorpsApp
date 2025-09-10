import 'dart:async';
import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/back_button.dart';
import 'package:corpsapp/widgets/otp_field.dart';
import 'package:flutter/gestures.dart';
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
  bool _resending = false;
  String? _error;

  Timer? _resendTimer;
  Duration _cooldown = Duration.zero;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$m:$s';
  }

  void _startCooldown() {
    setState(() => _cooldown = Duration(minutes: 1));
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
      // Clear any previous server error immediately
    if (mounted) setState(() => _error = null);

    if (_cooldown > Duration.zero || _resending) return;

    setState(() => _resending = true);//start spinner

    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url     = Uri.parse('$baseUrl/api/password/forgot-password');

    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
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
    } finally {
      setState(() => _resending = false); // stop spinner
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, constraints) {
          return SingleChildScrollView(
            padding: AppPadding.screen,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back arrow
                    CustomBackButton(route: '/forgot-password',),

                    const Spacer(),

                    // Illustration
                    Image.asset('assets/otp.png', height: 360),              

                    // Heading
                    const Text(
                      'CHECK YOUR EMAIL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'WinnerSans',
                      ),
                    ),

                    // Subtitle
                    const Text(
                      'We’ve sent you an email with a one-time code.\n'
                      'Please check your inbox or spam folder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),

                    const SizedBox(height: 24),

                    // OTP boxes
                    OtpField(
                      onSubmit: (code) {
                        _otpCtrl.text = code;
                        _submitCode();
                      },
                    ),

                    const SizedBox(height: 24),

                    // Error
                    if (_error != null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.errorColor,fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Resend link
                    Center(
                      child: RichText(
                        text: TextSpan(
                          text: "Didn't receive email? ",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          children: [
                            if (_cooldown > Duration.zero)
                              TextSpan(
                                text: ' ${_formatDuration(_cooldown)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else if (_resending)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(width: 6),
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              TextSpan(
                                text: 'Resend',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = (_isLoading || _resending) ? null : _resendCode,
                              ),
                          ],
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
