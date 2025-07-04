import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_http_client.dart';
import '../models/booking_model.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Helper to pull just the start/end times
class EventTime {
  final String startTime, endTime;
  EventTime(this.startTime, this.endTime);
  factory EventTime.fromJson(Map<String,dynamic> j) =>
    EventTime(j['startTime'] as String, j['endTime'] as String);
}

class TicketDetailView extends StatelessWidget {
  final Booking booking;
  final bool    allowCancel;

  const TicketDetailView({
    Key? key,
    required this.booking,
    required this.allowCancel,
  }) : super(key: key);

  Future<EventTime> _fetchEventTime() async {
    final resp = await AuthHttpClient.get('/api/events/${booking.eventId}');
    return EventTime.fromJson(jsonDecode(resp.body) as Map<String,dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat.yMMMMEEEEd().format(booking.eventDate);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Event Ticket'),
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder<EventTime>(
        future: _fetchEventTime(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Error loading times', style: const TextStyle(color: Colors.white))
            );
          }

          final times = snap.data!;
          // compute full DateTime of event start
          final parts = times.startTime.split(':');
          final eventStart = DateTime(
            booking.eventDate.year,
            booking.eventDate.month,
            booking.eventDate.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
            parts.length>2 ? int.parse(parts[2]) : 0,
          );
          final now = DateTime.now();
          final canCancelNow = allowCancel && now.isBefore(eventStart);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header
                  Center(
                    child: Column(
                      children: [
                        const Text('Booking for', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(booking.eventName,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(booking.status.toString().split('.').last,
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // details rows
                  _buildRow('Location', booking.eventName),
                  _buildRow('Date', dateLabel),
                  _buildRow('Time', '${times.startTime} – ${times.endTime}'),
                  _buildRow('Seat', booking.seatNumber.toString().padLeft(2,'0')),
                  _buildRow('Pick Up', booking.canBeLeftAlone ? 'Yes' : 'No'),
                  const Divider(color: Colors.white24, height: 32),

                  // QR code
                  Center(
                    child: Column(
                      children: [
                        QrImageView(
                          data: booking.qrCodeData,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(booking.qrCodeData, style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),

                  // only show cancel if still allowed
                  if (canCancelNow)
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          await AuthHttpClient.delete('/api/Booking/${booking.bookingId}');
                          // pop with the booking so the parent can mark it cancelled in‐session
                          Navigator.pop(context, booking);
                        },
                        child: const Text('Cancel Booking', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),

                  // always offer a back button
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: Colors.black
                      ),
                      child: const Text('Back to Tickets'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.white70))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
