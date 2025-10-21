import 'dart:convert';
import 'dart:math' as math;
import 'package:corpsapp/widgets/button.dart';
import 'package:corpsapp/widgets/input_field.dart';
import 'package:corpsapp/widgets/seat_picker.dart';
import '../models/event_summary.dart' show EventSummary;
import '../models/event_detail.dart' show EventDetail;
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/event_header.dart';
import 'package:flutter/material.dart';
import '../services/auth_http_client.dart';

class ReserveFlow extends StatefulWidget {
  final int eventId;
  final EventSummary event;
  const ReserveFlow({super.key, required this.eventId, required this.event});

  @override
  _ReserveFlowState createState() => _ReserveFlowState();
}

class _ReserveFlowState extends State<ReserveFlow> {
  final _formKey  = GlobalKey<FormState>();
  final _seatCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _guardianCtrl = TextEditingController();

  late Future<EventDetail> _detailFut;
  String? _mascotUrl;

  bool _loading = false;
  String? _error;

  // keep the selected seat in state (mirrors the text field)
  int? _selectedSeat;

  // UX toggle (inverse of API's canBeLeftAlone)
  bool _cannotBeLeftAlone = false;

  @override
  void initState() {
    super.initState();
    _detailFut = _loadEventDetail();
    _seatCtrl.addListener(_syncTypedSeat);
  }

  @override
  void dispose() {
    _seatCtrl.removeListener(_syncTypedSeat);
    _seatCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _guardianCtrl.dispose();
    super.dispose();
  }

  void _syncTypedSeat() {
    final n = int.tryParse(_seatCtrl.text.trim());
    setState(() => _selectedSeat = n);
  }

  // Allow only digits and '+'; strip spaces etc before sending
  String _cleanPhone(String s) =>
      String.fromCharCodes(
        s.trim().runes.where((c) => (c >= 0x30 && c <= 0x39) || c == 0x2B),
      );

  bool _needsGuardian() => _cannotBeLeftAlone;

  // ────────────────────────────────────────────────────────────────────────────
  // API helpers

  Future<EventDetail> _loadEventDetail() async {
    final resp = await AuthHttpClient.get(
      '/api/events/${widget.event.eventId}',
    );

    if (resp.statusCode == 200) {
      final jsonData = jsonDecode(resp.body) as Map<String, dynamic>;
      final detail = EventDetail.fromJson(jsonData);

      // Assign locationMascotImgSrc to _mascotUrl
      final mascotUrl = jsonData['locationMascotImgSrc'] as String?;
      if (mascotUrl != null &&
          mascotUrl.isNotEmpty) {
        _mascotUrl = mascotUrl;
      } else {
        _mascotUrl = null;
      }

      return detail;
    } else {
      throw Exception('Failed to load event detail: ${resp.statusCode}');
    }
  }

  Future<_SeatData> _fetchSeatData() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = await AuthHttpClient.get('/api/events/${widget.eventId}?_=$ts'); // bust caches
    final json = jsonDecode(r.body) as Map<String, dynamic>;

