import 'package:flutter/material.dart';

class QrScanFragment extends StatelessWidget {
  const QrScanFragment({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner, size: 100, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Scan to Check-In/Out',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}