import 'dart:async';
import 'package:flutter/material.dart';

/// Lightweight, poppable overlay for foreground notifications.
/// Tap outside or the X to dismiss. Auto-dismiss after [duration].
Future<void> showInAppPush(
  BuildContext context, {
  String? title,
  String? body,
  Duration duration = const Duration(seconds: 6),
}) async {
  // Prevent multiple stacked dialogs if messages arrive quickly
  if (ModalRoute.of(context)?.isCurrent != true && Navigator.of(context).overlay == null) return;

  bool closed = false;
  final timer = Timer(duration, () {
    if (!closed && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  });

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54, // dim
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.86,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(blurRadius: 24, color: Colors.black87)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title?.trim().isNotEmpty == true ? title!.toUpperCase() : 'NOTIFICATION',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          fontFamily: 'WinnerSans',
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                      child: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  (body ?? '').trim(),
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: const Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) {
      // subtle fade + scale
      return Opacity(
        opacity: anim.value,
        child: Transform.scale(
          scale: 0.98 + (anim.value * 0.02),
          child: child,
        ),
      );
    },
  ).whenComplete(() {
    closed = true;
    timer.cancel();
  });
}