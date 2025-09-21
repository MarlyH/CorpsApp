import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/event_summary.dart';
import '../services/auth_http_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';


class ManageEventDetailView extends StatefulWidget {
  final EventSummary event;
  const ManageEventDetailView({super.key, required this.event});
  

  @override
  _ManageEventDetailViewState createState() => _ManageEventDetailViewState();
}
enum _ActionKind { email, phone }

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
      final resp = await AuthHttpClient.get('/api/events/${widget.event.eventId}/attendees');
      final data = jsonDecode(resp.body);
      if (data is! List) throw 'Unexpected payload (expected List)';

      _attendees = data.map<_Attendee>((m) {
        final bookingId = (m['bookingId'] is num)
            ? (m['bookingId'] as num).toInt()
            : int.tryParse(m['bookingId']?.toString() ?? '') ?? 0;

        final name = (m['name'] == null) ? 'Unknown' : m['name'].toString();

        final dynamic statusRaw = m['status'];
        final status = (statusRaw is String)
            ? _statusFromString(statusRaw)
            : (statusRaw is num)
                ? _statusFromInt(statusRaw.toInt())
                : BookingStatusX.booked;

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

  Future<void> _openAttendeeDetail(_Attendee at) async {
    try {
      final resp = await AuthHttpClient.get('/api/BookingAdmin/detail/${at.bookingId}');
      if (resp.statusCode != 200) {
        _snack('Failed to load attendee detail (${resp.statusCode})', error: true);
        return;
      }
      final js = jsonDecode(resp.body) as Map<String, dynamic>;
      final detail = _AdminBookingDetail.fromJson(js);

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _AttendeeDetailSheet(detail: detail),
      );
    } catch (e) {
      _snack('Failed to load attendee detail: $e', error: true);
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
                  // header
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
                        Text(
                          niceDayDate(e.startDate),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Starts ${e.startTime} • Ends ${e.endTime}', style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Attendees', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  if (_attendees.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No attendees yet', style: TextStyle(color: Colors.white54))),
                    )
                  else
                    ..._attendees.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final at = entry.value;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _openAttendeeDetail(at), // ← open sheet
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    Text('${idx + 1}. ${at.name}', style: const TextStyle(color: Colors.white)),
                                    if (at.seatNumber != null)
                                      Text('Seat ${at.seatNumber}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
                                      child: Text(_labelFor(s), style: const TextStyle(color: Colors.white)),
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
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

// ==============================
// Models for admin detail sheet
// ==============================

class _AdminBookingDetail {
  final int bookingId;
  final int eventId;
  final String? eventName;
  final DateTime? eventDate;
  final int? seatNumber;
  final BookingStatusX status;
  final bool canBeLeftAlone;
  final String qrCodeData;
  final bool isForChild;
  final String attendeeName;

  // Reservation-related
  final bool isReserved;
  final String? reservedAttendeeName;
  final String? reservedPhone;
  final String? reservedGuardianName;

  final _AdminUserMini? user;
  final _ChildDto? child;

  _AdminBookingDetail({
    required this.bookingId,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.seatNumber,
    required this.status,
    required this.canBeLeftAlone,
    required this.qrCodeData,
    required this.isForChild,
    required this.attendeeName,
    required this.isReserved,
    required this.reservedAttendeeName,
    required this.reservedPhone,
    required this.reservedGuardianName,
    required this.user,
    required this.child,
  });

  factory _AdminBookingDetail.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        final s = v.toString();
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
          final p = s.split('-').map(int.parse).toList();
          return DateTime(p[0], p[1], p[2]);
        }
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    return _AdminBookingDetail(
      bookingId: (j['bookingId'] ?? 0) as int,
      eventId: (j['eventId'] ?? 0) as int,
      eventName: j['eventName']?.toString(),
      eventDate: parseDate(j['eventDate']),
      seatNumber: j['seatNumber'] as int?,
      status: _statusFromInt((j['status'] as int?) ?? 0),
      canBeLeftAlone: j['canBeLeftAlone'] == true,
      qrCodeData: (j['qrCodeData'] ?? '').toString(),
      isForChild: j['isForChild'] == true,
      attendeeName: (j['attendeeName'] ?? '').toString(),

      // Reservation fields
      isReserved: j['isReserved'] == true,
      reservedAttendeeName: j['reservedAttendeeName']?.toString(),
      reservedPhone: j['reservedPhone']?.toString(),
      reservedGuardianName: j['reservedGuardianName']?.toString(),

      user: j['user'] == null ? null : _AdminUserMini.fromJson(j['user'] as Map<String, dynamic>),
      child: j['child'] == null ? null : _ChildDto.fromJson(j['child'] as Map<String, dynamic>),
    );
  }

  // Use reserved name if present
  String get displayName =>
      isReserved && (reservedAttendeeName?.isNotEmpty ?? false)
          ? reservedAttendeeName!
          : attendeeName;
}

class _AdminUserMini {
  final String id;
  final String? email;
  final String? phoneNumber;
  final String firstName;
  final String lastName;
  final int strikes;
  final String? dateOfLastStrike;
  final bool isSuspended;

  _AdminUserMini({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.strikes,
    required this.dateOfLastStrike,
    required this.isSuspended,
  });

  factory _AdminUserMini.fromJson(Map<String, dynamic> j) => _AdminUserMini(
        id: (j['id'] ?? '').toString(),
        email: j['email']?.toString(),
        phoneNumber: j['phoneNumber']?.toString(),
        firstName: (j['firstName'] ?? '').toString(),
        lastName: (j['lastName'] ?? '').toString(),
        strikes: (j['attendanceStrikeCount'] as int?) ?? 0,
        dateOfLastStrike: j['dateOfLastStrike']?.toString(),
        isSuspended: j['isSuspended'] == true,
      );

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();
}

class _ChildDto {
  final int childId;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final int age;

  _ChildDto({
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.age,
  });

  factory _ChildDto.fromJson(Map<String, dynamic> j) {
    DateTime? parseDob(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      try {
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
          final p = s.split('-').map(int.parse).toList();
          return DateTime(p[0], p[1], p[2]);
        }
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    return _ChildDto(
      childId: (j['childId'] ?? j['ChildId'] ?? 0) as int,
      firstName: (j['firstName'] ?? j['FirstName'] ?? '').toString(),
      lastName: (j['lastName'] ?? j['LastName'] ?? '').toString(),
      dateOfBirth: parseDob(j['dateOfBirth'] ?? j['DateOfBirth']),
      emergencyContactName: (j['emergencyContactName'] ?? j['EmergencyContactName'] ?? '').toString(),
      emergencyContactPhone: (j['emergencyContactPhone'] ?? j['EmergencyContactPhone'] ?? '').toString(),
      age: (j['age'] ?? j['Age'] ?? 0) as int,
    );
  }

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();
}

// ==============================
// Local model & helpers (existing)
// ==============================

enum BookingStatusX { booked, checkedIn, checkedOut, cancelled, striked }

BookingStatusX _statusFromString(String s) {
  switch (s.toLowerCase()) {
    case 'checkedin':
      return BookingStatusX.checkedIn;
    case 'checkedout':
      return BookingStatusX.checkedOut;
    case 'cancelled':
      return BookingStatusX.cancelled;
    case 'striked':
      return BookingStatusX.striked;
    case 'booked':
    default:
      return BookingStatusX.booked;
  }
}

int _statusToInt(BookingStatusX s) {
  switch (s) {
    case BookingStatusX.booked: return 0;
    case BookingStatusX.checkedIn: return 1;
    case BookingStatusX.checkedOut: return 2;
    case BookingStatusX.cancelled: return 3;
    case BookingStatusX.striked: return 4;
  }
}

BookingStatusX _statusFromInt(int v) {
  switch (v) {
    case 1: return BookingStatusX.checkedIn;
    case 2: return BookingStatusX.checkedOut;
    case 3: return BookingStatusX.cancelled;
    case 4: return BookingStatusX.striked;
    default: return BookingStatusX.booked;
  }
}

String _labelFor(BookingStatusX s) {
  switch (s) {
    case BookingStatusX.booked: return 'Not Arrived';
    case BookingStatusX.checkedIn: return 'Checked In';
    case BookingStatusX.checkedOut: return 'Checked Out';
    case BookingStatusX.cancelled: return 'Cancelled';
    case BookingStatusX.striked: return 'Strike';
  }
}

class _Attendee {
  final int bookingId;
  final String name;
  BookingStatusX status;
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

// ==============================
// View helpers
// ==============================

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

String niceDayDate(DateTime d) {
  const week = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final local = d.toLocal();
  return '${week[local.weekday - 1]} • ${local.day.toString().padLeft(2, '0')} ${mon[local.month - 1]} ${local.year}';
}

// ==============================
// Detail bottom sheet
// ==============================

class _AttendeeDetailSheet extends StatelessWidget {
  final _AdminBookingDetail detail;
  const _AttendeeDetailSheet({required this.detail});
  


  @override
  Widget build(BuildContext context) {
    final user = detail.user;
    final child = detail.child;
    final isChildBooking = detail.isForChild;
    

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.displayName, // uses reserved name when present
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Status: ${_labelFor(detail.status)}'
            '${detail.seatNumber != null ? ' • Seat ${detail.seatNumber}' : ''}'
            '${detail.isReserved ? ' • Reservation' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Reservation block
          if (detail.isReserved) ...[
            const Text('Reservation', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            _kv('Name', detail.displayName),
            _kvAction(context,
              label: 'Phone',
              value: (detail.reservedPhone?.trim().isNotEmpty == true) ? detail.reservedPhone!.trim() : '—',
              kind: _ActionKind.phone,
            ),

            // derive requirement correctly
            () {
              final hasGuardianName = (detail.reservedGuardianName?.trim().isNotEmpty ?? false);
              // If guardian name is present on a reservation OR canBeLeftAlone is false,
              // then a guardian is required at event conclusion.
              final requireGuardian = hasGuardianName || !detail.canBeLeftAlone;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(
                    'Does the attendee require a Parent/Guardian to be present on event conclusion?',
                    requireGuardian ? 'Yes' : 'No',
                  ),
                  if (hasGuardianName)
                    _kv('Parent/Guardian', detail.reservedGuardianName!.trim()),
                ],
              );
            }(),

            const SizedBox(height: 12),
          ],

          // Related user block
          if (user != null) ...[
            Text(isChildBooking ? 'Parent/Guardian' : 'User',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            _kv('Name', user.fullName),
            () {
              final email = (user.email ?? '').trim();
              return _kvAction(
                context,
                label: isChildBooking ? 'Parent Email' : 'Email',
                value: email.isNotEmpty ? email : '—',
                kind: _ActionKind.email,
              );
            }(),
            () {
              final phone = (user.phoneNumber ?? '').trim();
              return _kvAction(
                context,
                label: isChildBooking ? 'Parent Phone' : 'Phone',
                value: phone.isNotEmpty ? phone : '—',
                kind: _ActionKind.phone,
              );
            }(),
            _kv('Strikes', '${user.strikes}${user.isSuspended ? ' (SUSPENDED)' : ''}'),
            const SizedBox(height: 12),
          ],

          // Child block when present
          if (child != null) ...[
            const Text('Child', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            _kv('Name', child.fullName),
            _kv('DOB', _fmtDob(child.dateOfBirth)),
            _kv('Age', '${child.age}'),
            _kv('Emergency Contact', child.emergencyContactName),
            () {
              final phone = (child.emergencyContactPhone).trim();
              return _kvAction(
                context,
                label: 'Emergency Phone',
                value: phone.isNotEmpty ? phone : '—',
                kind: _ActionKind.phone,
              );
            }(),
            const SizedBox(height: 12),
          ],

          // Booking block (for child bookings we also show canBeLeftAlone already)
          const Text('Booking', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          _kv('Event', detail.eventName ?? '—'),
          _kv('Event Date', _fmtDob(detail.eventDate)),
          if (isChildBooking)
            _kv('Does the attendee require a Parent/Guardian to be present on event conclusion?', detail.canBeLeftAlone ? 'Yes' : 'No'),

          const Spacer(),
        ],
      ),
    );
  }

    Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(k, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ),
            Expanded(
              child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
      );

  // New: actionable row — tap to open, long-press to copy
  Widget _kvAction(
    BuildContext context, {
    required String label,
    required String value,
    required _ActionKind kind, // email or phone
  }) {
    final isDisabled = value.trim().isEmpty || value == '—';
    final style = TextStyle(
      color: isDisabled ? Colors.white38 : const Color(0xFF4A90E2),
      fontSize: 13,
      decoration: isDisabled ? TextDecoration.none : TextDecoration.underline,
      decorationColor: const Color(0xFF4A90E2),
    );

    Future<void> _launch() async {
      if (isDisabled) return;
      final uri = switch (kind) {
        _ActionKind.email => Uri(scheme: 'mailto', path: value.trim()),
        _ActionKind.phone => Uri(scheme: 'tel', path: value.trim()),
      };
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _copy(context, value);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _launch,
              onLongPress: () => _copy(context, value),
              child: Text(value.isEmpty ? '—' : value, style: style),
            ),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text) {
    if (text.trim().isEmpty || text == '—') return;
    Clipboard.setData(ClipboardData(text: text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  String _fmtDob(DateTime? d) {
    if (d == null) return '—';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
