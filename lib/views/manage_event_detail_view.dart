import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/event_summary.dart';
import '../services/auth_http_client.dart';

class ManageEventDetailView extends StatefulWidget {
  final EventSummary event;
  const ManageEventDetailView({super.key, required this.event});

  @override
  _ManageEventDetailViewState createState() => _ManageEventDetailViewState();
}

class _ManageEventDetailViewState extends State<ManageEventDetailView> {
  bool _loading = true;
  List<_Attendee> _attendees = [];

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    setState(() => _loading = true);
    try {
      final resp = await AuthHttpClient.get(
        '/api/events/${widget.event.eventId}/attendees',
      );
      final data = jsonDecode(resp.body);

      if (data is! List) {
        throw 'Unexpected payload (expected List)';
      }

      _attendees = data.map<_Attendee>((m) {
        // bookingId (allow number or string)
        final bookingId = (m['bookingId'] is num)
            ? (m['bookingId'] as num).toInt()
            : int.tryParse(m['bookingId']?.toString() ?? '') ?? 0;

        // name (coerce to string)
        final name = (m['name'] == null) ? 'Unknown' : m['name'].toString();

        // status may come as "CheckedIn" or 1, etc.
        final dynamic statusRaw = m['status'];
        final status = (statusRaw is String)
            ? _statusFromString(statusRaw)
            : (statusRaw is num)
                ? _statusFromInt(statusRaw.toInt())
                : BookingStatusX.booked;

        // seatNumber (number or string or null)
        final dynamic seatRaw = m['seatNumber'];
        final seatNumber = (seatRaw is num)
            ? seatRaw.toInt()
            : int.tryParse(seatRaw?.toString() ?? '');

        final isForChild = m['isForChild'] == true;

        return _Attendee(
          bookingId: bookingId,
          name: name,
          status: status,
          seatNumber: seatNumber,
          isForChild: isForChild,
        );
      }).toList();
    } catch (e) {
      _snack('Error loading attendees: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(_Attendee at, BookingStatusX newStatus) async {
    setState(() => _loading = true);
    try {
      final payload = jsonEncode({
        'bookingId': at.bookingId,
        'newStatus': _statusToInt(newStatus),
      });

      final resp = await AuthHttpClient.postRaw(
        '/api/booking/manual-status',
        body: payload,
        headers: {'Content-Type': 'application/json'},
      );

      if (resp.statusCode == 200) {
        setState(() => at.status = newStatus);
        _snack('Updated ${at.name} → ${_labelFor(newStatus)}');
      } else {
        _snack('Save failed (${resp.statusCode}): ${resp.body}', error: true);
      }
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black)),
        backgroundColor: error ? Colors.redAccent : Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'My Events',
          style: TextStyle(
            letterSpacing: 1.2,
            fontFamily: 'WinnerSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              color: Colors.white,
              onRefresh: _loadAttendees,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(e.locationName, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            const Spacer(),
                            Text(friendlySession(e.sessionType), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // day + date line
                        Text(
                          niceDayDate(e.startDate),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 4),
                        Text(
                          'Starts ${e.startTime} • Ends ${e.endTime}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text('Attendees', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),

                  if (_attendees.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No attendees yet',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    )
                  else
                    ..._attendees.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final at = entry.value;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            // name + seat
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${idx + 1}. ${at.name}',
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  if (at.seatNumber != null)
                                    Text('Seat ${at.seatNumber}',
                                        style: const TextStyle(
                                            color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            // status dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: DropdownButton<BookingStatusX>(
                                value: at.status,
                                underline: const SizedBox.shrink(),
                                dropdownColor: Colors.grey[900],
                                iconEnabledColor: Colors.white70,
                                items: BookingStatusX.values.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(_labelFor(s),
                                        style:
                                            const TextStyle(color: Colors.white)),
                                  );
                                }).toList(),
                                onChanged: (s) {
                                  if (s != null && s != at.status) {
                                    _updateStatus(at, s);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

// Local model & helpers

/// Local booking status used by the UI
enum BookingStatusX { booked, checkedIn, checkedOut, cancelled }

BookingStatusX _statusFromString(String s) {
  switch (s.toLowerCase()) {
    case 'checkedin':
      return BookingStatusX.checkedIn;
    case 'checkedout':
      return BookingStatusX.checkedOut;
    case 'cancelled':
      return BookingStatusX.cancelled;
    case 'booked':
    default:
      return BookingStatusX.booked;
  }
}
int _statusToInt(BookingStatusX s) {
  switch (s) {
    case BookingStatusX.booked:return 0; // Booked
    case BookingStatusX.checkedIn:return 1; // CheckedIn
    case BookingStatusX.checkedOut:return 2; // CheckedOut
    case BookingStatusX.cancelled:return 3; // Cancelled
  }
}


/// backend sends an enum as int (C# default: Booked=0, CheckedIn=1, CheckedOut=2, Cancelled=3)
BookingStatusX _statusFromInt(int v) {
  switch (v) {
    case 1:
      return BookingStatusX.checkedIn;
    case 2:
      return BookingStatusX.checkedOut;
    case 3:
      return BookingStatusX.cancelled;
    case 0:
    default:
      return BookingStatusX.booked;
  }
}

String _labelFor(BookingStatusX s) {
  switch (s) {
    case BookingStatusX.booked:
      return 'Not Arrived';
    case BookingStatusX.checkedIn:
      return 'Checked In';
    case BookingStatusX.checkedOut:
      return 'Checked Out';
    case BookingStatusX.cancelled:
      return 'Cancelled';
  }
}

class _Attendee {
  final int bookingId;
  final String name;
  BookingStatusX status; // mutable so we can update in-place
  final int? seatNumber;
  final bool isForChild;

  _Attendee({
    required this.bookingId,
    required this.name,
    required this.status,
    this.seatNumber,
    required this.isForChild,
  });
}

// view helpers
String friendlySession(SessionType type) {
  switch (type) {
    case SessionType.Ages8to11:
      return 'Ages 8 to 11';
    case SessionType.Ages12to15:
      return 'Ages 12 to 15';
    default:
      return 'Ages 16+';
  }
}
// a nice formatted date string
String niceDayDate(DateTime d) {
  const week = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  const mon  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final local = d.toLocal();
  return '${week[local.weekday - 1]} • ${local.day.toString().padLeft(2, '0')} ${mon[local.month - 1]} ${local.year}';
}