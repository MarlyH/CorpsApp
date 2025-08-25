import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import '../services/auth_http_client.dart';
import '../views/ticket_detail_view.dart';

class EventTime {
  final String? startTime;
  final String? endTime;
  EventTime(this.startTime, this.endTime);

  factory EventTime.fromJson(Map<String, dynamic> j) =>
      EventTime(j['startTime'] as String?, j['endTime'] as String?);
}

class _BookingWithTime {
  final Booking booking;
  final EventTime time;
  late final DateTime startDateTime;
  late final DateTime endDateTime;

  _BookingWithTime(this.booking, this.time) {
    DateTime _parse(String? hhmm) {
      // Accept: HH:mm, HH:mm:ss, null/empty
      if (hhmm == null || hhmm.trim().isEmpty) {
        final d = booking.eventDate;
        return DateTime(d.year, d.month, d.day); // midnight
      }
      final parts = hhmm.split(':');
      int h = 0, m = 0;
      if (parts.isNotEmpty) h = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1) m = int.tryParse(parts[1]) ?? 0;
      final d = booking.eventDate;
      return DateTime(d.year, d.month, d.day, h, m);
    }

    startDateTime = _parse(time.startTime);
    final parsedEnd = _parse(time.endTime);

    // If end is the same as start or clearly zero, fallback to +15m
    final isZero = (time.endTime == null) ||
                   time.endTime == '00:00' ||
                   time.endTime == '00:00:00';
    endDateTime = (isZero || !parsedEnd.isAfter(startDateTime))
        ? startDateTime.add(const Duration(minutes: 15))
        : parsedEnd;
  }
}

