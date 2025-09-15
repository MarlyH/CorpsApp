import 'package:corpsapp/views/login_view.dart';
import 'package:flutter/material.dart';

class RequireLoginModal extends StatelessWidget {
  const RequireLoginModal({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Login Required',
              style: TextStyle(
                fontFamily: 'WinnerSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Please sign in to start booking and'),
            const Text('getting notified for events.'),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontFamily: 'WinnerSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginView()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
