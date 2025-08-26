import 'package:flutter/material.dart';
import '../../views/qr_scan_view.dart';

class QrScanFab extends StatelessWidget {
  final double diameter;
  final double borderWidth;
  final int? expectedEventId; // ← optional

  const QrScanFab({
    super.key,
    required this.diameter,
    required this.borderWidth,
    this.expectedEventId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter + borderWidth * 2,
      height: diameter + borderWidth * 2,
      child: FloatingActionButton(
        backgroundColor: const Color(0xFFD01417),
        elevation: 4,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QrScanView(expectedEventId: expectedEventId),
            ),
          );
        },
        shape: CircleBorder(
          side: BorderSide(color: Colors.black, width: borderWidth),
        ),
        child: const Icon(Icons.qr_code_scanner, size: 32, color: Colors.white),
      ),
    );
  }
}
