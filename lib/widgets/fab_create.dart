import 'package:corpsapp/views/create_event_view.dart';
import 'package:flutter/material.dart';

class CreateEventFAB extends StatelessWidget {

  const CreateEventFAB({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: SizedBox(
        width: 70,
        height: 70,
        child: FloatingActionButton(
          shape: const CircleBorder(
            side: BorderSide(
              color: Color(0xFF4C85D0),
              width: 2,
            ),
          ),
          backgroundColor: Colors.white,
          child: const Icon(Icons.add, color: Colors.black),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateEventView(),
              ),
            );
          },
        ),
      ),
    );
  }
}
