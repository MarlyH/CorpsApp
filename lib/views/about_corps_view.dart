// lib/views/about_corps_view.dart

import 'package:flutter/material.dart';

class AboutCorpsView extends StatelessWidget {
  const AboutCorpsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'ABOUT CORPS',
          style: TextStyle(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Spacer above logo
            const SizedBox(height: 40),

            // Logo and version
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Your Corps logo asset
                  // Make sure to add assets/your_corps_logo.png in pubspec.yaml
                  Image.asset(
                    'assets/your_corps_logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Corps App',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version v1.0.0',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Rate our app button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: const Text(
                  'Rate our app',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: const Icon(Icons.keyboard_arrow_right, color: Colors.white),
                onTap: () {
                  // TODO: launch your app store link
                },
              ),
            ),

            // Copyright
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 16),
              child: Text(
                'Copyright Your Corps 2025',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
