import 'package:flutter/material.dart';
import 'navbar_button.dart';

class GuestNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;

  const GuestNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Guests: 0=HOME 1=EVENTS 2=PROFILE
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        NavBarButton(
          icon: Icons.space_dashboard_rounded,
          label: 'HOME',
          isSelected: selectedIndex == 0,
          onTap: () => onTap(0),
        ),
        NavBarButton(
          icon: Icons.event,
          label: 'EVENTS',
          isSelected: selectedIndex == 1,
          onTap: () => onTap(1),
        ),
        NavBarButton(
          icon: Icons.person,
          label: 'PROFILE',
          isSelected: selectedIndex == 2,
          onTap: () => onTap(2),
        ),
      ],
    );
  }
}
