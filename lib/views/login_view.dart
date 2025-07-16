import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/token_service.dart';
import '../providers/auth_provider.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl    = TextEditingController();

  bool _isLoading = false;
  bool _canResend = false;
  bool _obscure   = true;
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
      _error     = null;
      _canResend = false;
    });

    final base = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final res = await http.post(
      Uri.parse('$base/api/auth/login'),
      headers: {'Content-Type':'application/json'},
      body: jsonEncode({
        'Email':    _emailCtrl.text.trim(),
        'Password': _pwCtrl.text,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      await TokenService.saveTokens(
        data['accessToken'], data['refreshToken']);
      await context.read<AuthProvider>().loadUser();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      setState(() {
        _error     = data['message'] ?? 'Login failed';
        _canResend = res.statusCode == 401 && (data['canResend'] == true);
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _resendEmail() async {
    setState(() => _isLoading = true);
    final base = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final res = await http.post(
      Uri.parse('$base/api/auth/resend-confirmation-email'),
      headers: {'Content-Type':'application/json'},
      body: jsonEncode({'email': _emailCtrl.text.trim()}),
    );
    final msg = jsonDecode(res.body)['message'] ?? 'Check your inbox';
    if (mounted) {
      ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
      setState(() {
        _canResend = false;
        _isLoading = false;
      });
    }
  }

  Widget _boxField({
    required String label,
    required TextEditingController ctrl,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Enter your ${label.toLowerCase()}',
            hintStyle: const TextStyle(color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
            suffixIcon: suffix,
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
      // default resizeToAvoidBottomInset = true
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ——— fixed top bar ———
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // ——— scrollable form area ———
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 24),

                  const Text(
                    'WELCOME BACK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _boxField(
                          label: 'EMAIL',
                          ctrl: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        _boxField(
                          label: 'PASSWORD',
                          ctrl: _pwCtrl,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 4),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero),
                            onPressed: () =>
                              Navigator.pushNamed(context, '/forgot-password'),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(width: 8),
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

                        const SizedBox(height: 24),

                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Center(
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                              children: [
                                TextSpan(
                                  text: 'Register',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.pushNamed(context, '/register');
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
