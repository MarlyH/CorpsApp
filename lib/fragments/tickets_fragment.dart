import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import '../services/auth_http_client.dart';
import '../views/ticket_detail_view.dart';

/// Simple holder for an event’s start/end times
class EventTime {
  final String startTime, endTime;
  EventTime(this.startTime, this.endTime);
  factory EventTime.fromJson(Map<String, dynamic> j) =>
      EventTime(j['startTime'] as String, j['endTime'] as String);
}

/// Couples a Booking with its parsed start DateTime
class _BookingWithTime {
  final Booking booking;
  final EventTime time;
  late final DateTime startDateTime;

  _BookingWithTime(this.booking, this.time) {
    // parse safely—stubbed '00:00' will parse without error
    final parts = time.startTime.split(':').map(int.parse).toList();
    final d = booking.eventDate;
    startDateTime = DateTime(d.year, d.month, d.day, parts[0], parts[1]);
  }
}

class TicketsFragment extends StatefulWidget {
  const TicketsFragment({super.key});
  @override
  State<TicketsFragment> createState() => _TicketsFragmentState();
}

class _TicketsFragmentState extends State<TicketsFragment>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<List<_BookingWithTime>> _futureBookings;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _futureBookings = _fetchAllWithTimes();
    });
  }

  Future<List<_BookingWithTime>> _fetchAllWithTimes() async {
    final resp = await AuthHttpClient.get('/api/booking/my');
    final list = (jsonDecode(resp.body) as List)
        .cast<Map<String, dynamic>>()
        .map(Booking.fromJson)
        .toList();

    return Future.wait(list.map((b) async {
      EventTime time;

      // 1) If the booking is already cancelled, stub valid zeros
      if (b.status == BookingStatus.Cancelled) {
        time = EventTime('00:00', '00:00');
      } else {
        // 2) Otherwise attempt network fetch, fallback to zeros on error
        try {
          final evtResp =
              await AuthHttpClient.get('/api/events/${b.eventId}');
          time = EventTime.fromJson(jsonDecode(evtResp.body));
        } catch (_) {
          time = EventTime('00:00', '00:00');
        }
      }

      return _BookingWithTime(b, time);
    }));
  }

  bool _isExpired(_BookingWithTime bt) =>
      DateTime.now().isAfter(bt.startDateTime.add(const Duration(minutes: 15)));

  bool _isUpcoming(_BookingWithTime bt) =>
      bt.booking.status == BookingStatus.Booked && !_isExpired(bt);

  bool _isCompleted(_BookingWithTime bt) =>
      bt.booking.status == BookingStatus.CheckedOut || _isExpired(bt);

  bool _isCancelled(_BookingWithTime bt) =>
      bt.booking.status == BookingStatus.Cancelled;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        
        child: Column(
          children: [
            const Text(
              'MY TICKETS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Pill‐style TabBar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: TabBar(
                controller: _tabs,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black,
                indicator: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(32),
                ),
                indicatorPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                tabs: const [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Swipeable pages
            Expanded(
              child: FutureBuilder<List<_BookingWithTime>>(
                future: _futureBookings,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text('Error: ${snap.error}',
                          style:
                              const TextStyle(color: Colors.white)),
                    );
                  }
                  final all = snap.data!;
                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _buildList(
                          all.where(_isUpcoming).toList(),
                          allowCancel: true),
                      _buildList(
                          all.where(_isCompleted).toList(),
                          allowCancel: false),
                      _buildList(
                          all.where(_isCancelled).toList(),
                          allowCancel: false),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<_BookingWithTime> list,
      {required bool allowCancel}) {
    if (list.isEmpty) {
      return const Center(
          child:
              Text('No bookings', style: TextStyle(color: Colors.white)));
    }

    final byDate = <String, List<_BookingWithTime>>{};
    for (var bt in list) {
      final key = DateFormat.yMMMMEEEEd()
          .format(bt.booking.eventDate);
      byDate.putIfAbsent(key, () => []).add(bt);
    }

    return RefreshIndicator(
      onRefresh: () async => _loadAll(),
      child: ListView(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: byDate.entries.expand((entry) sync* {
          yield Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              entry.key,
              style:
                  const TextStyle(color: Colors.white, fontSize: 14),
            ),
          );
          for (var bt in entry.value) {
            yield _BookingCard(
              booking: bt.booking,
              time: bt.time,
              allowCancel: allowCancel,
              onCancelled: (_) => _loadAll(),
            );
          }
        }).toList(),
      ),
    );
  }
}

/// Booking card now shows “CANCELLED” for cancelled tickets
class _BookingCard extends StatelessWidget {
  final Booking booking;
  final EventTime time;
  final bool allowCancel;
  final void Function(Booking) onCancelled;

  const _BookingCard({
    required this.booking,
    required this.time,
    required this.allowCancel,
    required this.onCancelled,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled =
        booking.status == BookingStatus.Cancelled;

    // compute “late” only if not cancelled
    bool isLate = false;
    if (!isCancelled) {
      final parts =
          time.startTime.split(':').map(int.parse).toList();
      final sd = booking.eventDate;
      final start = DateTime(
          sd.year, sd.month, sd.day, parts[0], parts[1]);
      isLate = DateTime.now().isAfter(start) &&
          DateTime.now().isBefore(
              start.add(const Duration(minutes: 15)));
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final didCancel = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => TicketDetailView(
                booking: booking,
                allowCancel: allowCancel,
              ),
            ),
          );
          if (didCancel == true) onCancelled(booking);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 16, horizontal: 12),
          child: Column(
            children: [
              const Text('Booking for',
                  style: TextStyle(
                      color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                booking.attendeeName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold),
              ),

              // “Late” pill, only for non-cancelled
              if (isLate)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius:
                            BorderRadius.circular(4)),
                    child: const Text('LATE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10)),
                  ),
                ),

              const SizedBox(height: 8),

              // Show CANCELLED badge _or_ times
              if (isCancelled)
                Text(
                  'CANCELLED',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Text(
                  'Starts ${time.startTime}   Ends ${time.endTime}',
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
