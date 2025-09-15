import 'package:flutter/material.dart';

class CancellationDialog extends StatelessWidget {
  final TextEditingController controller;

  const CancellationDialog({
    super.key,
    required this.controller
    });

  @override
  Widget build(BuildContext c) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(c).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Icon(Icons.warning, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Event Cancellation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to cancel?\nThis cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
              decoration: InputDecoration(
                hintText:
                    'Add explanation. This message will be sent to people with an active booking.',
                hintStyle: const TextStyle(color: Color.fromARGB(100, 0, 0, 0)),
                filled: true,
                fillColor: const Color.fromARGB(255, 255, 255, 255),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(c).pop(controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'CANCEL EVENT',
                  style: TextStyle(color: Colors.white, letterSpacing: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}