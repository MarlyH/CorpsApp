import 'dart:convert';
import 'package:corpsapp/models/medical_condition.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/EventExpandableCard/event_summary.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/medical_tile.dart';
import 'package:flutter/cupertino.dart';
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
enum _ActionKind { none, email, phone }

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
        useSafeArea: true,
        backgroundColor: AppColors.background,
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
        content: Text(msg, style: const TextStyle(color: AppColors.normalText)),
        backgroundColor: error ? AppColors.errorColor : Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'My Event'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              color: Colors.white,
              onRefresh: _loadAttendees,
              child: ListView(
                padding: AppPadding.screen,
                children: [
                  // header
                  EventSummaryCard(summary: e),
                  
                  const SizedBox(height: 24),

                  const Text('Attendees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 4),

                  if (_attendees.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('No attendees yet', style: TextStyle(color: Colors.white54)))
                    )
                  else
                    CupertinoListSection.insetGrouped(                     
                      hasLeading: false,
                      margin: EdgeInsets.all(0),
                      backgroundColor: Colors.transparent,
                      children: _attendees.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final at = entry.value;
                        return ListTile(
                          minVerticalPadding: 20,
                          onTap: () => _openAttendeeDetail(at),
                          title: Text(
                            '${idx + 1}. ${at.name}', 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                          trailing: DropdownButton<BookingStatusX>(
                            value: at.status,
                            underline: const SizedBox.shrink(),
                            dropdownColor: Colors.grey[900],
                            iconEnabledColor: Colors.white70,
                            items: BookingStatusX.values.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(
                                  _labelFor(s), 
                                  style: const TextStyle(color: Colors.white, fontSize: 14 )
                                ),
                              );
                            }).toList(),
                            onChanged: (s) {
                              if (s != null && s != at.status) {
                                _updateStatus(at, s);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    )                                           
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

  // NEW:
  final bool hasMedicalConditions;
  final List<MedicalCondition> medicalConditions;

  _AdminUserMini({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.strikes,
    required this.dateOfLastStrike,
    required this.isSuspended,
    required this.hasMedicalConditions,
    required this.medicalConditions,
  });

  factory _AdminUserMini.fromJson(Map<String, dynamic> j) {
    final medsRaw = (j['medicalConditions'] ?? j['MedicalConditions']) as List<dynamic>? ?? const [];
    final meds = medsRaw.whereType<Map<String, dynamic>>().map(MedicalCondition.fromJson).toList();

    return _AdminUserMini(
      id: (j['id'] ?? '').toString(),
      email: j['email']?.toString(),
      phoneNumber: j['phoneNumber']?.toString(),
      firstName: (j['firstName'] ?? '').toString(),
      lastName: (j['lastName'] ?? '').toString(),
      strikes: (j['attendanceStrikeCount'] as int?) ?? 0,
      dateOfLastStrike: j['dateOfLastStrike']?.toString(),
      isSuspended: j['isSuspended'] == true,
      hasMedicalConditions: (j['hasMedicalConditions'] ?? j['HasMedicalConditions']) == true || meds.isNotEmpty,
      medicalConditions: meds,
    );
  }

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

  // NEW:
  final bool hasMedicalConditions;
  final List<MedicalCondition> medicalConditions;

  _ChildDto({
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.age,
    required this.hasMedicalConditions,
    required this.medicalConditions,
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

    final medsRaw = (j['medicalConditions'] ?? j['MedicalConditions']) as List<dynamic>? ?? const [];
    final meds = medsRaw.whereType<Map<String, dynamic>>().map(MedicalCondition.fromJson).toList();

    return _ChildDto(
      childId: (j['childId'] ?? j['ChildId'] ?? 0) as int,
      firstName: (j['firstName'] ?? j['FirstName'] ?? '').toString(),
      lastName: (j['lastName'] ?? j['LastName'] ?? '').toString(),
      dateOfBirth: parseDob(j['dateOfBirth'] ?? j['DateOfBirth']),
      emergencyContactName: (j['emergencyContactName'] ?? j['EmergencyContactName'] ?? '').toString(),
      emergencyContactPhone: (j['emergencyContactPhone'] ?? j['EmergencyContactPhone'] ?? '').toString(),
      age: (j['age'] ?? j['Age'] ?? 0) as int,
      hasMedicalConditions: (j['hasMedicalConditions'] ?? j['HasMedicalConditions']) == true || meds.isNotEmpty,
      medicalConditions: meds,
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

Widget _medicalBlock({
  required String title,
  required bool hasAny,
  required List<MedicalCondition> items,
}) {
  final hasItems = items.isNotEmpty;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title, 
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
      ),

      const SizedBox(height: 8),

      if (!hasAny || !hasItems)
        const Text('None reported',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16))
      else
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((m) => MedicalTile(m)).toList(),
        ),
      const SizedBox(height: 16),
    ],
  );
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
    
    return SafeArea(
      child: Padding(
        padding: AppPadding.screen,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [   
              const SizedBox(height: 16),           
              // Header
              Center(
                child: Column(
                  children: [
                    Text(
                      detail.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labelFor(detail.status),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Reservation block
              if (detail.isReserved) ...[
                const Text('Reservation', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                infoRow(context, label: 'Name', value: detail.displayName),
                () {
                  final hasGuardianName = (detail.reservedGuardianName?.trim().isNotEmpty ?? false);
                  final requireGuardian = hasGuardianName || !detail.canBeLeftAlone;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      infoRow(context, label: 'MUST the attendee be picked up by a guardian?', value: requireGuardian ? 'Yes' : 'No'),
                      if (hasGuardianName)
                        infoRow(context, label: 'Guardian Name', value: detail.reservedGuardianName!.trim())
                    ],
                  );
                }(),
                infoRow(
                  context, 
                  label: 'Guardian Phone', 
                  value: (detail.reservedPhone?.trim().isNotEmpty == true) ? detail.reservedPhone!.trim() : '',
                  kind: _ActionKind.phone
                ), 
                const SizedBox(height: 16),
              ],

              // Child block
              if (child != null) ...[
                const Text('Child', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                infoRow(context, label: 'Name', value: child.firstName),
                infoRow(context, label: 'Date of Birth', value: _fmtDob(child.dateOfBirth)),
                infoRow(context, label: 'Age', value: '${child.age}'),
                infoRow(context, label: 'Emergency Contact', value: child.emergencyContactName),
                infoRow(context, label: 'Emergency Phone', value: child.emergencyContactPhone, kind: _ActionKind.phone),
                infoRow(context, label: 'MUST the attendee be picked up by a guardian?', value: detail.canBeLeftAlone ? 'Yes' : 'No'),
                const SizedBox(height: 16),
                _medicalBlock(
                  title: 'Medical / Allergy Info',
                  hasAny: child.hasMedicalConditions,
                  items: child.medicalConditions,
                ),
              ],

              // User/Parent block
              if (user != null) ...[
                Text(isChildBooking ? 'Parent/Guardian' : 'User',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                infoRow(context, label: 'Name', value: user.fullName),
                infoRow(context, label: isChildBooking ? 'Parent Email' : 'Email', value: user.email ?? '', kind: _ActionKind.email),
                infoRow(context, label: isChildBooking ? 'Parent Phone' : 'Phone', value: user.phoneNumber ?? '', kind: _ActionKind.phone),
                const SizedBox(height: 16),
                if (!detail.isForChild && !detail.isReserved)
                  _medicalBlock(
                    title: 'Medical / Allergy Info (User)',
                    hasAny: user.hasMedicalConditions,
                    items: user.medicalConditions,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


Widget infoRow(
  BuildContext context, {
    required String label,
    required String value,
    _ActionKind kind = _ActionKind.none,
    double labelWidth = 150,
  }
) {
  final isDisabled = value.trim().isEmpty || value == '';
  final isAction = kind != _ActionKind.none;

  final textStyle = TextStyle(
    fontSize: 14,
    color: 
    Colors.white,
    fontWeight: FontWeight.w500,
    decoration: isAction && !isDisabled ? TextDecoration.underline : TextDecoration.none,
    decorationColor: Colors.white,
  );

  Future<void> handleTap() async {
    if (!isAction || isDisabled) return;
    final uri = switch (kind) {
      _ActionKind.email => Uri(scheme: 'mailto', path: value.trim()),
      _ActionKind.phone => Uri(scheme: 'tel', path: value.trim()),
      _ => null,
    };
    if (uri == null) return;

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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: handleTap,
            onLongPress: () => _copy(context, value),
            behavior: HitTestBehavior.opaque,
            child: Text(
              value.isEmpty ? '' : value,
              style: textStyle,
            ),
          ),
        ),
      ],
    ),
  );
}

void _copy(BuildContext context, String text) {
  if (text.trim().isEmpty || text == '') return;
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

