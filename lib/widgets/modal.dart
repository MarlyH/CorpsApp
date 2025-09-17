import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class Modal extends StatelessWidget {
  final TextEditingController? controller;

  const Modal ({
    super.key,
    this.controller
  });
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: Padding(
        padding: AppPadding.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          mainAxisSize: MainAxisSize.min, 
          children: <Widget>[

            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SvgPicture.asset(
              'assets/icons/alert.svg',
              color: AppColors.errorColor,
              width: 64,
              height: 64,
            ),

            const SizedBox(height: 8),

            const Text(
              'Event Cancellation',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Are you sure you want to cancel this event? This cannot be undone.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(
                color: Color.fromARGB(255, 0, 0, 0),
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText:
                    "Add an optional explanation for the cancellation. This message will appear on people's email that have an active booking for this event.",
                hintStyle: const TextStyle(color: Color.fromARGB(100, 0, 0, 0)),
                filled: true,
                fillColor: const Color.fromARGB(255, 255, 255, 255),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: AppPadding.screen,
              ),
            ),

            const SizedBox(height: 20),

            Button(
              label: 'Confirm Cancellation',
              onPressed: () =>
                  Navigator.of(context).pop(controller?.text.trim()),
              buttonColor: AppColors.errorColor,
            ),
          ],
        ),
      ),
    );
  }
}