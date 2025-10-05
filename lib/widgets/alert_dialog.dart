import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:corpsapp/widgets/button.dart';

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final String info;
  final String buttonLabel;
  final VoidCallback? buttonAction;
  final String? extraContentText;
  final String? iconPath;
  final bool? cancel;

  const CustomAlertDialog({
    super.key,
    required this.title,
    required this.info,
    this.buttonLabel = 'OK',
    this.buttonAction,
    this.extraContentText,
    this.iconPath,
    this.cancel,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double buttonFontSize = screenWidth < 360 ? 14 : 16;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [    
            Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,               
                ),
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

            if (extraContentText != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black26),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        extraContentText!,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            if (cancel == true) ...[
              Row(
                children: [
                  Expanded(
                    child: Button(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                      textColor: AppColors.normalText,
                      fontSize: buttonFontSize,
                      isCancelOrBack: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Button(
                      label: buttonLabel,
                      onPressed: buttonAction ?? () => Navigator.of(context).pop(),
                      fontSize: buttonFontSize,
                    ),
                  ),
                ],
              ),
            ] else 
              Button(
                label: buttonLabel,
                onPressed: buttonAction ?? () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}
