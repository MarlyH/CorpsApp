import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController userNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  bool obscurePassword = true;

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url = Uri.parse('$baseUrl/api/auth/register');
    final body = jsonEncode({
      'userName': userNameController.text.trim(),
      'email': emailController.text.trim(),
      'password': passwordController.text,
      'firstName': firstNameController.text.trim(),
      'lastName': lastNameController.text.trim(),
      'dateOfBirth': dobController.text.trim(),
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Check your email.')),
        );
        Navigator.pop(context);
      } else {
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

  Future<void> pickDateOfBirth() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      dobController.text = pickedDate.toIso8601String().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BackButton(color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  textAlign: TextAlign.center,
                  'REGISTER',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  
                ),
                const SizedBox(height: 24),

                buildTextField(label: 'Username', controller: userNameController),
                buildTextField(label: 'First Name', controller: firstNameController),
                buildTextField(label: 'Last Name', controller: lastNameController),

                GestureDetector(
                  onTap: pickDateOfBirth,
                  child: AbsorbPointer(
                    child: buildTextField(
                      label: 'Date of Birth',
                      controller: dobController,
                      keyboardType: TextInputType.datetime,
                      suffixIcon: const Icon(Icons.calendar_today, color: Colors.white54),
                    ),
                  ),
                ),

                buildTextField(
                  label: 'Email',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                ),

                buildTextField(
                  label: 'Password',
                  controller: passwordController,
                  obscureText: obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
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
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text('Register'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'By registering, you agree to the Terms and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              hintText: 'Enter your $label',
              hintStyle: const TextStyle(color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: suffixIcon,
            ),
            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}
