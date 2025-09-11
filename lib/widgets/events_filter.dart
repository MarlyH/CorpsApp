import 'package:corpsapp/models/event_summary.dart' as event_summary;
import 'package:corpsapp/theme/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class EventsFilter extends StatelessWidget {
  final VoidCallback onTap;
  final event_summary.SessionType? filterSessionType;
  final String Function(event_summary.SessionType) friendlySession;

  const EventsFilter ({
    super.key,
    required this.filterSessionType,
    required this.friendlySession,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppPadding.screen,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/filter.svg',
              width: 24,
              height: 24
            ),

            const SizedBox(width: 4),
            
            Text(
              filterSessionType == null
                ? 'All Ages'
                : friendlySession(filterSessionType!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold
              ),
            )
          ],
        ),
      ),
    );
  }
}