import 'dart:convert';
import 'dart:io';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/back_button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/token_service.dart';
import 'package:corpsapp/widgets/button.dart';


class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _isLoading = false;
  bool _canResend = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _canResend = false;
    });

    final base = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';

    try {
      final res = await http.post(
        Uri.parse('$base/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Email': _emailCtrl.text.trim(),
          'Password': _pwCtrl.text,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        // Save tokens and load user
        await TokenService.saveTokens(data['accessToken'], data['refreshToken']);
        await context.read<AuthProvider>().loadUser();

        // Let OS consider saving these credentials
        TextInput.finishAutofillContext(shouldSave: true);

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        setState(() {
          _error = data['message'] ?? 'Login failed';
          _canResend = res.statusCode == 401 && (data['canResend'] == true);
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isLoading = true);
    final base = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';

    try {
      final res = await http.post(
        Uri.parse('$base/api/auth/resend-confirmation-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailCtrl.text.trim()}),
      );
      final msg = jsonDecode(res.body)['message'] ?? 'Check your inbox';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send email. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _canResend = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kbOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      // allow layout to adjust when keyboard appears
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppPadding.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // back button at the top (fixed)
              if (Platform.isAndroid) ...[
                CustomBackButton(route: '/'),
              ],

              // content centered in remaining space
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      // only scroll when keyboard is visible
                      physics: kbOpen
                          ? const ClampingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(
                        bottom: kbOpen
                            ? (MediaQuery.of(context).viewInsets.bottom + 24)
                            : 0,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'LOGIN TO CORPS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'WinnerSans',
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 60),

                            Form(
                              key: _formKey,
                              child: AutofillGroup(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    InputField(
                                      label: 'EMAIL',
                                      hintText: 'Enter your email',
                                      controller: _emailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [AutofillHints.email],
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: 20),
                                    InputField(
                                      label: 'PASSWORD',
                                      hintText: 'Enter your password',
                                      controller: _pwCtrl,
                                      obscureText: _obscure,
                                      keyboardType: TextInputType.visiblePassword,
                                      iconLook: IconButton(
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.black,
                                        ),
                                        onPressed: () =>
                                            setState(() => _obscure = !_obscure),
                                      ),
                                      autofillHints: const [AutofillHints.password],
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _login(),
                                    ),

                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                        ),
                                        onPressed: () =>
                                            Navigator.pushNamed(context, '/forgot-password'),
                                        child: const Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),

                                    if (_error != null) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error, color: Colors.red),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _error!,
                                                style: const TextStyle(color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    if (_canResend) ...[
                                      const SizedBox(height: 8),
                                      Center(
                                        child: TextButton(
                                          onPressed: _resendEmail,
                                          child: const Text(
                                            'Resend Confirmation Email',
                                            style: TextStyle(
                                              color: Colors.white,
                                              decoration: TextDecoration.underline,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 42),

                                    Button(
                                      label: 'LOGIN',
                                      onPressed: _login,
                                      loading: _isLoading,
                                    ),

                                    const SizedBox(height: 16),

                                    Center(
                                      child: RichText(
                                        text: TextSpan(
                                          text: "Don't have an account? ",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: 'Register',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                decoration: TextDecoration.underline, // optional
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  Navigator.pushNamed(context, '/register');
                                                },
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}