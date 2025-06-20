import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<void> register() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = Uri.parse('http://10.0.2.2:5133/api/auth/register');
    final body = jsonEncode({
      'userName': userNameController.text.trim(),
      'email': emailController.text.trim(),
      'password': passwordController.text,
      'firstName': firstNameController.text.trim(),
      'lastName': lastNameController.text.trim(),
      'dateOfBirth': dobController.text.trim(), // Expecting yyyy-MM-dd can change later to use a calender widget instead
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Check your email to verify.')),
        );
        Navigator.pop(context); // Return to login
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          errorMessage = data['message']?.toString() ?? 'Registration failed';
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
                        Image.asset('assets/welcome_back.jpg', height: 100),
                        const SizedBox(height: 24),
                        buildTextField(label: 'Username', controller: userNameController),
                        const SizedBox(height: 16),
                        buildTextField(label: 'First Name', controller: firstNameController),
                        const SizedBox(height: 16),
                        buildTextField(label: 'Last Name', controller: lastNameController),
                        const SizedBox(height: 16),
                        buildTextField(
                          label: 'Date of Birth (YYYY-MM-DD)',
                          controller: dobController,
                          keyboardType: TextInputType.datetime,
                        ),
                        const SizedBox(height: 16),
                        buildTextField(
                          label: 'Email',
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        buildTextField(
                          label: 'Password',
                          controller: passwordController,
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        if (errorMessage != null)
                          Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isLoading ? null : register,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Register'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'By registering, you agree to the Terms and Privacy Policy.',
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

  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
