import 'package:flutter/material.dart';

class HomeFragment extends StatelessWidget {
  const HomeFragment({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Upcoming Events',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}