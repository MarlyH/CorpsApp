import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/views/create_event_view.dart';
import 'package:flutter/material.dart';

class CreateEventFAB extends StatefulWidget {
  const CreateEventFAB({super.key});

  @override
  State<CreateEventFAB> createState() => _DraggableFABState();
}

class _DraggableFABState extends State<CreateEventFAB> {
  // Initial position
  final double initialTop = 500;
  final double initialLeft = 300;

  double top = 500;
  double left = 300;

  bool bouncingBack = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        AnimatedPositioned(
          duration: Duration(milliseconds: bouncingBack ? 400 : 0),
          curve: Curves.elasticOut,
          top: top,
          left: left,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                left += details.delta.dx;
                top += details.delta.dy;
              });
            },
            onPanEnd: (_) {
              final withinBounds = left >= 0 &&
                  left <= screenSize.width - 70 &&
                  top >= 0 &&
                  top <= screenSize.height - 100;

              if (!withinBounds) {
                setState(() {
                  bouncingBack = true;
                  top = initialTop;
                  left = initialLeft;
                });

                // Reset bounce flag after animation
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (mounted) {
                    setState(() => bouncingBack = false);
                  }
                });
              }
            },
            child: SizedBox(
              width: 70,
              height: 70,
              child: FloatingActionButton(
                shape: const CircleBorder(
                  side: BorderSide(
                    color: AppColors.primaryColor,
                    width: 4,
                  ),
                ),
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.add,
                  color: Colors.black,
                  size: 24,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateEventView(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
