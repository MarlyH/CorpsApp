import 'package:flutter/material.dart';
import 'navbar_button.dart';

class AdminNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  final double fabDiameter;
  final double fabBorder;
  final double sideGap;

  const AdminNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.fabDiameter,
    required this.fabBorder,
    required this.sideGap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NavBarButton(
          icon: Icons.home,
          label: 'HOME',
          isSelected: selectedIndex == 0,
          onTap: () => onTap(0),
        ),

        // space for the QR scanner FAB
        SizedBox(width: fabDiameter + fabBorder * 2 + sideGap),

        NavBarButton(
          icon: Icons.person,
          label: 'PROFILE',
          isSelected: selectedIndex == 1,
          onTap: () => onTap(1),
        ),
      ],
    );
  }
}
