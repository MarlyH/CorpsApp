import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../views/children/create_child.dart'; // if you need that

// --- Models & Parsing ---

enum SessionType { Kids, Teens, Adults }

SessionType _parseSessionType(dynamic raw) {
  if (raw is int) {
    // clamp to valid index
    final idx = raw.clamp(0, SessionType.values.length - 1);
    return SessionType.values[idx];
  } else if (raw is String) {
    return SessionType.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == raw.toLowerCase(),
      orElse: () => SessionType.Kids,
    );
  }
  // fallback if neither int nor String
  return SessionType.Kids;
}

class EventSummary {
  final int id;
  final SessionType sessionType;
  final DateTime startDate;
  final String startTime;
  final String endTime;
  final String locationName;
  final int availableSeats;

  EventSummary.fromJson(Map<String, dynamic> json)
      : id             = json['eventId'] as int,
        sessionType    = _parseSessionType(json['sessionType']),
        startDate      = DateTime.parse(json['startDate'] as String),
        startTime      = json['startTime'] as String,
        endTime        = json['endTime'] as String,
        locationName   = json['locationName'] as String,
        availableSeats = json['availbleSeatsCount'] as int;
}

class EventDetail {
  final String description, address, locationName;
  final int totalSeats;
  final List<int> availableSeats;

  EventDetail.fromJson(Map<String, dynamic> json)
      : description    = json['description'] ?? '',
        address        = json['address'] ?? '',
        totalSeats     = json['totalSeatsCount'] ?? 0,
        locationName   = json['locationName'] ?? '',
        availableSeats = (json['availableSeats'] as List<dynamic>?)
                            ?.cast<int>() ?? [];
}

// --- HomeFragment ---

class HomeFragment extends StatefulWidget {
  const HomeFragment({Key? key}) : super(key: key);
  @override
  State<HomeFragment> createState() => _HomeFragmentState();
}

class _HomeFragmentState extends State<HomeFragment> {
  late Future<List<EventSummary>> _futureSummaries;
  String? _filterLocation;
  bool _dateAsc = true, _seatsAsc = true;

  @override
  void initState() {
    super.initState();
    _futureSummaries = _loadSummaries();
  }

  Future<List<EventSummary>> _loadSummaries() async {
    final resp = await AuthHttpClient.get('/api/events');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>()
               .map(EventSummary.fromJson)
               .toList();
  }

  Future<EventDetail> _loadDetail(int id) async {
    final resp = await AuthHttpClient.get('/api/events/$id');
    return EventDetail.fromJson(jsonDecode(resp.body));
  }

  void _refresh() {
    setState(() => _futureSummaries = _loadSummaries());
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final isUser    = auth.isUser || auth.isStaff;          
    final canManage = auth.isAdmin || auth.isEventManager;  

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              Expanded(
                child: Text('INVERCARGILL',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ),
              Icon(Icons.keyboard_arrow_down, color: Colors.white),
            ],
          ),
        ),

        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.white70),
              const SizedBox(width: 8),
              const Text('All Sessions',
                  style: TextStyle(color: Colors.white)),
              const Spacer(),
              Icon(Icons.keyboard_arrow_down, color: Colors.white70),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Event list
        Expanded(
          child: FutureBuilder<List<EventSummary>>(
            future: _futureSummaries,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text('Error: ${snap.error}',
                      style: const TextStyle(color: Colors.white)),
                );
              }
              final all = snap.data!;

              // unique locations
              final locs = all.map((e) => e.locationName).toSet().toList()
                ..sort();

              var filtered = all.where((e) {
                return _filterLocation == null ||
                       e.locationName == _filterLocation;
              }).toList();

              // sort
              filtered.sort((a,b){
                final dcmp = _dateAsc
                    ? a.startDate.compareTo(b.startDate)
                    : b.startDate.compareTo(a.startDate);
                if (a.availableSeats != b.availableSeats) {
                  return _seatsAsc
                      ? a.availableSeats.compareTo(b.availableSeats)
                      : b.availableSeats.compareTo(a.availableSeats);
                }
                return dcmp;
              });

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('No events',
                      style: TextStyle(color: Colors.white70)),
                );
              }

              return RefreshIndicator(
                color: Colors.white,
                onRefresh: () async {
                  _refresh();
                  await _futureSummaries;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => EventTile(
                    summary:    filtered[i],
                    isUser:     isUser,
                    canManage:  canManage,
                    loadDetail: _loadDetail,
                    onAction:   _refresh,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- EventTile & DetailContent (same as previous) ---

class EventTile extends StatefulWidget {
  final EventSummary                   summary;
  final bool                           isUser;
  final bool                           canManage;
  final Future<EventDetail> Function(int)
                                       loadDetail;
  final VoidCallback                   onAction;

  const EventTile({
    Key? key,
    required this.summary,
    required this.isUser,
    required this.canManage,
    required this.loadDetail,
    required this.onAction,
  }) : super(key: key);

  @override
  State<EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<EventTile> {
  bool _expanded = false;
  late Future<EventDetail> _futureDetail;

  @override
  void initState() {
    super.initState();
    _futureDetail = widget.loadDetail(widget.summary.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;

    final dateStr =
        '${['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][s.startDate.weekday-1]} '
        '${s.startDate.day.toString().padLeft(2,'0')} '
        '${_monthName(s.startDate.month)} '
        '${s.startDate.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        // Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // location + session type
              Row(
                children: [
                  Expanded(
                    child: Text(s.locationName,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                  ),
                  Text(s.sessionType.toString().split('.').last,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(dateStr,
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Starts ${s.startTime}',
                      style: const TextStyle(color: Colors.black54)),
                  Text('Ends   ${s.endTime}',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),

              if (_expanded) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.event_seat, size: 16),
                    const SizedBox(width: 4),
                    Text('${s.availableSeats} Seats Available'),
                    const Spacer(),
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 4),
                    Text(s.locationName),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<EventDetail>(
                  future: _futureDetail,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    if (snap.hasError) {
                      return const Text('Error loading details',
                          style: TextStyle(color: Colors.redAccent));
                    }
                    return Text(snap.data!.description,
                        style: const TextStyle(color: Colors.black87));
                  },
                ),
              ],
            ],
          ),
        ),

        // More/Less button
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.only(top: -20),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white),
            ),
            child: Text(_expanded ? 'Less' : 'More',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),

        // Actions
        if (_expanded) ...[
          const SizedBox(height: 8),
          if (widget.isUser)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size.fromHeight(40),
              ),
              onPressed: () {/* booking */},
              child: const Text('BOOK NOW'),
            )
          else if (widget.canManage)
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    minimumSize: const Size.fromHeight(40),
                  ),
                  onPressed: () {/* cancel */},
                  child: const Text('CANCEL EVENT',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(40),
                  ),
                  onPressed: () {/* reserve */},
                  child: const Text('RESERVE SEAT'),
                ),
              ),
            ]),
        ],
      ]),
    );
  }

  String _monthName(int m) {
    const names = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return names[m - 1];
  }
}
