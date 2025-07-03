import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import '../services/auth_http_client.dart';
import '../views/ticket_detail_view.dart';

class EventTime {
  final String startTime;
  final String endTime;
  EventTime(this.startTime, this.endTime);
  factory EventTime.fromJson(Map<String, dynamic> json) =>
      EventTime(json['startTime'] as String, json['endTime'] as String);
}

// Wraps a Booking plus its fetched EventTime and a parsed startDateTime.
class _BookingWithTime {
  final Booking booking;
  final EventTime time;
  late final DateTime startDateTime;

  _BookingWithTime(this.booking, this.time) {
    // parse "HH:mm:ss"
    final parts = time.startTime.split(':').map(int.parse).toList();
    final d = booking.eventDate;
    startDateTime = DateTime(d.year, d.month, d.day, parts[0], parts[1], parts[2]);
  }
}

class TicketsFragment extends StatefulWidget {
  const TicketsFragment({Key? key}) : super(key: key);
  @override
  _TicketsFragmentState createState() => _TicketsFragmentState();
}

class _TicketsFragmentState extends State<TicketsFragment>
    with SingleTickerProviderStateMixin {
  late Future<List<_BookingWithTime>> _futureBookings;
  late TabController _tabs;
  final Set<int> _cancelledIds = {}; // track cancelled bookingIds in-session

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
    // fetch raw bookings
    final resp = await AuthHttpClient.get('/api/Booking/my');
    final list = (jsonDecode(resp.body) as List<dynamic>)
        .cast<Map<String,dynamic>>()
        .map(Booking.fromJson)
        .toList();

    // fetch all their EventTime in parallel
    final futures = list.map((b) async {
      final evtR = await AuthHttpClient.get('/api/events/${b.eventId}');
      final evt = EventTime.fromJson(jsonDecode(evtR.body) as Map<String,dynamic>);
      return _BookingWithTime(b, evt);
    }).toList();

    return await Future.wait(futures);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _isExpired(_BookingWithTime bt) {
    // expired if now > start + 15m
    return DateTime.now().isAfter(bt.startDateTime.add(const Duration(minutes: 15)));
  }

  bool _isUpcoming(_BookingWithTime bt) {
    return bt.booking.status == BookingStatus.Booked &&
      !_cancelledIds.contains(bt.booking.bookingId) &&
      !_isExpired(bt);
  }

  bool _isCompleted(_BookingWithTime bt) {
    return !_cancelledIds.contains(bt.booking.bookingId) &&
      (bt.booking.status == BookingStatus.CheckedOut || _isExpired(bt));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text('My Bookings',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TabBar(
          controller: _tabs,
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
          child: FutureBuilder<List<_BookingWithTime>>(
            future: _futureBookings,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.white)));
              }
              final all = snap.data!;
              return TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildList(all.where(_isUpcoming).toList(), allowCancel: true),
                  _buildList(all.where(_isCompleted).toList(), allowCancel: false),
                  _buildList(
                    all.where((bt) => _cancelledIds.contains(bt.booking.bookingId)).toList(),
                    allowCancel: false,
                  ),
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
      return const Center(child: Text('No bookings', style: TextStyle(color: Colors.white70)));
    }
    // group by formatted date
    final byDate = <String,List<_BookingWithTime>>{};
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
        padding: const EdgeInsets.all(8),
        children: byDate.entries.expand((entry) sync* {
          yield Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(entry.key,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          );
          for (var bt in entry.value) {
            yield _BookingCard(
              booking:     bt.booking,
              time:        bt.time,
              allowCancel: allowCancel,
              onCancelled: (b) => setState(() => _cancelledIds.add(b.bookingId)),
            );
          }
        }).toList(),
      ),
    );
  }
}

// Single booking card: taps push to detail, returns Booking if cancelled.
class _BookingCard extends StatelessWidget {
  final Booking      booking;
  final EventTime    time;
  final bool         allowCancel;
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
    // show within 15m late badge?
    final now = DateTime.now();
    final parts = time.startTime.split(':').map(int.parse).toList();
    final sd = booking.eventDate;
    final startDT = DateTime(sd.year, sd.month, sd.day, parts[0], parts[1], parts[2]);
    final isLate = now.isAfter(startDT) && now.isBefore(startDT.add(const Duration(minutes:15)));

    return Card(
      color: Colors.grey.shade800,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('Booking for',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                if (isLate)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('LATE',
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
              ]),
              Text(booking.eventName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Starts ${time.startTime}   Ends ${time.endTime}',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
