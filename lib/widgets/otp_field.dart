import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';

class OtpField extends StatelessWidget {
  final void Function(String) onSubmit;

  const OtpField({
    super.key,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return OtpTextField(
      numberOfFields: 6,
      borderColor: const Color(0xFFFFFFFF),
      focusedBorderColor: const Color(0xFF4C85D0),
      fieldWidth: 45,
      fieldHeight: 60,
      showFieldAsBox: false,
      autoFocus: true,
      margin: const EdgeInsets.only(right: 16),
      clearText: true,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      onSubmit: onSubmit,
    );
  }
}
