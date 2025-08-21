import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/event_summary.dart';
import '../services/auth_http_client.dart';
import 'manage_event_detail_view.dart' hide friendlySession;

class ManageEventsView extends StatefulWidget {
  const ManageEventsView({super.key});

  @override
  _ManageEventsViewState createState() => _ManageEventsViewState();
}

class _ManageEventsViewState extends State<ManageEventsView> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<EventSummary> _allEvents = [];
  List<EventSummary> _filtered = [];
  bool _loading = true;

  // Lookup tables for constructing search queries
  static const _weekFull = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
  static const _weekAbbr = ['mon','tue','wed','thu','fri','sat','sun'];
  static const _monFull = ['january','february','march','april','may','june','july','august','september','october','november','december'];
  static const _monAbbr = ['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'];

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
        SnackBar(
          content: Text('Failed to load events: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // Nicely formatted day + date for the row
  String niceDayDate(DateTime d) {
    const week = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mon  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final local = d.toLocal();
    return '${week[local.weekday - 1]} • ${local.day.toString().padLeft(2, '0')} ${mon[local.month - 1]} ${local.year}';
  }

  // search capabilities
  // - location name
  // - session label (e.g., "Ages 12 to 15")
  // - weekday full/abbr
  // - month full/abbr + month number
  // - day-of-month + year
  // - ISO date y-m-d
  // - start/end times as strings
  String _searchBlob(EventSummary e) {
    final d = e.startDate.toLocal();
    final weekdayFull = _weekFull[d.weekday - 1];
    final weekdayAbbr = _weekAbbr[d.weekday - 1];
    final monthFull = _monFull[d.month - 1];
    final monthAbbr = _monAbbr[d.month - 1];
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final iso = '$yyyy-$mm-$dd';

    return [
      e.locationName,
      friendlySession(e.sessionType),
      weekdayFull, weekdayAbbr,
      monthFull, monthAbbr, mm,
      dd, yyyy, iso,
      e.startTime, e.endTime,
    ].join(' ').toLowerCase();
  }

  void _filter() {
    final raw = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (raw.isEmpty) {
        _filtered = List.from(_allEvents);
        return;
      }
      final tokens = raw.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

      _filtered = _allEvents.where((e) {
        final blob = _searchBlob(e);
        // Require ALL tokens to match
        for (final t in tokens) {
          if (!blob.contains(t)) return false;
        }
        return true;
      }).toList();
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
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search (e.g. “Riverton Mon 2025 Jan 12 15 Ages 12 to 15”)',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: (_searchCtrl.text.isEmpty)
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filter();
                        },
                      ),
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
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        friendlySession(e.sessionType),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Day + date line
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
