// lib/views/manage_events_view.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/event_summary.dart';
import '../services/auth_http_client.dart';
import 'manage_event_detail_view.dart';

class ManageEventsView extends StatefulWidget {
  const ManageEventsView({Key? key}) : super(key: key);

  @override
  _ManageEventsViewState createState() => _ManageEventsViewState();
}

class _ManageEventsViewState extends State<ManageEventsView> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<EventSummary> _allEvents = [];
  List<EventSummary> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _searchCtrl.addListener(_filter);
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final resp = await AuthHttpClient.get('/api/events');
      final list = jsonDecode(resp.body) as List<dynamic>;
      _allEvents = list
          .cast<Map<String, dynamic>>()
          .map(EventSummary.fromJson)
          .toList();
      _filtered = List.from(_allEvents);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load events: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_allEvents);
      } else {
        _filtered = _allEvents.where((e) =>
          e.locationName.toLowerCase().contains(q)
          || friendlySession(e.sessionType).toLowerCase().contains(q)
          || e.startDate.toLocal().toString().toLowerCase().contains(q)
        ).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('My Events', style: TextStyle(letterSpacing: 1.2, fontFamily: 'WinnerSans', fontSize: 20, fontWeight: FontWeight.w600,)),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search Events',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white12,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : RefreshIndicator(
                  color: Colors.white,
                  onRefresh: _loadEvents,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final e = _filtered[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManageEventDetailView(event: e),
                            ),
                          ),
                          child: Container(
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
                                    Expanded(
                                      child: Text(
                                        e.locationName,
                                        style: const TextStyle(
                                          fontSize: 12, color: Colors.black54),
                                      ),
                                    ),
                                    Text(
                                      friendlySession(e.sessionType),
                                      style: const TextStyle(
                                        fontSize: 12, color: Colors.black54),
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
                        ),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// Helpers re‑used:
String _weekdayFull(DateTime d) {
  const week = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  return week[d.weekday - 1];
}
String _formatDate(DateTime d) {
  final m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day.toString().padLeft(2,'0')} ${m[d.month-1]} ${d.year}';
}