    final available = (json['availableSeats'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toSet() ??
        <int>{};

    final total = (json['totalSeats'] as num?)?.toInt() ??
        (available.isNotEmpty ? available.reduce(math.max) : 0);

    return _SeatData(totalSeats: total, availableSeats: available);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Seat picker dialog

  Future<void> _openSeatPicker() async {
    try {
      final data = await _fetchSeatData();

      final picked = await showModalBottomSheet<int>(
        useSafeArea: true,
        context: context,
        builder: (_) => Padding(
          padding: AppPadding.screen,
          child: SeatPickerSheet(
            futureDetail: _detailFut, 
            initialSelected: _selectedSeat, 
            eventTotalSeats: data.totalSeats, 
            isReserveFlow: true,
            onSeatPicked: (seat) {
              // Update both controller and local state
              setState(() {
                _selectedSeat = seat;
                _seatCtrl.text = seat.toString();
              });

              // Close the modal after choosing a seat
              Navigator.of(context).pop();
            },
          )
        )
      );

      if (picked != null) {
        setState(() {
          _selectedSeat = picked;
          _seatCtrl.text = picked.toString();
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load any tickets. Please try again later.')),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Reserve submit

  Future<void> _reserve() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cleanedPhone = _cleanPhone(_phoneCtrl.text);
      if (cleanedPhone.length < 7) {
        setState(() => _error = 'Please enter a valid phone number.');
        return;
      }

      final guardian = _guardianCtrl.text.trim();
      if (_needsGuardian() && guardian.isEmpty) {
        setState(() => _error = 'Parent/Guardian name is required.');
        return;
      }

      final body = jsonEncode({
        'eventId': widget.eventId,
        'seatNumber': int.parse(_seatCtrl.text.trim()),
        'attendeeName': _nameCtrl.text.trim(),
        'phoneNumber': cleanedPhone,
        // NEW: API expects canBeLeftAlone (inverse of the toggle)
        'canBeLeftAlone': !_cannotBeLeftAlone,
        'reservedBookingParentGuardianName': _cannotBeLeftAlone ? guardian : null,
      });

      // Prefer JSON explicitly
      final resp = await AuthHttpClient.postRaw(
        '/api/booking/reserve',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );

      // Handle non-2xx without relying on thrown exceptions
      final status = resp.statusCode;
      final text = resp.body.toString();

      if (status >= 200 && status < 300) {
        final data = (text.isNotEmpty)
            ? (jsonDecode(text) as Map<String, dynamic>)
            : const <String, dynamic>{};
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Reserved successfully')),
        );
        Navigator.of(context).pop(true);
        return;
      }

      // Non-2xx: try to surface server message
      String msg = 'Error $status';
      if (text.isNotEmpty) {
        try {
          final json = jsonDecode(text);
          if (json is Map && json['message'] != null) {
            msg = json['message'].toString();
          } else {
            msg = text; // plain text error
          }
        } catch (_) {
          msg = text; // not JSON
        }
      }

      setState(() => _error = msg);
    } catch (e) {
      // More robust: match "HTTP 500" and optional ": body"
      final s = e.toString();
      final m = RegExp(r'^HTTP\s+(\d{3})(?::\s*(.*))?$').firstMatch(s);

      if (m != null) {
        final code = m.group(1) ?? '500';
        final raw = m.group(2) ?? '';
        String msg = 'Error $code';

        if (raw.isNotEmpty) {
          try {
            final j = jsonDecode(raw);
            if (j is Map && j['message'] != null) {
              msg = j['message'].toString();
            } else {
              msg = raw;
            }
          } catch (_) {
            msg = raw;
          }
        }
        setState(() => _error = msg);
      } else {
        // Show the exception string so we see what's going on
        setState(() => _error = s);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // UI helpers


  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Reserve a Ticket'),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.screen,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EventHeader(event: widget.event, detailFuture: _detailFut, mascotUrl: _mascotUrl),

                  const Text(
                    'Ticket',
                    style: TextStyle( fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const Text(
                    'The ticket number does not represent a physical seat.',
                    style: TextStyle( fontSize: 14 ),
                  ),

                  const SizedBox(height: 8),

                  // Choose seat button (opens centered overlay)
                  Button(
                    label: _selectedSeat == null
                                        ? 'Choose Ticket'
                                        : 'Ticket #$_selectedSeat', 
                    subLabel: 'Change Ticket',
                    onPressed: _openSeatPicker),
                  
                  const SizedBox(height: 16),
                  Divider(color: Colors.white24, height: 1, thickness: 2),
                  const SizedBox(height: 16),

                  const Text(
                    'Attendee Details',
                    style: TextStyle( fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  
                  const SizedBox(height: 8),

                  InputField(
                    hintText: 'Attendee full name',
                    label: 'Name',
                    controller: _nameCtrl,
                  ),

                  const SizedBox(height: 12),

                  InputField(
                    hintText: 'Attendee / Guardian phone number',
                    label: 'Phone Number',
                    controller: _phoneCtrl,
                  ),

                  const SizedBox(height: 16),
                  Divider(color: Colors.white24, height: 1, thickness: 2),
                  const SizedBox(height: 16),

                  const Text(
                    'Leave Permission',
                    style: TextStyle( fontSize: 20, fontWeight: FontWeight.bold),
                  ),
              
                  // NEW: Cannot be left alone toggle
                  SwitchListTile.adaptive(
                    value: _cannotBeLeftAlone,
                    onChanged: (v) => setState(() => _cannotBeLeftAlone = v),
                    title: const Text(
                      'MUST the attendee be picked up by a guardian?',
                      style: TextStyle( fontSize: 16),
                    ),                 
                    activeColor: AppColors.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  // NEW: Parent/Guardian Name (conditional)
                  if (_cannotBeLeftAlone) ... [
                    const SizedBox(height: 8),
                    InputField(hintText: 'Full Name', label: 'Guardian Name', controller: _guardianCtrl),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.red)),                   
                  ],

                  const SizedBox(height: 24),

                  Button(label: 'Reserve', onPressed: _reserve, loading: _loading),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatData {
  final int totalSeats;
  final Set<int> availableSeats;
  _SeatData({required this.totalSeats, required this.availableSeats});
}


