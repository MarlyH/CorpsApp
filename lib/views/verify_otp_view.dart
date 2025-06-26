import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'reset_password_view.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  Future<void> verifyOtp() async {
    if (otpController.text.trim().length != 6) {
      setState(() {
        errorMessage = 'Please enter a 6-digit code';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5133';
    final url = Uri.parse('$baseUrl/api/auth/verify-otp');
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

  Widget buildOtpFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return Container(
          width: 45,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
          child: Text(
            index < otpController.text.length
                ? otpController.text[index]
                : '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        );
      }),
    );
  }

  void handleOtpInput(String value) {
    if (value.length <= 6) {
      setState(() {
        otpController.text = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 52),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Back Arrow
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),

                      const Spacer(),

                      Image.asset(
                        'assets/otp.jpg',
                        height: 240,
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'CHECK YOUR EMAIL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'We’ve sent you an email with a one-time code. Please check your inbox or spam and enter the 6-digit code below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      GestureDetector(
                        onTap: () {
                          FocusScope.of(context).requestFocus(FocusNode());
                          showDialog(
                            context: context,
                            builder: (_) {
                              String buffer = otpController.text;
                              final tempController = TextEditingController(text: buffer);
                              return AlertDialog(
                                backgroundColor: Colors.black,
                                content: TextField(
                                  controller: tempController,
                                  maxLength: 6,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontSize: 20),
                                  decoration: const InputDecoration(
                                    hintText: 'Enter 6-digit code',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.white),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.blue),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    handleOtpInput(val);
                                    if (val.length == 6) Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          );
                        },
                        child: buildOtpFields(),
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

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isLoading ? null : verifyOtp,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white, width: 4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'SUBMIT CODE',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20), // padding below button
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

}
