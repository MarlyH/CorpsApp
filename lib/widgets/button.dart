import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color buttonColor;
  final Color textColor;

  const Button({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonColor = const Color(0xFF4C85D0),
    this.textColor = const Color(0xFFFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: buttonColor,
        ),
        onPressed: onPressed, 
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'WinnerSans',
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}