// lib/views/reserve_flow.dart

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/auth_http_client.dart';

class ReserveFlow extends StatefulWidget {
  final int eventId;
  const ReserveFlow({super.key, required this.eventId});

  @override
  _ReserveFlowState createState() => _ReserveFlowState();
}

class _ReserveFlowState extends State<ReserveFlow> {
  final _formKey  = GlobalKey<FormState>();
  final _seatCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  // NEW: keep the selected seat in state (mirrors the text field)
  int? _selectedSeat;

  // brand color used for selected state
  static const _brandBlue = Color(0xFF4C85D0);

  @override
  void initState() {
    super.initState();
    _seatCtrl.addListener(_syncTypedSeat);
  }

  @override
  void dispose() {
    _seatCtrl.removeListener(_syncTypedSeat);
    _seatCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _syncTypedSeat() {
    final n = int.tryParse(_seatCtrl.text.trim());
    setState(() => _selectedSeat = n);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // API helpers

  Future<_SeatData> _fetchSeatData() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = await AuthHttpClient.get('/api/events/${widget.eventId}?_=$ts'); // <— bust caches
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load seats')),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Original reserve submit logic (unchanged)

  Future<void> _reserve() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await AuthHttpClient.post(
        '/api/booking/reserve',
        body: {
          'eventId': widget.eventId,
          'seatNumber': int.parse(_seatCtrl.text.trim()),
          'attendeeName': _nameCtrl.text.trim(),
        },
      );

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Reserved successfully')),
      );
      Navigator.of(context).pop(true);
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.startsWith('HTTP 401')) {
        setState(() => _error = 'Unauthorized. Please sign in.');
      } else {
        final m = RegExp(r'HTTP (\d+): (.*)').firstMatch(msg);
        if (m != null) {
          final code = m.group(1);
          final body = m.group(2);
          try {
            final json = jsonDecode(body!);
            setState(() => _error = json['message']?.toString() ?? 'Error $code');
          } catch (_) {
            setState(() => _error = 'Error $code');
          }
        } else {
          setState(() => _error = 'Unexpected error');
        }
      }
    } finally {
      setState(() {
        _loading = false;
      });
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Reserve Seat'),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                            ? 'Choose Seat'
                            : 'Change Seat (Seat #$_selectedSeat)',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Seat number (you can keep this editable or make it readOnly)
                  _boxedField(
                    label: 'Seat Number',
                    hint: 'Tap “Choose Seat”',
                    controller: _seatCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null) return 'Please pick a seat';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _boxedField(
                    label: 'Attendee Name',
                    hint: 'Your name',
                    controller: _nameCtrl,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

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
                      'Select a Seat',
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
                  '${available.length} of $total seats available'
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
                        _picked == null ? 'USE SELECTED' : 'USE SEAT #$_picked',
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
