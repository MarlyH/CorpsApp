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

    // "unknown" or sentinel -> short fallback window so logic still works
    final isZero =
        (time.endTime == null) ||
        time.endTime == '00:00' ||
        time.endTime == '00:00:00';

    // If we DO have an end-time but it's <= start, assume it crosses midnight (+1 day)
    if (!isZero && !parsedEnd.isAfter(startDateTime)) {
      endDateTime = parsedEnd.add(const Duration(days: 1));
    } else if (!isZero) {
      endDateTime = parsedEnd;
    } else {
      endDateTime = startDateTime.add(const Duration(minutes: 15));
    }
  }
}

// Buckets: striked now lives under "concluded"
enum _Bucket { upcoming, concluded, cancelled }

// Concluded filter choices
enum _ConcludedFilter { all, checkedOut, striked }

class TicketsFragment extends StatefulWidget {
  const TicketsFragment({super.key});
  @override
  State<TicketsFragment> createState() => _TicketsFragmentState();
}

class _TicketsFragmentState extends State<TicketsFragment>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<List<_BookingWithTime>> _futureBookings;

  // filter state for "Concluded" tab
  _ConcludedFilter _concludedFilter = _ConcludedFilter.all;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this); // 3 tabs now
    _loadAll();
  }

  void _loadAll() {
    final f = _fetchAllWithTimes();
    setState(() {
      _futureBookings = f;
    });
  }

  Future<void> _refresh() async {
    final f = _fetchAllWithTimes();
    setState(() {
      _futureBookings = f;
    });
    await f;
  }

  Future<List<_BookingWithTime>> _fetchAllWithTimes() async {
    final resp = await AuthHttpClient.get('/api/booking/my');
    final list =
        (jsonDecode(resp.body) as List)
            .cast<Map<String, dynamic>>()
            .map(Booking.fromJson)
            .toList();

    return Future.wait(
      list.map((b) async {
        try {
          final evtResp = await AuthHttpClient.get('/api/events/${b.eventId}');
          final js = jsonDecode(evtResp.body) as Map<String, dynamic>;
          final t = EventTime(
            (js['startTime'] ?? js['StartTime']) as String?,
            (js['endTime'] ?? js['EndTime']) as String?,
          );
          return _BookingWithTime(b, t);
        } catch (_) {
          // fall back only if the event fetch fails
          return _BookingWithTime(b, EventTime('00:00', '00:00'));
        }
      }),
    );
  }

  _Bucket _classify(_BookingWithTime bt) {
    final s = bt.booking.status;

    if (s == BookingStatus.Cancelled) return _Bucket.cancelled;
    if (s == BookingStatus.Striked) return _Bucket.concluded; // moved here

    final now = DateTime.now();
    if (s == BookingStatus.CheckedOut || now.isAfter(bt.endDateTime)) {
      return _Bucket.concluded;
    }
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
                dividerColor: Colors.transparent,
                dividerHeight: 0,
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
                  Tab(text: 'Concluded'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
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

                  final data = snap.data ?? [];
                  final upcoming = <_BookingWithTime>[];
                  final concluded = <_BookingWithTime>[];
                  final cancelled = <_BookingWithTime>[];

                  for (final bt in data) {
                    switch (_classify(bt)) {
                      case _Bucket.upcoming:
                        upcoming.add(bt);
                        break;
                      case _Bucket.concluded:
                        concluded.add(bt);
                        break;
                      case _Bucket.cancelled:
                        cancelled.add(bt);
                        break;
                    }
                  }

                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _buildList(
                        upcoming,
                        allowCancel: true,
                        dateFmtHeader: dateFmtHeader,
                      ),
                      _buildConcludedList(
                        concluded,
                        dateFmtHeader: dateFmtHeader,
                      ),
                      _buildList(
                        cancelled,
                        allowCancel: false,
                        dateFmtHeader: dateFmtHeader,
                      ),
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

  /// Generic list builder used by Upcoming and Cancelled
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
            Center(
              child: Text('No bookings', style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 400),
          ],
        ),
      );
    }

    final Map<DateTime, List<_BookingWithTime>> byDate = {};
    for (final bt in list) {
      final d = bt.booking.eventDate;
      final dateKey = DateTime(d.year, d.month, d.day);
      byDate.putIfAbsent(dateKey, () => []).add(bt);
    }

    final dateKeys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final key in dateKeys) {
      final headerLabel = dateFmtHeader.format(key);
      final day =
          byDate[key]!
            ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
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
          return _BookingCard(
            key: ValueKey('b:${bt.booking.bookingId}'),
            bt: bt,
            allowCancel: allowCancel,
            onCancelled: (_) => _loadAll(),
            bucket: _classify(bt),
          );
        },
      ),
    );
  }

  /// Concluded list with filter controls
  Widget _buildConcludedList(
    List<_BookingWithTime> list, {
    required DateFormat dateFmtHeader,
  }) {
    // Apply filter
    final filtered = switch (_concludedFilter) {
      _ConcludedFilter.checkedOut =>
        list
            .where((bt) => bt.booking.status == BookingStatus.CheckedOut)
            .toList(),
      _ConcludedFilter.striked =>
        list.where((bt) => bt.booking.status == BookingStatus.Striked).toList(),
      _ => List<_BookingWithTime>.from(list),
    };

    if (filtered.isEmpty) {
      return Column(
        children: [
          _ConcludedFilterBar(
            selected: _concludedFilter,
            onChanged: (val) => setState(() => _concludedFilter = val),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Text(
                      'No concluded bookings',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Group by date and reuse the card UI
    final Map<DateTime, List<_BookingWithTime>> byDate = {};
    for (final bt in filtered) {
      final d = bt.booking.eventDate;
      final dateKey = DateTime(d.year, d.month, d.day);
      byDate.putIfAbsent(dateKey, () => []).add(bt);
    }

    final items = <_Item>[];
    final dateKeys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final key in dateKeys) {
      final headerLabel = dateFmtHeader.format(key);
      final day =
          byDate[key]!
            ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
      items.add(_Header(headerLabel));
      for (final bt in day!) {
        items.add(_Row(bt));
      }
    }

    return Column(
      children: [
        _ConcludedFilterBar(
          selected: _concludedFilter,
          onChanged: (val) => setState(() => _concludedFilter = val),
        ),
        Expanded(
          child: RefreshIndicator(
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
                return _BookingCard(
                  key: ValueKey('b:${bt.booking.bookingId}'),
                  bt: bt,
                  allowCancel: false,
                  onCancelled: (_) => _loadAll(),
                  bucket: _Bucket.concluded,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ConcludedFilterBar extends StatelessWidget {
  final _ConcludedFilter selected;
  final ValueChanged<_ConcludedFilter> onChanged;

  const _ConcludedFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final baseChip = ChipTheme.of(context);

    // State-based background color
    final MaterialStateProperty<Color?> chipFill =
        MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(MaterialState.selected)) {
            return Colors.white;
          }
          return Colors.transparent;
        });

    // State-based border
    final MaterialStateProperty<BorderSide?> chipBorder =
        MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const BorderSide(color: Colors.black, width: 1.2);
          }
          return BorderSide(color: Colors.grey[400]!, width: 1.0);
        });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Theme(
        data: baseTheme.copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          chipTheme: baseChip.copyWith(
            backgroundColor: Colors.transparent,
            selectedColor: Colors.white,
            secondarySelectedColor: Colors.white,
            disabledColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
        ),
        child: Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(
                'All',
                style: TextStyle(
                  color:
                      selected == _ConcludedFilter.all
                          ? Colors.black
                          : const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
              selected: selected == _ConcludedFilter.all,
              showCheckmark: true,
              surfaceTintColor: Colors.transparent,
              color: chipFill,
              onSelected: (_) => onChanged(_ConcludedFilter.all),
            ),
            ChoiceChip(
              label: Text(
                'Checked Out',
                style: TextStyle(
                  color:
                      selected == _ConcludedFilter.checkedOut
                          ? Colors.black
                          : const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
              selected: selected == _ConcludedFilter.checkedOut,
              showCheckmark: true,
              surfaceTintColor: Colors.transparent,
              color: chipFill,

              onSelected: (_) => onChanged(_ConcludedFilter.checkedOut),
            ),
            ChoiceChip(
              label: Text(
                'Striked',
                style: TextStyle(
                  color:
                      selected == _ConcludedFilter.striked
                          ? Colors.black
                          : const Color.fromARGB(255, 255, 255, 255),
                ),
              ),
              selected: selected == _ConcludedFilter.striked,
              showCheckmark: true,
              surfaceTintColor: Colors.transparent,
              color: chipFill,

              onSelected: (_) => onChanged(_ConcludedFilter.striked),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final _BookingWithTime bt;
  final bool allowCancel;
  final void Function(Booking) onCancelled;
  final _Bucket bucket;

  String _format12hFromRawOnDay(String? raw, DateTime day, {bool dashOnZero = false}) {
    if (raw == null || raw.trim().isEmpty) return '—';
    final isZero = raw == '00:00' || raw == '00:00:00' || raw == '0:00' || raw == '0:00:00';
    if (dashOnZero && isZero) return '—';

    final parts = raw.split(':');
    int h = 0, m = 0;
    if (parts.isNotEmpty) h = int.tryParse(parts[0]) ?? 0;
    if (parts.length > 1) m = int.tryParse(parts[1]) ?? 0;

    final dt = DateTime(day.year, day.month, day.day, h, m);
    return DateFormat('h:mm a').format(dt); // e.g., 1:05 PM
  }


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

    final startLabel = _format12hFromRawOnDay(time.startTime, booking.eventDate);
    final endLabel = _format12hFromRawOnDay(time.endTime,booking.eventDate, dashOnZero: true);


    final now = DateTime.now();
    final isLive =
        now.isAfter(bt.startDateTime) && now.isBefore(bt.endDateTime);
    final isMissed =
        bucket == _Bucket.concluded &&
        booking.status != BookingStatus.CheckedOut &&
        booking.status != BookingStatus.Striked;

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
              builder:
                  (_) => TicketDetailView(
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
                        const Text(
                          'Booking for',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
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
                      'Starts $startLabel • Ends $endLabel',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
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

      case _Bucket.concluded:
        if (s == BookingStatus.Striked) {
          label = 'STRIKED';
          bg = Colors.red.shade700;
        } else if (s == BookingStatus.CheckedOut) {
          label = 'CHECKED OUT';
          bg = Colors.grey.shade800;
        } else {
          label = missed ? 'MISSED' : 'COMPLETED';
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

abstract class _Item {
  const _Item();
}

class _Header extends _Item {
  final String label;
  const _Header(this.label);
}

class _Row extends _Item {
  final _BookingWithTime bt;
  const _Row(this.bt);
}
