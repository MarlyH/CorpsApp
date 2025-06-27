import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();

  final userNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final dobController = TextEditingController();

  final Map<String, FocusNode> focusNodes = {};

  bool isLoading = false;
  String? errorMessage;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    for (var label in [
      'Username',
      'Email',
      'Password',
      'Confirm Password',
      'First Name',
      'Last Name',
      'Date of Birth',
    ]) {
      focusNodes[label] = FocusNode();
      focusNodes[label]!.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    userNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    dobController.dispose();
    for (var node in focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

    if (passwordController.text != confirmPasswordController.text) {
      setState(() => errorMessage = 'Passwords do not match.');
      return;
    }

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

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Check your email.')),
        );
        Navigator.pop(context);
      } else if (response.statusCode == 400 && data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        final errorList = errors.values.expand((e) => List<String>.from(e)).toList();
        setState(() => errorMessage = errorList.join('\n'));
      } else {
        setState(() => errorMessage = data['message']?.toString() ?? 'Registration failed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => errorMessage = 'Failed to connect to server');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> pickDateOfBirth() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && mounted) {
      dobController.text = pickedDate.toIso8601String().split('T').first;
    }
  }

  Widget buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final node = focusNodes[label]!;

    final showHint = node.hasFocus && controller.text.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            focusNode: node,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            onTap: onTap,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: showHint ? 'Enter your $label' : null,
              hintStyle: const TextStyle(color: Colors.white54),
              suffixIcon: suffixIcon,
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent, width: 2),
              ),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget passwordField(String label, TextEditingController controller) {
    return buildTextField(
      label: label,
      controller: controller,
      obscureText: obscurePassword,
      suffixIcon: IconButton(
        icon: Icon(
          obscurePassword ? Icons.visibility_off : Icons.visibility,
          color: Colors.white54,
        ),
        onPressed: () => setState(() => obscurePassword = !obscurePassword),
      ),
    );
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
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BackButton(color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'REGISTER',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 24),
                buildTextField(label: 'Username', controller: userNameController),
                buildTextField(label: 'First Name', controller: firstNameController),
                buildTextField(label: 'Last Name', controller: lastNameController),
                buildTextField(
                  label: 'Date of Birth',
                  controller: dobController,
                  keyboardType: TextInputType.datetime,
                  suffixIcon: const Icon(Icons.calendar_today, color: Colors.white54),
                  readOnly: true,
                  onTap: pickDateOfBirth,
                ),
                buildTextField(
                  label: 'Email',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                passwordField('Password', passwordController),
                passwordField('Confirm Password', confirmPasswordController),
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
                          child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text('Register'),
                  ),
                ),
                const SizedBox(height: 16),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    children: [
                      const TextSpan(text: 'By logging in, you agree to the '),
                      TextSpan(
                        text: 'Terms and Conditions',
                        style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final url = Uri.parse('https://www.yourcorps.co.nz/terms-and-conditions');
                            if (await launcher.canLaunchUrl(url)) {
                              await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
                            }
                          },
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy.',
                        style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final url = Uri.parse('https://www.yourcorps.co.nz/privacy-policy');
                            if (await launcher.canLaunchUrl(url)) {
                              await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
                            }
                          },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
