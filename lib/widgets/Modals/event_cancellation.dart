import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class EventCancellationModal extends StatelessWidget {
  final TextEditingController? controller;
  final bool isListingRemoval;

  const EventCancellationModal({
    super.key,
    this.controller,
    this.isListingRemoval = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.screen.copyWith(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min, // hug content
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
              colorFilter: const ColorFilter.mode(
                AppColors.errorColor,
                BlendMode.srcIn,
              ),
              width: 64,
              height: 64,
            ),

            const SizedBox(height: 8),

            Text(
              isListingRemoval ? 'Remove Listing' : 'Event Cancellation',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              isListingRemoval
                  ? 'Are you sure you want to remove this listing? This will hide it from event feeds.'
                  : 'Are you sure you want to cancel this event? This cannot be undone.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            if (!isListingRemoval) ...[
              TextField(
                controller: controller,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText:
                      "Add an optional explanation for the cancellation. This message will appear on people's email that have an active booking for this event.",
                  hintStyle: const TextStyle(
                    color: Color.fromARGB(100, 0, 0, 0),
                  ),
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
            ],

            Button(
              label:
                  isListingRemoval ? 'Confirm Removal' : 'Confirm Cancellation',
              onPressed:
                  () => Navigator.of(
                    context,
                  ).pop(isListingRemoval ? '' : controller?.text.trim()),
              buttonColor: AppColors.errorColor,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
