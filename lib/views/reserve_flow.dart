// lib/views/reserve_flow.dart

import 'dart:convert';
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

  @override
  void dispose() {
    _seatCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

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

                  _boxedField(
                    label: 'Seat Number',
                    hint: 'e.g. 12',
                    controller: _seatCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1) return 'Invalid seat number';
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
                        backgroundColor: const Color(0xFF4C85D0),
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
