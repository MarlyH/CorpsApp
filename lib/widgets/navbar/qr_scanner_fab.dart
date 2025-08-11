import 'package:flutter/material.dart';
import '../../fragments/qr_scan_fragment.dart';

class QrScanFab extends StatelessWidget {
  final double diameter;
  final double borderWidth;

  const QrScanFab({
    super.key,
    required this.diameter,
    required this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter + borderWidth * 2,
      height: diameter + borderWidth * 2,
      child: FloatingActionButton(
        backgroundColor: const Color(0xFFD01417),
        elevation: 4,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QrScanFragment()),
        ),
        shape: CircleBorder(
          side: BorderSide(color: Colors.black, width: borderWidth),
        ),
        child: const Icon(
          Icons.qr_code_scanner,
          size: 32,
          color: Colors.white,
        ),
      ),
    );
  }
}
