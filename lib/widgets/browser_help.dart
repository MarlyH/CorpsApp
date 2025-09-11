import 'package:flutter/material.dart';

class EventBrowserHelpButton extends StatelessWidget {
  const EventBrowserHelpButton({super.key});

  void _showHelp(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        scrollable: true,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.help_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Event Browser Help',
                style: TextStyle(color: Colors.white),
                softWrap: true,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: screenWidth - 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              // Location
              Text(
                'Location Filter',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '• Use the dropdown at the top to filter events by location\n'
                '• Select "All Locations" to see events from everywhere\n',
                style: TextStyle(color: Colors.white70),
                softWrap: true,
              ),

              SizedBox(height: 12),
              Text(
                'Session Types & Sorting',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '• Tap "All Sessions" to open the filter panel\n'
                '• Filter by age groups (8–11, 12–15, 16+)\n'
                '• Sort by date (ascending/descending)\n'
                '• Sort by available seats\n',
                style: TextStyle(color: Colors.white70),
                softWrap: true,
              ),

              SizedBox(height: 12),
              Text(
                'Event Cards',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '• Tap a card to see event details\n'
                '• View location, date, time, and seat availability\n'
                '• Use "Book Now" to register for an event\n',
                style: TextStyle(color: Colors.white70),
                softWrap: true,
              ),

              SizedBox(height: 12),
              Text(
                'Refresh',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '• Pull down to refresh the event list\n'
                '• This will show the latest event updates\n',
                style: TextStyle(color: Colors.white70),
                softWrap: true,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              child: const Text('GOT IT', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline, color: Colors.white),
      onPressed: () => _showHelp(context),
      tooltip: 'Help',
    );
  }
}