enum _Bucket { upcoming, completed, cancelled }

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
    final f = _fetchAllWithTimes();
    // IMPORTANT: setState is NOT async
    setState(() {
      _futureBookings = f;
    });
  }

  Future<void> _refresh() async {
    final f = _fetchAllWithTimes();
    setState(() {
      _futureBookings = f;
    });
    await f; // let the pull-to-refresh spinner wait for data
  }

  Future<List<_BookingWithTime>> _fetchAllWithTimes() async {
    final resp = await AuthHttpClient.get('/api/booking/my');
    final list = (jsonDecode(resp.body) as List)
        .cast<Map<String, dynamic>>()
        .map(Booking.fromJson)
        .toList();

    return Future.wait(list.map((b) async {
      EventTime t;
      if (b.status == BookingStatus.Cancelled) {
        t = EventTime('00:00', '00:00');
      } else {
        try {
          final evtResp = await AuthHttpClient.get('/api/events/${b.eventId}');
          final js = jsonDecode(evtResp.body) as Map<String, dynamic>;
          // Be tolerant to different casing/paths
          t = EventTime(
            (js['startTime'] ?? js['StartTime']) as String?,
            (js['endTime'] ?? js['EndTime']) as String?,
          );
        } catch (_) {
          t = EventTime('00:00', '00:00');
        }
      }
      return _BookingWithTime(b, t);
    }));
  }

  _Bucket _classify(_BookingWithTime bt) {
    final s = bt.booking.status;
    if (s == BookingStatus.Cancelled) return _Bucket.cancelled;

    final now = DateTime.now();
    if (s == BookingStatus.CheckedOut || now.isAfter(bt.endDateTime)) {
      return _Bucket.completed;
    }
    // Booked or CheckedIn, and not past end
    return _Bucket.upcoming;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmtHeader = DateFormat.yMMMMEEEEd();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            const Text(
              'MY Bookings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'WinnerSans',
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

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
                dividerColor: Colors.transparent,// remove devider bottom line fixxed
                dividerHeight: 0,
                indicator: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(32),
                ),
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                tabs: const [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              )
            ),

            const SizedBox(height: 12),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tap a booking to view details. Your entry QR code is inside.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: FutureBuilder<List<_BookingWithTime>>(
                future: _futureBookings,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (snap.hasError) {
                    // Show a scrollable error so PageView/Viewport stays happy
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Something went wrong. Pull to refresh.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          SizedBox(height: 400),
                        ],
                      ),
                    );
                  }
                  final data = snap.data;
                  if (data == null) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text('No data', style: TextStyle(color: Colors.white)),
                          ),
                          SizedBox(height: 400),
                        ],
                      ),
                    );
                  }

                  final upcoming = <_BookingWithTime>[];
                  final completed = <_BookingWithTime>[];
                  final cancelled = <_BookingWithTime>[];

                  for (final bt in data) {
                    switch (_classify(bt)) {
                      case _Bucket.upcoming:
                        upcoming.add(bt);
                        break;
                      case _Bucket.completed:
                        completed.add(bt);
                        break;
                      case _Bucket.cancelled:
                        cancelled.add(bt);
                        break;
                    }
                  }

                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _buildList(upcoming, allowCancel: true,  dateFmtHeader: dateFmtHeader),
                      _buildList(completed, allowCancel: false, dateFmtHeader: dateFmtHeader),
                      _buildList(cancelled, allowCancel: false, dateFmtHeader: dateFmtHeader),
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

 

  // Flattened + keyed list model to keep children stable
  Widget _buildList(
    List<_BookingWithTime> list, {
    required bool allowCancel,
    required DateFormat dateFmtHeader,
  }) {
    final items = <_Item>[];

    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('No bookings', style: TextStyle(color: Colors.white))),
            SizedBox(height: 400),
          ],
        ),
      );
    }

    // Group by pure date and sort keys NEWEST first
    final Map<DateTime, List<_BookingWithTime>> byDate = {};
    for (final bt in list) {
      final d = bt.booking.eventDate; // DateTime on the Flutter model
      final dateKey = DateTime(d.year, d.month, d.day); // strip time
      byDate.putIfAbsent(dateKey, () => []).add(bt);
    }

    final dateKeys = byDate.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // newest date first

    for (final key in dateKeys) {
      final headerLabel = dateFmtHeader.format(key);
      final day = byDate[key]!..sort(
        // newest start time first (desc)
        (a, b) => b.startDateTime.compareTo(a.startDateTime),
      );
      items.add(_Header(headerLabel));
      for (final bt in day!) {
        items.add(_Row(bt));
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final it = items[index];
          if (it is _Header) {
            return Padding(
              key: ValueKey('h:${it.label}'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                it.label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            );
          }
          final bt = (it as _Row).bt;
          final canCancelNow =
              allowCancel && DateTime.now().isBefore(bt.startDateTime);
          return _BookingCard(
            key: ValueKey('b:${bt.booking.bookingId}'),
            bt: bt,
            allowCancel: canCancelNow,
            onCancelled: (_) => _loadAll(),
            bucket: _classify(bt),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final _BookingWithTime bt;
  final bool allowCancel;
  final void Function(Booking) onCancelled;
  final _Bucket bucket;

  const _BookingCard({
    super.key,
    required this.bt,
    required this.allowCancel,
    required this.onCancelled,
    required this.bucket,
  });

  @override
  Widget build(BuildContext context) {
    final booking = bt.booking;
    final time = bt.time;

    final now = DateTime.now();
    final isLive = now.isAfter(bt.startDateTime) && now.isBefore(bt.endDateTime);
    final isMissed = bucket == _Bucket.completed &&
        booking.status != BookingStatus.CheckedOut;

    final chip = _statusChip(bucket, booking.status, isLive, isMissed);

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Booking for',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          booking.attendeeName,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  chip,
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Starts ${time.startTime ?? '—'} • Ends ${time.endTime ?? '—'}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ),
                ],
              ),
              // if (isMissed)
              //   Padding(
              //     padding: const EdgeInsets.only(top: 8),
              //     child: Text(
              //       'Did not attend',
              //       style: TextStyle(
              //         color: Colors.red.shade700,
              //         fontSize: 12,
              //         fontWeight: FontWeight.w600,
              //       ),
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(_Bucket b, BookingStatus s, bool isLive, bool missed) {
    String label;
    Color bg;
    switch (b) {
      case _Bucket.upcoming:
        if (s == BookingStatus.CheckedIn) {
          label = isLive ? 'CHECKED IN • LIVE' : 'CHECKED IN';
          bg = Colors.green.shade700;
        } else {
          label = isLive ? 'UPCOMING • LIVE' : 'UPCOMING';
          bg = Colors.black87;
        }
        break;
      case _Bucket.completed:
        if (missed) {
          label = 'MISSED';
          bg = Colors.grey.shade800;
        } else {
          label = 'COMPLETED';
          bg = Colors.grey.shade800;
        }
        break;
      case _Bucket.cancelled:
        label = 'CANCELLED';
        bg = Colors.grey.shade800;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

abstract class _Item { const _Item(); }
class _Header extends _Item { final String label; const _Header(this.label); }
class _Row extends _Item { final _BookingWithTime bt; const _Row(this.bt); }