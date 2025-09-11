import 'package:flutter/material.dart';
import 'package:corpsapp/widgets/filter_sheet.dart';
import '../models/event_summary.dart' as event_summary;


class EventFilterButton extends StatelessWidget {
  final event_summary.SessionType? initialSession;
  final bool initialDateAsc;
  final bool initialDateDesc;
  final bool initialSeatsAsc;
  final bool initialSeatsDesc;
  final void Function(event_summary.SessionType? session, bool dateAsc, bool dateDesc, bool seatsAsc, bool seatsDesc) onApply;

  const EventFilterButton({
    super.key,
    this.initialSession,
    required this.initialDateAsc,
    required this.initialDateDesc,
    required this.initialSeatsAsc,
    required this.initialSeatsDesc,
    required this.onApply,
  });

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: FilterSheet(
          initialSession: initialSession,
          initialDateAsc: initialDateAsc,
          initialDateDesc: initialDateDesc,
          initialSeatsAsc: initialSeatsAsc,
          initialSeatsDesc: initialSeatsDesc,
          onApply: onApply,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.filter_list, color: Colors.white),
      onPressed: () => _showFilters(context),
      tooltip: 'Filters',
    );
  }
}
