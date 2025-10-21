import 'dart:convert';
import 'dart:math' as math;
import '../models/event_summary.dart' show EventSummary;
import '../models/event_detail.dart' show EventDetail, friendlySession;
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/event_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // brand color used for selected state
  static const _brandBlue = Color(0xFF4C85D0);

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

      final picked = await showDialog<int>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _SeatPickerDialog(
          totalSeats: data.totalSeats,
          availableSeats: data.availableSeats,
          initialSelected: _selectedSeat,
          brandBlue: _brandBlue,
        ),
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
      final status = resp.statusCode ?? 0;
      final text = resp.body?.toString() ?? '';

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

  Widget _boxedField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters, // optional
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

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
                  EventHeader(event: widget.event, detailFuture: _detailFut, mascotUrl: _mascotUrl,),

                  Text('Event ID: ${widget.eventId}',
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 16),

                  // Choose seat button (opens centered overlay)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openSeatPicker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.event_seat, color: Colors.white),
                      label: Text(
                        _selectedSeat == null
                            ? 'Choose Ticket'
                            : 'Change Ticket (Ticket #$_selectedSeat)',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Seat number (editable or readOnly; keep editable here)
                  _boxedField(
                    label: 'Ticket Number',
                    hint: 'Tap “Choose Ticket”',
                    controller: _seatCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null) return 'Please pick a Ticket';
                      if (n <= 0) return 'Ticket must be >= 1';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _boxedField(
                    label: 'Attendee Name',
                    hint: 'Child full name',
                    controller: _nameCtrl,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Phone number
                  _boxedField(
                    label: 'Phone Number',
                    hint: '+64 21 123 4567',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                    ],
                    validator: (v) {
                      final cleaned = _cleanPhone(v ?? '');
                      if (cleaned.isEmpty) return 'Required';
                      if (cleaned.length < 7) return 'Enter a valid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // NEW: Cannot be left alone toggle
                  SwitchListTile.adaptive(
                    value: _cannotBeLeftAlone,
                    onChanged: (v) => setState(() => _cannotBeLeftAlone = v),
                    title: const Text(
                      'Does the attendee require a Parent/Guardian to be present on event conclusion?',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'If enabled, a Parent/Guardians full name is required they may be asked for ID on event day.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    activeColor: _brandBlue,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),

                  // NEW: Parent/Guardian Name (conditional)
                  if (_cannotBeLeftAlone)
                    _boxedField(
                      label: 'Parent/Guardian Name',
                      hint: 'Full name',
                      controller: _guardianCtrl,
                      validator: (v) {
                        if (_needsGuardian() && (v == null || v.trim().isEmpty)) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  if (_cannotBeLeftAlone) const SizedBox(height: 16),

                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _reserve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('RESERVE',
                              style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Centered overlay seat picker (dialog) + tiny helpers

class _SeatData {
  final int totalSeats;
  final Set<int> availableSeats;
  _SeatData({required this.totalSeats, required this.availableSeats});
}

class _SeatPickerDialog extends StatefulWidget {
  final int totalSeats;
  final Set<int> availableSeats;
  final int? initialSelected;
  final Color brandBlue;

  const _SeatPickerDialog({
    required this.totalSeats,
    required this.availableSeats,
    required this.initialSelected,
    required this.brandBlue,
  });

  @override
  State<_SeatPickerDialog> createState() => _SeatPickerDialogState();
}

class _SeatPickerDialogState extends State<_SeatPickerDialog> {
  int? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialSelected;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalSeats;
    final available = widget.availableSeats;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 6),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: title + cancel
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select a Ticket',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(color: Colors.white12, height: 1),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${available.length} of $total Tickets available'
                  '${_picked != null ? ' • selected: #$_picked' : ''}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),

              // Grid
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: total,
                  itemBuilder: (_, i) {
                    final seat = i + 1;
                    final isAvailable = available.contains(seat);
                    final selected = _picked == seat;

                    return _SeatTile(
                      seat: seat,
                      available: isAvailable,
                      selected: selected,
                      brandBlue: widget.brandBlue,
                      onTap: isAvailable ? () => setState(() => _picked = seat) : null,
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: const [
                  _LegendSwatch(color: Colors.white, border: Colors.white24),
                  SizedBox(width: 6),
                  Text('Available', style: TextStyle(color: Colors.white70)),
                  SizedBox(width: 16),
                  _LegendSwatch(color: Colors.white10, border: Colors.white24),
                  SizedBox(width: 6),
                  Text('Taken', style: TextStyle(color: Colors.white70)),
                  SizedBox(width: 16),
                  _LegendSwatch(color: Color(0xFF4C85D0), border: Colors.transparent),
                  SizedBox(width: 6),
                  Text('Selected', style: TextStyle(color: Colors.white70)),
                ],
              ),

              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF9E9E9E),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.brandBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _picked == null ? 'USE SELECTED' : 'USE TICKET #$_picked',
                        style: const TextStyle(color: Colors.white),
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
}

class _SeatTile extends StatelessWidget {
  final int seat;
  final bool available;
  final bool selected;
  final Color brandBlue;
  final VoidCallback? onTap;

  const _SeatTile({
    required this.seat,
    required this.available,
    required this.selected,
    required this.brandBlue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = !available
        ? Colors.white10
        : (selected ? brandBlue : Colors.white);
    final fg = !available
        ? Colors.white38
        : (selected ? Colors.white : Colors.black87);
    final border = selected ? brandBlue : Colors.white24;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: selected ? 2 : 1),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!available)
                const Icon(Icons.event_seat, size: 14, color: Colors.white38),
              if (!available) const SizedBox(width: 6),
              Text(
                '$seat',
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  final Color border;
  const _LegendSwatch({required this.color, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 1),
      ),
    );
  }
}
