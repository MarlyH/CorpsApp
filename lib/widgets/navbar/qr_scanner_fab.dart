import 'dart:convert';
import 'package:corpsapp/services/auth_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../views/qr_scan_view.dart';

class QrScanFab extends StatelessWidget {
  final double diameter;
  final double borderWidth;
  final int? expectedEventId;

  const QrScanFab({
    super.key,
    required this.diameter,
    required this.borderWidth,
    this.expectedEventId,
  });

  Future<List<int>> getCurrentEventIds() async {
    final response = await AuthHttpClient.get('/api/events');
    if (response.statusCode != 200) return [];

    final List<dynamic> events = jsonDecode(response.body);
    final now = DateTime.now();
    List<int> currentEventIds = [];

    for (final event in events) {
      try {
        final start = DateTime.parse('${event['startDate']}T${event['startTime']}');
        final end   = DateTime.parse('${event['startDate']}T${event['endTime']}');

        // Adjust for overnight events
        final adjustedEnd = end.isBefore(start) ? end.add(const Duration(days: 1)) : end;

        if (now.isAfter(start) && now.isBefore(adjustedEnd)) {
          currentEventIds.add(event['eventId']);
        }
      } catch (e) {
        debugPrint('Error parsing times for event ${event['eventId']}: $e');
      }
    }

    return currentEventIds;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: borderWidth),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF512728), width: borderWidth),
        ),
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: FloatingActionButton(
            heroTag: null,
            backgroundColor: const Color(0xFFD01417),
            elevation: 4,
            onPressed: () async {
              // Fetch current event IDs or use the one passed in
              final currentEventIds = expectedEventId != null
                  ? [expectedEventId!]
                  : await getCurrentEventIds();

              if (currentEventIds.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No active event found.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return;
              }

              // Pick the first active event automatically
              final currentEventId = currentEventIds.first;

              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QrScanView(expectedEventId: currentEventId),
                  ),
                );
              }
            },
            shape: const CircleBorder(),
            child: SvgPicture.asset(
              'assets/icons/scanner.svg',
              width: 32,
              height: 32,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
