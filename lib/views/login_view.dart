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
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  bool canResend = false;

  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      canResend = false;
    });

    // make sure to run API on its http profile during development.
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];

        // TODO: Save tokens securely (e.g., with flutter_secure_storage)

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeView()),
          );
        }
      } else if (response.statusCode == 401) {
        final data = jsonDecode(response.body);
        setState(() {
          errorMessage = data['message'] ?? 'Unauthorized';
          canResend = data['canResend'] ?? false;
        });
      } else if (response.statusCode == 500) {
        final data = jsonDecode(response.body);
        setState(() {
          errorMessage = data['message'] ?? 'Server error';
        });
      } else {
        setState(() {
          errorMessage = 'Unexpected error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to connect to server';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(flex: 1, child: Container(color: Colors.black)),
          Expanded(
            flex: 4,
            child: Container(
              width: width,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        Image.asset(
                          'assets/welcome_back.jpg',
                          height: 100,
                        ),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Enter your email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Enter your password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              // TODO: handle forgot password
                            },
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (canResend)
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Resend email clicked')),
                              );
                            },
                            child: const Text('Resend Confirmation Email'),
                          ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isLoading ? null : login,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Login'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'By logging in, you agree to the Terms and Conditions and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
