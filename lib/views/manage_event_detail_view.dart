// lib/views/manage_event_detail_view.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/event_summary.dart';
import '../services/auth_http_client.dart';

class ManageEventDetailView extends StatefulWidget {
  final EventSummary event;
  const ManageEventDetailView({Key? key, required this.event}) : super(key: key);

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
      final resp = await AuthHttpClient.get('/api/events/${widget.event.eventId}/attendees');
      final list = jsonDecode(resp.body) as List<dynamic>;
      _attendees = list.map((m) {
        return _Attendee(
          id: m['attendeeId'] as int,
          name: m['name'] as String,
          status: (m['status'] as String).toLowerCase() == 'in',
        );
      }).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading attendees: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(int idx, bool isIn) async {
    final at = _attendees[idx];
    setState(() => _loading = true);
    try {
      await AuthHttpClient.post(
        '/api/events/${widget.event.eventId}/attendance',
        body: {'attendeeId': at.id, 'status': isIn ? 'in' : 'out'},
      );
      at.status = isIn;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('My Events', style: TextStyle(letterSpacing: 1.2)),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header card (same style)
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
                        Text(
                          e.locationName,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const Spacer(),
                        Text(
                          friendlySession(e.sessionType),
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_weekdayFull(e.startDate)} ${_formatDate(e.startDate)}',
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
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

              ..._attendees.asMap().entries.map((entry) {
                final idx = entry.key;
                final at = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${idx + 1}. ${at.name}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Radio<bool>(
                              value: true,
                              groupValue: at.status,
                              activeColor: Colors.blueAccent,
                              onChanged: (v) => _updateStatus(idx, v!),
                            ),
                            const Text('In', style: TextStyle(color: Colors.white70)),
                            const SizedBox(width: 16),
                            Radio<bool>(
                              value: false,
                              groupValue: at.status,
                              activeColor: Colors.blueAccent,
                              onChanged: (v) => _updateStatus(idx, v!),
                            ),
                            const Text('Out', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
    );
  }
}

class _Attendee {
  final int id;
  final String name;
  bool status;
  _Attendee({required this.id, required this.name, required this.status});
}

// helpers
String _weekdayFull(DateTime d) {
  const week = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  return week[d.weekday - 1];
}
String _formatDate(DateTime d) {
  final m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day.toString().padLeft(2,'0')} ${m[d.month-1]} ${d.year}';
}
