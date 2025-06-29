import 'package:flutter/material.dart';

class TicketsFragment extends StatelessWidget {
  const TicketsFragment({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Your Bookings',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}