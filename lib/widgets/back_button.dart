import 'package:flutter/material.dart';

class CustomBackButton extends StatelessWidget {
  final String? route;
  final double size;
  final Color color;
  final double spacingAfter;

  const CustomBackButton({
    super.key,
    this.route,
    this.size = 24,
    this.color = Colors.white,
    this.spacingAfter = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Align(
          alignment: Alignment.centerLeft, 
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (route != null) {
                Navigator.pushNamed(context, route!);
              } else {
                Navigator.pop(context);
              }
            },
            child: Icon(
              Icons.arrow_back,
              color: color,
              size: size,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: spacingAfter),
      ],
    );
  }
}
