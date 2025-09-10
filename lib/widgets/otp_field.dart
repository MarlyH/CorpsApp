import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';

class OtpField extends StatefulWidget {
  final void Function(String) onSubmit;

  const OtpField({
    super.key,
    required this.onSubmit,
  });

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  bool _clearText = false;
  Key _rebuildKey = UniqueKey(); 

  void _clearAndRefocus() {
    setState(() {
      _clearText = true;
      _rebuildKey = UniqueKey();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _clearText = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fieldWidth = screenWidth / 8;
    final margin = screenWidth / 60;

    return KeyedSubtree(
      key: _rebuildKey,

      child: OtpTextField(
        numberOfFields: 6,
        borderColor: const Color(0xFFFFFFFF),
        focusedBorderColor: const Color(0xFF4C85D0),
        fieldWidth: fieldWidth,
        fieldHeight: 60,
        showFieldAsBox: false,
        clearText: _clearText, 
        margin: EdgeInsets.only(right: margin),
        mainAxisAlignment: MainAxisAlignment.center,
        textStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),

        onSubmit: (code) {
          widget.onSubmit(code);   
          _clearAndRefocus();      // clear + refocus to first digit
        },
      ),
    );
  }
}
