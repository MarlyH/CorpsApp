import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'reset_password_view.dart';

class VerifyOtpView extends StatefulWidget {
  final String email;
  final String resetToken;

  const VerifyOtpView({super.key, required this.email, required this.resetToken});

  @override
  State<VerifyOtpView> createState() => _VerifyOtpViewState();
}

class _VerifyOtpViewState extends State<VerifyOtpView> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  Future<void> verifyOtp() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final url = Uri.parse('http://10.0.2.2:5133/api/auth/verify-otp');
    final body = jsonEncode({
      'email': widget.email,
      'otp': otpController.text.trim(),
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
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
        final data = jsonDecode(response.body);
        setState(() {
          errorMessage = data['message'] ?? 'Invalid OTP';
        });
      }
    } catch (_) {
      setState(() {
        errorMessage = 'Connection failed';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Enter the 6-digit code sent to your email'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            if (errorMessage != null)
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : verifyOtp,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
