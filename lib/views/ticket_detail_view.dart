import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking_model.dart';
import '../services/auth_http_client.dart';

/// A simple model for start/end times from your `/api/events/{id}` endpoint.
class EventTime {
  final String startTime;
  final String endTime;

  EventTime(this.startTime, this.endTime);

  factory EventTime.fromJson(Map<String, dynamic> json) => EventTime(
        json['startTime'] as String,
        json['endTime'] as String,
      );
}

/// Displays a single booking in a full-screen “ticket” UI.
class TicketDetailView extends StatefulWidget {
  final Booking booking;

  const TicketDetailView({Key? key, required this.booking}) : super(key: key);

  @override
  State<TicketDetailView> createState() => _TicketDetailViewState();
}

class _TicketDetailViewState extends State<TicketDetailView> {
  late Future<EventTime> _timeFuture;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _timeFuture = _fetchEventTime();
  }

  Future<EventTime> _fetchEventTime() async {
    final resp = await AuthHttpClient.get('/api/events/${widget.booking.eventId}');
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return EventTime.fromJson(json);
  }

  Future<void> _cancelBooking() async {
    setState(() => _cancelling = true);
    try {
      await AuthHttpClient.delete('/api/Booking/${widget.booking.bookingId}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled', style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
          ),
        );
        Navigator.of(context).pop(); // go back
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancel failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final dateLabel = DateFormat.yMMMMEEEEd().format(b.eventDate);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Event Ticket'),
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder<EventTime>(
        future: _timeFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Error loading times', style: const TextStyle(color: Colors.white)),
            );
          }
          final times = snap.data!;
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
                  // Header: who & what
                  Center(
                    child: Column(
                      children: [
                        const Text('Booking for',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(b.eventName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(b.status.name,
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data rows
                  _DataRow(label: 'Location', value: b.eventName),
                  _DataRow(label: 'Date', value: dateLabel),
                  _DataRow(label: 'Time', value: '${times.startTime} – ${times.endTime}'),
                  _DataRow(
                      label: 'Seat', value: b.seatNumber.toString().padLeft(2, '0')),
                  _DataRow(
                      label: 'Pick Up', value: b.canBeLeftAlone ? 'Yes' : 'No'),
                  const Divider(color: Colors.white24, height: 32),

                  // QR code
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.qr_code, size: 128, color: Colors.white70),
                        const SizedBox(height: 8),
                        SelectableText(b.qrCodeData,
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cancel button
                  Center(
                    child: _cancelling
                        ? const CircularProgressIndicator(color: Colors.redAccent)
                        : TextButton(
                            onPressed: _cancelBooking,
                            child: const Text('Cancel Booking',
                                style: TextStyle(color: Colors.redAccent)),
                          ),
                  ),
                  const SizedBox(height: 8),

                  // Back
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black),
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
}

/// A little helper widget for label/value rows.
class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({Key? key, required this.label, required this.value})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.white70))),
        Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(color: Colors.white))),
      ]),
    );
  }
}
