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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        NavBarButton(
          icon: Icons.home,
          label: 'HOME',
          isSelected: selectedIndex == 0,
          onTap: () => onTap(0),
        ),

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
