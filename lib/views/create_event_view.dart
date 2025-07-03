import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_http_client.dart';

enum SessionType { Kids, Adults, Seniors }
const _sessionTypeValues = {
  SessionType.Kids: 0,
  SessionType.Adults: 1,
  SessionType.Seniors: 2,
};

class CreateEventView extends StatefulWidget {
  const CreateEventView({Key? key}) : super(key: key);

  @override
  _CreateEventViewState createState() => _CreateEventViewState();
}

class _CreateEventViewState extends State<CreateEventView> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtl = TextEditingController();
  final _seatingCtl  = TextEditingController();
  final _seatsCtl    = TextEditingController();
  final _descCtl     = TextEditingController();
  final _addressCtl  = TextEditingController();

  SessionType? _chosenSession;
  DateTime?    _availableDate;
  DateTime?    _startDate;
  TimeOfDay?   _startTime;
  TimeOfDay?   _endTime;

  bool _isLoading = false;

  @override
  void dispose() {
    for (final ctl in [
      _locationCtl,
      _seatingCtl,
      _seatsCtl,
      _descCtl,
      _addressCtl,
    ]) {
      ctl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(BuildContext ctx, bool isAvailable) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => isAvailable ? _availableDate = picked : _startDate = picked);
    }
  }

  Future<void> _pickTime(BuildContext ctx, bool isStart) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: ctx,
      initialTime: now,
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:00';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _chosenSession  == null ||
        _availableDate == null ||
        _startDate     == null ||
        _startTime     == null ||
        _endTime       == null) return;

    setState(() => _isLoading = true);

    final body = {
      'locationId'      : int.parse(_locationCtl.text.trim()),
      'sessionType'     : _sessionTypeValues[_chosenSession]!,
      'availableDate'   : _availableDate!.toIso8601String().substring(0,10),
      'startDate'       : _startDate!.toIso8601String().substring(0,10),
      'startTime'       : _formatTime(_startTime!),
      'endTime'         : _formatTime(_endTime!),
      'seatingMapImgSrc': _seatingCtl.text.trim(),
      'totalSeats'      : int.parse(_seatsCtl.text.trim()),
      'description'     : _descCtl.text.trim(),
      'address'         : _addressCtl.text.trim(),
    };

    try {
      final resp = await AuthHttpClient.post('/api/events', body: body);
      final data = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
      final msg = data?['message'] ??
          (resp.statusCode == 200 ? 'Event created!' : 'Failed (${resp.statusCode})');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.black)),
          backgroundColor: resp.statusCode == 200 ? Colors.white : Colors.redAccent,
        ),
      );

      if (resp.statusCode == 200) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildField({
    required TextEditingController ctl,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event'), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(children: [
              _buildField(
                ctl: _locationCtl,
                label: 'Location ID',
                keyboardType: TextInputType.number,
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),

              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Session Type',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SessionType>(
                    value: _chosenSession,
                    isExpanded: true,
                    dropdownColor: Colors.black,
                    hint: const Text('Select session', style: TextStyle(color: Colors.white54)),
                    items: SessionType.values.map((st) {
                      final label = st.toString().split('.').last;
                      return DropdownMenuItem(
                        value: st,
                        child: Text(label, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _chosenSession = v),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(context, true),
                    child: Text(
                      _availableDate == null
                          ? 'Pick Available Date'
                          : _availableDate!.toIso8601String().substring(0,10),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(context, false),
                    child: Text(
                      _startDate == null
                          ? 'Pick Start Date'
                          : _startDate!.toIso8601String().substring(0,10),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(context, true),
                    child: Text(
                      _startTime == null
                          ? 'Pick Start Time'
                          : _startTime!.format(context),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(context, false),
                    child: Text(
                      _endTime == null
                          ? 'Pick End Time'
                          : _endTime!.format(context),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 12),
              _buildField(
                ctl: _seatingCtl,
                label: 'Seating Map URL',
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                ctl: _seatsCtl,
                label: 'Total Seats',
                keyboardType: TextInputType.number,
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                ctl: _descCtl,
                label: 'Description',
                maxLines: 4,
                validator: (_) => null,
              ),
              const SizedBox(height: 12),
              _buildField(
                ctl: _addressCtl,
                label: 'Address',
                validator: (_) => null,
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Event', style: TextStyle(fontSize: 16)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
