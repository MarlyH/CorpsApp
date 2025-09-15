import 'package:corpsapp/models/event_summary.dart' as event_summary;
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class EventsFilter extends StatelessWidget {
  final event_summary.SessionType? filterSessionType;
  final String Function(event_summary.SessionType) friendlySession;
  final void Function(event_summary.SessionType?) onChanged;

  const EventsFilter({
    super.key,
    required this.filterSessionType,
    required this.friendlySession,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/filter.svg',
          width: 24,
          height: 24,
        ),

        const SizedBox(width: 4),

        Flexible(
          child: DropdownMenu<event_summary.SessionType?>(
            showTrailingIcon: false,
            initialSelection: filterSessionType,
            onSelected: onChanged,
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16
            ),
            inputDecorationTheme: const InputDecorationTheme(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero, // remove padding around text
            ),
            dropdownMenuEntries: [
              const DropdownMenuEntry<event_summary.SessionType?>(
                value: null,
                label: 'All Ages',
              ),
              ...event_summary.SessionType.values.map(
                (session) => DropdownMenuEntry<event_summary.SessionType?>(
                  value: session,
                  label: friendlySession(session),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
