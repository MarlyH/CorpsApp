import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import '../services/auth_http_client.dart';
import '../views/ticket_detail_view.dart';

class EventTime {
  final String startTime, endTime;
  EventTime(this.startTime, this.endTime);
  factory EventTime.fromJson(Map<String, dynamic> j) =>
      EventTime(j['startTime'] as String, j['endTime'] as String);
}

class _BookingWithTime {
  final Booking booking;
  final EventTime time;
  late final DateTime startDateTime;

  _BookingWithTime(this.booking, this.time) {
    final parts = time.startTime.split(':').map(int.parse).toList();
    final d     = booking.eventDate;
    startDateTime = DateTime(d.year, d.month, d.day, parts[0], parts[1]);
  }
}

class TicketsFragment extends StatefulWidget {
  const TicketsFragment({Key? key}) : super(key: key);
  @override
  State<TicketsFragment> createState() => _TicketsFragmentState();
}

class _TicketsFragmentState extends State<TicketsFragment>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<List<_BookingWithTime>> _futureBookings;
  final Set<int> _cancelledIds = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  void _loadAll() {
    _futureBookings = _fetchAllWithTimes();
  }

  Future<List<_BookingWithTime>> _fetchAllWithTimes() async {
    final resp = await AuthHttpClient.get('/api/booking/my');
    final list = (jsonDecode(resp.body) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Booking.fromJson)
        .toList();

    return Future.wait(list.map((b) async {
      final evtResp = await AuthHttpClient.get('/api/events/${b.eventId}');
      final time    = EventTime.fromJson(jsonDecode(evtResp.body));
      return _BookingWithTime(b, time);
    }));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _isExpired(_BookingWithTime bt) =>
      DateTime.now().isAfter(bt.startDateTime.add(const Duration(minutes: 15)));

  bool _isUpcoming(_BookingWithTime bt) =>
      bt.booking.status == BookingStatus.Booked &&
      !_isExpired(bt) &&
      !_cancelledIds.contains(bt.booking.bookingId);

  bool _isCompleted(_BookingWithTime bt) =>
      (bt.booking.status == BookingStatus.CheckedOut || _isExpired(bt)) &&
      !_cancelledIds.contains(bt.booking.bookingId);

  bool _isCancelled(_BookingWithTime bt) =>
      _cancelledIds.contains(bt.booking.bookingId);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'MY TICKETS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: TabBar(
            controller: _tabs,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey.shade600,
            indicator: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(32),
            ),
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: FutureBuilder<List<_BookingWithTime>>(
            future: _futureBookings,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }
              if (snap.hasError) {
                return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(color: Colors.white)));
              }
              final all = snap.data!;
              return TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildList(all.where(_isUpcoming).toList(), allowCancel: true),
                  _buildList(all.where(_isCompleted).toList(), allowCancel: false),
                  _buildList(all.where(_isCancelled).toList(), allowCancel: false),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<_BookingWithTime> list, {required bool allowCancel}) {
    if (list.isEmpty) {
      return const Center(
          child: Text('No bookings', style: TextStyle(color: Colors.white70)));
    }

    final byDate = <String, List<_BookingWithTime>>{};
    for (var bt in list) {
      final key = DateFormat.yMMMMEEEEd().format(bt.booking.eventDate);
      byDate.putIfAbsent(key, () => []).add(bt);
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadAll();
        setState(() {});
        await _futureBookings;
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: byDate.entries.expand((entry) sync* {
          yield Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(entry.key,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          );
          for (var bt in entry.value) {
            yield _BookingCard(
              booking: bt.booking,
              time:    bt.time,
              allowCancel: allowCancel,
              onCancelled: (b) => setState(() => _cancelledIds.add(b.bookingId)),
            );
          }
        }).toList(),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final EventTime time;
  final bool allowCancel;
  final void Function(Booking) onCancelled;

  const _BookingCard({
    Key? key,
    required this.booking,
    required this.time,
    required this.allowCancel,
    required this.onCancelled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final parts = time.startTime.split(':').map(int.parse).toList();
    final sd    = booking.eventDate;
    final start = DateTime(sd.year, sd.month, sd.day, parts[0], parts[1]);
    final isLate = DateTime.now().isAfter(start) &&
        DateTime.now().isBefore(start.add(const Duration(minutes: 15)));

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final result = await Navigator.push<Booking?>(
            context,
            MaterialPageRoute(
              builder: (_) => TicketDetailView(
                booking: booking,
                allowCancel: allowCancel,
              ),
            ),
          );
          if (result != null) onCancelled(result);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(children: [
            Text('Booking for',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              booking.attendeeName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (isLate)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('LATE',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Starts ${time.startTime}   Ends ${time.endTime}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ]),
        ),
      ),
    );
  }
}
