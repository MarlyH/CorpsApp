import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/models/event_summary.dart' as event_summary;

class EventSummaryCard extends StatelessWidget {
  final event_summary.EventSummary summary;
  final bool isFull;
  final bool isExpanded;

  const EventSummaryCard({
    super.key,
    required this.summary,
    this.isFull = false,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final smallScreen = screenWidth < 360;

    return ClipRRect(
      borderRadius: isExpanded ? BorderRadius.vertical(bottom: Radius.circular(0)) : BorderRadius.all(Radius.circular(7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _eventHeading(summary, context, smallScreen),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _summaryLeft(summary, context, smallScreen)),
                    Expanded(child: _summaryRight(summary, context, smallScreen)),
                  ],
                ),               
              ],              
            ),           
          ),
          if (isFull) _bookedOutBanner(),
        ],
      ),
    );
  }

  Widget _bookedOutBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.errorColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(width: 6),
          Text(
            'BOOKED OUT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontFamily: 'WinnerSans'
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventHeading(event_summary.EventSummary s, BuildContext context, bool smallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          s.locationName,
          style: TextStyle(
            color: AppColors.normalText,
            fontSize: smallScreen ? 14 : 16,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          event_summary.friendlySession(s.sessionType),
          style: TextStyle(
            color: AppColors.normalText,
            fontSize: smallScreen ? 14 : 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _summaryLeft(event_summary.EventSummary s, BuildContext context, bool smallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _weekdayFull(s.startDate),
          style: TextStyle(
            color: AppColors.normalText,
            fontSize: smallScreen ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          _formatDate(s.startDate),
          style: TextStyle(
            color: AppColors.normalText,
            fontSize: smallScreen ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _summaryRight(event_summary.EventSummary s, BuildContext context, bool smallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Starts    ',
                style: TextStyle(
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: smallScreen ? 10 : 12,
                ),
              ),
              TextSpan(
                text: formatTime(s.startTime),
                style: TextStyle(
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: smallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 4),

        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Ends    ',
                style: TextStyle(
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: smallScreen ? 10 : 12,
                ),
              ),
              TextSpan(
                text: formatTime(s.endTime),
                style: TextStyle(
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: smallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _weekdayFull(DateTime d) {
    const week = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return week[d.weekday - 1];
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String formatTime(String time) {
    final parsed = DateFormat("HH:mm:ss").parse(time);
    return DateFormat("hh:mma").format(parsed);
  }
}
