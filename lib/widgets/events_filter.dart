import 'package:corpsapp/models/session_type_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class EventsFilter extends StatelessWidget {
  final SessionType filterSessionType; 
  final void Function(SessionType?) onChanged;

  const EventsFilter({
    super.key,
    required this.filterSessionType,
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
          child: DropdownMenu<SessionType>(
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
              contentPadding: EdgeInsets.zero,
            ),
            dropdownMenuEntries: [
              const DropdownMenuEntry<SessionType>(
                value: SessionType.all,
                label: 'All Ages',
              ),
              ...SessionType.values
                .where((session) => session != SessionType.all)
                .map(
                  (session) => DropdownMenuEntry<SessionType>(
                    value: session,
                    label: SessionTypeHelper.format(session),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}