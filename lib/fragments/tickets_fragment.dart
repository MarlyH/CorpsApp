import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking_model.dart';
import '../services/auth_http_client.dart';
import '/views/ticket_detail_view.dart'; // adjust to your path

/// Mirrors your server’s event/Get endpoint for start/end times.
class EventTime {
  final String startTime;
  final String endTime;

  EventTime(this.startTime, this.endTime);

  factory EventTime.fromJson(Map<String, dynamic> json) => EventTime(
        json['startTime'] as String,
        json['endTime']   as String,
      );
}

/// --- TicketsFragment ---
class TicketsFragment extends StatelessWidget {
  const TicketsFragment({Key? key}) : super(key: key);

  Future<List<Booking>> _loadBookings() async {
    final resp = await AuthHttpClient.get('/api/Booking/my');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(Booking.fromJson).toList();
  }

  Future<EventTime> _fetchEventTime(int eventId) async {
    final resp = await AuthHttpClient.get('/api/events/$eventId');
    return EventTime.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  List<Booking> _filterByStatus(List<Booking> all, BookingStatus status) {
    return all.where((b) => b.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text('My Bookings',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<Booking>>(
              future: _loadBookings(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.white));
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(color: Colors.white)),
                  );
                }
                final all = snap.data!;
                return TabBarView(
                  // ← disable swipe between tabs
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildTabContent(all, BookingStatus.Booked),
                    _buildTabContent(all, BookingStatus.CheckedOut),
                    _buildTabContent(all, BookingStatus.Booked /* no Cancelled status */),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(List<Booking> all, BookingStatus status) {
    final bookings = _filterByStatus(all, status);
    if (bookings.isEmpty) {
      return const Center(
          child: Text('No bookings', style: TextStyle(color: Colors.white70)));
    }

    // group by human-readable date
    final byDate = <String, List<Booking>>{};
    for (var b in bookings) {
      final key = DateFormat.yMMMMEEEEd().format(b.eventDate);
      byDate.putIfAbsent(key, () => []).add(b);
    }

    return RefreshIndicator(
      onRefresh: () async {
        // trigger FutureBuilder reload
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: byDate.entries.expand((entry) sync* {
          yield Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(entry.key,
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w600)),
          );
          for (var b in entry.value) {
            yield _BookingCard(
              booking:  b,
              fetchTime: () => _fetchEventTime(b.eventId),
            );
          }
        }).toList(),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking                  booking;
  final Future<EventTime> Function() fetchTime;

  const _BookingCard({
    Key? key,
    required this.booking,
    required this.fetchTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TicketDetailView(booking: booking),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: FutureBuilder<EventTime>(
            future: fetchTime(),
            builder: (ctx, snap) {
              final start = snap.hasData ? snap.data!.startTime : '…';
              final end   = snap.hasData ? snap.data!.endTime   : '…';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Booking for',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(booking.eventName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Starts $start   Ends $end',
                      style: const TextStyle(color: Colors.white70)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
