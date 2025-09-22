// widgets/navbar/admin_navbar.dart
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
        // LEFT of notch: Home, Events
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: NavBarButton(
                  icon: Icons.space_dashboard_rounded,
                  label: 'HOME',
                  isSelected: selectedIndex == 0,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: NavBarButton(
                  icon: Icons.event,
                  label: 'EVENTS',
                  isSelected: selectedIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),
            ],
          ),
        ),

        // Notch spacer
        SizedBox(width: fabDiameter + fabBorder * 2 + sideGap),

        // RIGHT of notch: Profile
        Expanded(
          child: NavBarButton(
            icon: Icons.person,
            label: 'PROFILE',
            isSelected: selectedIndex == 2,
            onTap: () => onTap(2),
          ),
        ),
      ],
    );
  }
}
