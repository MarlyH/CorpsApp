import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
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
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: borderWidth),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Color(0xFF512728), width: borderWidth),
        ),
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: FloatingActionButton(
            heroTag: null,
            backgroundColor: const Color(0xFFD01417),
            elevation: 4,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      QrScanView(expectedEventId: expectedEventId),
                ),
              );
            },
            shape: const CircleBorder(),
            child: SvgPicture.asset('assets/icons/scanner.svg', width: 32, height: 32, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
