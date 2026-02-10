import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/views/create_event_view.dart';
import 'package:flutter/material.dart';

class CreateEventFAB extends StatefulWidget {
  const CreateEventFAB({super.key});

  @override
  State<CreateEventFAB> createState() => _DraggableFABState();
}

class _DraggableFABState extends State<CreateEventFAB> {
  // Relative initial position (percentage of screen size)
  final double initialTopFactor = 0.7;   
  final double initialLeftFactor = 0.8;  

  double? top;
  double? left;
  bool bouncingBack = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Initialize relative position if not set
    top ??= screenSize.height * initialTopFactor;
    left ??= screenSize.width * initialLeftFactor;

    return Stack(
      children: [
        AnimatedPositioned(
          duration: Duration(milliseconds: bouncingBack ? 400 : 0),
          curve: Curves.elasticOut,
          top: top!,
          left: left!,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                left = (left! + details.delta.dx).clamp(0, screenSize.width - 70);
                top = (top! + details.delta.dy).clamp(0, screenSize.height - 100);
              });
            },
            onPanEnd: (_) {
              final withinBounds = left! >= 0 &&
                  left! <= screenSize.width - 70 &&
                  top! >= 0 &&
                  top! <= screenSize.height - 100;

              if (!withinBounds) {
                setState(() {
                  bouncingBack = true;
                  top = screenSize.height * initialTopFactor;
                  left = screenSize.width * initialLeftFactor;
                });

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
                    color: AppColors.background,
                    width: 6,
                  ),
                ),
                backgroundColor: Colors.white,
                child: const Icon(
                  weight: 900, 
                  Icons.add,
                  color: AppColors.background,
                  size: 50,
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
