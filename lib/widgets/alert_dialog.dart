import 'package:flutter/material.dart';
import 'package:corpsapp/widgets/button.dart';

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final String info;

  const CustomAlertDialog({
    super.key,
    required this.title,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min, // this makes height wrap content
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              info,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 16),
            
            Button(
                label: 'OK',
                onPressed: () => Navigator.of(context).pop(),
              ),

          ],
        ),
      ),
    );
  }
}
