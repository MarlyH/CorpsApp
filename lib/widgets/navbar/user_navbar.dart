import 'package:flutter/material.dart';
import 'navbar_button.dart';

class UserNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  final bool showTickets; // users only

  const UserNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.showTickets = true,
  });

  @override
  Widget build(BuildContext context) {
    // Index map must match Dashboard pages:
    // 0: HOME (hub)  1: EVENTS  2: TICKETS (optional)  3: PROFILE
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
        if (showTickets)
          NavBarButton(
            icon: Icons.confirmation_number,
            label: 'BOOKINGS',
            isSelected: selectedIndex == 2,
            onTap: () => onTap(2),
          ),
        NavBarButton(
          icon: Icons.person,
          label: 'PROFILE',
          isSelected: selectedIndex == (showTickets ? 3 : 2),
          onTap: () => onTap(showTickets ? 3 : 2),
        ),
      ],
    );
  }
}
