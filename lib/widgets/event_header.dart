import 'package:corpsapp/models/event_summary.dart';
import 'package:corpsapp/models/session_type_helper.dart';
import 'package:flutter/material.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/models/event_detail.dart';

class EventHeader extends StatelessWidget {
  final EventSummary event; // replace `dynamic` with your actual Event model type
  final Future<EventDetail> detailFuture;
  final String? mascotUrl;

  const EventHeader({
    super.key,
    required this.event,
    required this.detailFuture,
    this.mascotUrl,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double avatarSize = screenWidth < 360 ? 80 : 140;

    Widget avatar;

    if (mascotUrl == null) {
      avatar = Image.asset(
        'assets/logo/logo_transparent_1024px.png',
      );
    } else {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          mascotUrl!,
          height: avatarSize,
          width: avatarSize,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/logo/logo_transparent_1024px.png',           
            color: Colors.white30,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(flex: 1, child: avatar),

              const SizedBox(width: 8),

              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _format12h(event.startTime),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ), 
                    
                    Text(
                      _headerDate(event.startDate),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                                                
                    const SizedBox(height: 4),

                    Text(
                    SessionTypeHelper.format(event.sessionType),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth < 360 ? 24 : 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 4),
                    
                    FutureBuilder<EventDetail>(
                      future: detailFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text(
                            'Loading...',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          );
                        } else if (snapshot.hasError) {
                          return const Text(
                            '—',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          );
                        } else {
                          return Text(
                            snapshot.data?.address ?? '—',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          );
                        }
                      },
                    ),                                                                           
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white24, height: 1, thickness: 2),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---- Helper methods ----

  String _headerDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'March', 'April', 'May', 'June',
      'July', 'Aug', 'Sept', 'October', 'Nov', 'Dec'
    ];
    const weekdays = [
      'Monday', 'Tueday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  String _format12h(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : hour;
    return '${formattedHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
  }
}
