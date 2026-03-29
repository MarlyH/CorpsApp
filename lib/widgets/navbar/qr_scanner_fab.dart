
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../views/qr_scan_view.dart';

class QrScanFab extends StatefulWidget {
  final double diameter;
  final double borderWidth;
  final int? expectedEventId;

  const QrScanFab({
    super.key,
    required this.diameter,
    required this.borderWidth,
    this.expectedEventId,
  });

  @override
  State<QrScanFab> createState() => _QrScanFabState();
}

class _QrScanFabState extends State<QrScanFab>
    with SingleTickerProviderStateMixin {

  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }



  Future<void> _openScanner() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrScanView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color.fromARGB(255, 18, 18, 18),
            width: widget.borderWidth,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF512728),
              width: widget.borderWidth,
            ),
          ),
          child: SizedBox(
            width: widget.diameter,
            height: widget.diameter,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  heroTag: null,
                  backgroundColor: const Color(0xFFD01417),
                  elevation: 4,
                  onPressed: _openScanner,
                  shape: const CircleBorder(),
                  child: SvgPicture.asset(
                    'assets/icons/scanner.svg',
                    width: 32,
                    height: 32,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      if (!_shimmerController.isAnimating) {
                        return const SizedBox.shrink();
                      }
                      final slide = -1.8 + (_shimmerController.value * 3.6);
                      return ClipOval(
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment(slide - 0.5, -1),
                              end: Alignment(slide + 0.5, 1),
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.45),
                                Colors.transparent,
                              ],
                              stops: const [0.35, 0.5, 0.65],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcATop,
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      );
                    },
                  ),
                ),               
              ],
            ),
          ),
        ),
      ),
    );
  }
}




