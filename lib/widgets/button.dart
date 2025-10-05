import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final String label;
  final String? subLabel; 
  final VoidCallback? onPressed;
  final Color buttonColor;
  final Color textColor;
  final Color borderColor;
  final double? buttonWidth;
  final bool loading;
  final double radius;
  final double fontSize;
  final bool isCancelOrBack;

  const Button({
    super.key,
    required this.label,
    required this.onPressed,
    this.subLabel, 
    this.buttonColor = const Color(0xFF4C85D0),
    this.textColor = const Color(0xFFFFFFFF),
    this.borderColor = Colors.transparent,
    this.buttonWidth = double.infinity,
    this.loading = false,
    this.radius = 12,
    this.fontSize = 16,
    this.isCancelOrBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: isCancelOrBack == true? Colors.transparent : buttonColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
              color: isCancelOrBack == true? Colors.white70 : borderColor,
              width: 1.5,
            ),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'WinnerSans',
                      color: textColor,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subLabel != null) ...[
                    Text(
                      subLabel!,
                      style: TextStyle(
                        color: textColor.withOpacity(0.8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
