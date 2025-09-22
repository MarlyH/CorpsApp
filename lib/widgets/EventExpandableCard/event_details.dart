import 'package:corpsapp/fragments/events_fragment.dart';
import 'package:corpsapp/models/event_summary.dart' as event_summary;
import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';

class EventDetailsCard extends StatelessWidget {
  final event_summary.EventSummary summary;
  final Future<EventDetail> detailFut;

  const EventDetailsCard ({
    super.key,
    required this.summary,
    required this.detailFut,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(7),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeatsRow(summary),
          const SizedBox(height: 12),
          _buildAddress(),
          const SizedBox(height: 12),
          _buildDescription(),
        ],
      ),
    );
  }
  
  Widget _buildSeatsRow(event_summary.EventSummary s) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.event_seat, color: Colors.white, size: 20),
      const SizedBox(width: 8),
      RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${s.availableSeatsCount} ',
              style: TextStyle(fontSize: 20)
            ),
            TextSpan(
              text: 'AVAILABLE',
              style: TextStyle(fontSize: 14)
            ),
          ]
        )
      ),
    ],
  );

  Widget _buildAddress() => FutureBuilder<EventDetail>(
    future: detailFut,
    builder: (ctx, snap) {
      final addr = snap.data?.address ?? '';
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, size: 20),
          const SizedBox(width: 4),
          Text(addr, style: TextStyle(fontSize: 16))
        ],
      );
    },
  );

  Widget _buildDescription() => FutureBuilder<EventDetail>(
    future: detailFut,
    builder: (ctx, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        );
      }
      if (snap.hasError) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Error loading details',
            style: TextStyle(color: AppColors.errorColor),
          ),
        );
      }

      if (snap.data?.description == null || snap.data!.description.isEmpty) {
        return const SizedBox.shrink(); // no description, no padding
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          snap.data!.description,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    },
  );
}