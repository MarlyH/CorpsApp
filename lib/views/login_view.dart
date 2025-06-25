import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool canResend = false;
  bool obscurePassword = true;
  String? errorMessage;

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
      canResend = false;
    });

    final url = Uri.parse('http://10.0.2.2:5133/api/auth/login');
    final body = jsonEncode({
      'Email': emailController.text.trim(),
      'Password': passwordController.text,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeView()),
          );
        }
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage = data['message'] ?? 'Unauthorized';
          canResend = data['canResend'] ?? false;
        });
      } else {
        setState(() {
          errorMessage =
              data['message'] ?? 'Unexpected error: ${response.statusCode}';
        });
      }
    } catch (_) {
      setState(() {
        errorMessage = 'Failed to connect to server';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> resendConfirmationEmail() async {
    final resendUrl = Uri.parse(
      'http://10.0.2.2:5133/api/auth/resend-confirmation',
    );
    final resendBody = jsonEncode({'email': emailController.text.trim()});

    try {
      final resendResponse = await http.post(
        resendUrl,
        headers: {'Content-Type': 'application/json'},
        body: resendBody,
      );

      final data = jsonDecode(resendResponse.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Email resent')),
      );

      if (resendResponse.statusCode == 200) {
        setState(() {
          canResend = false;
        });
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server error, try again later.')),
      );
    }
  }

  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        hintText: 'Enter your $label',
        hintStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.5),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Optional: Add top logo or background here

            Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), // horizontal + bottom padding
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'WELCOME BACK',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      buildTextField(
                        label: 'Email',
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Email is required' : null,
                      ),
                      const SizedBox(height: 16),
                      buildTextField(
                        label: 'Password',
                        controller: passwordController,
                        obscureText: obscurePassword,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Password is required' : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() => obscurePassword = !obscurePassword);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (canResend)
                        TextButton(
                          onPressed: resendConfirmationEmail,
                          child: const Text('Resend Confirmation Email'),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isLoading ? null : login,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 4.65,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'By logging in, you agree to the Terms and Conditions and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
