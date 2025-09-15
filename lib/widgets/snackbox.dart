import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomSnackBar {
  static void show({
    required BuildContext context,
    required BuildContext dialogContext,
    required String message,
    String? icon
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(dialogContext).pop(); // close the current dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ... [
                SvgPicture.asset(
                  icon, 
                  height: 24, 
                  width: 24, 
                  color: Colors.black
                ),                    
                const SizedBox(width: 8),
              ],

              Expanded(
                child: Text(message),
              ),
            ],
          ),
          backgroundColor: Colors.white, // primary color
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(0),
        ),
      );
    });
  }
}
