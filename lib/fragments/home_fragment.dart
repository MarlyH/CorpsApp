import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/event_tile.dart';
import 'package:corpsapp/widgets/events_sort.dart';
import 'package:corpsapp/widgets/fab_create.dart';
import 'package:corpsapp/widgets/sliver_app_bar.dart';
import 'package:corpsapp/widgets/events_filter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_http_client.dart';
import '../providers/auth_provider.dart';
import '../models/event_summary.dart' as event_summary;

/// Local model for /api/events/{id}
class EventDetail {
  final String description;
  final String address;
  EventDetail.fromJson(Map<String, dynamic> json)
    : description = json['description'] as String? ?? '',
      address = json['address'] as String? ?? '';
}

String friendlySession(event_summary.SessionType type) {
  switch (type) {
    case event_summary.SessionType.Ages8to11:
      return 'Ages 8 to 11';
    case event_summary.SessionType.Ages12to15:
      return 'Ages 12 to 15';
    default:
      return 'Ages 16+';
  }
}

class HomeFragment extends StatefulWidget {
  const HomeFragment({super.key});
  @override
  HomeFragmentState createState() => HomeFragmentState();
}

class HomeFragmentState extends State<HomeFragment> {
  late Future<List<event_summary.EventSummary>> _futureSummaries;
  int dropdownOpenTime = 0;

  String? _filterLocation;
  event_summary.SessionType? _filterSessionType;

  // four sort flags
  bool _dateAsc = true; // default: closest date first
  bool _dateDesc = false;
  // bool _seatsAsc = false;
  // bool _seatsDesc = false;

  @override
  void initState() {
    super.initState();
    _futureSummaries = _loadSummaries();
  }

  Future<List<event_summary.EventSummary>> _loadSummaries() async {
    final resp = await AuthHttpClient.getNoAuth('/api/events');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(event_summary.EventSummary.fromJson)
        .toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureSummaries = _loadSummaries();
    });
    await _futureSummaries;
  }

    DateTime eventEndDateTime(event_summary.EventSummary e) {
    // Be tolerant of formats like "09:30", "9:30", "9:30 AM"
    final t = (e.endTime).trim();
    final m = RegExp(r'^(\d{1,2})\s*:\s*(\d{2})\s*(AM|PM|am|pm)?').firstMatch(t);

    int hh = 0, mm = 0;
    String? ampm;

    if (m != null) {
      hh = int.tryParse(m.group(1) ?? '0') ?? 0;
      mm = int.tryParse(m.group(2) ?? '0') ?? 0;
      ampm = m.group(3);
    }

    // Handle 12-hour suffix if present
    if (ampm != null) {
      final mer = ampm.toLowerCase();
      if (mer == 'pm' && hh < 12) hh += 12;
      if (mer == 'am' && hh == 12) hh = 0;
    }

    final d = e.startDate; // assumed local date (no TZ)
    return DateTime(d.year, d.month, d.day, hh, mm);
  }

  // void _showFilters() {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: AppColors.background,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //     ),
  //     builder:
  //         (_) => SafeArea(
  //           child: FilterSheet(
  //             initialSession: _filterSessionType,
  //             initialDateAsc: _dateAsc,
  //             initialDateDesc: _dateDesc,
  //             initialSeatsAsc: _seatsAsc,
  //             initialSeatsDesc: _seatsDesc,
  //             onApply: (session, dateAsc, dateDesc, seatsAsc, seatsDesc) {
  //               setState(() {
  //                 _filterSessionType = session;
  //                 _dateAsc = dateAsc;
  //                 _dateDesc = dateDesc;
  //                 _seatsAsc = seatsAsc;
  //                 _seatsDesc = seatsDesc;
  //               });
  //             },
  //           ),
  //         ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canManage = auth.isAdmin || auth.isEventManager;
    final isUser = auth.isUser;
    // final isGuest = !isUser || !canManage;

    final user = auth.userProfile ?? {};
    final bool isSuspended = (user['isSuspended'] as bool?) ?? false;

    // Try a few common keys for the end date; keep null-safe.
    DateTime? readDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }
    final DateTime? suspensionUntil = readDate(
      user['suspensionUntil'] ?? user['suspensionExpiresAt'] ?? user['suspensionEnd'],
    );
    
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: canManage ? CreateEventFAB() : null,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<event_summary.EventSummary>>(
            future: _futureSummaries,
            builder: (ctx, snap) {
              final loading = snap.connectionState == ConnectionState.waiting;
              final hasError = snap.hasError;
              final all = snap.data ?? [];

              // APPLY FILTERS (rely solely on status from backend)
              final now = DateTime.now();

              final events = all.where((e) {
                // keep only available events
                if (e.status != event_summary.EventStatus.Available) return false;

                // location/session filters
                if (_filterLocation != null && e.locationName != _filterLocation) return false;
                if (_filterSessionType != null && e.sessionType != _filterSessionType) return false;

                // EXCLUDE events that have finished
                if (!eventEndDateTime(e).isAfter(now)) return false;

                return true;
              }).toList()
                // sort using full start DateTime (date + time)
                ..sort((a, b) {
                  final aStart = eventEndDateTime(a);
                  final bStart = eventEndDateTime(b);

                  if (_dateAsc) {
                    final c = aStart.compareTo(bStart);
                    if (c != 0) return c;
                  } else if (_dateDesc) {
                    final c = bStart.compareTo(aStart);
                    if (c != 0) return c;
                  }

                  // if (_seatsAsc) {
                  //   return a.availableSeatsCount.compareTo(b.availableSeatsCount);
                  // } else if (_seatsDesc) {
                  //   return b.availableSeatsCount.compareTo(a.availableSeatsCount);
                  // }

                  return 0;
                }
              );

              final allLocations =
                  all.map((e) => e.locationName).toSet().toList()..sort();

              return RefreshIndicator(
                color: Colors.white,
                onRefresh: _refresh,
                child: CustomScrollView(
                  slivers: [
                    EventBrowserAppBar(
                      filterLocation: _filterLocation,
                      onLocationChanged: (v) => setState(() => _filterLocation = v),
                      allLocations: allLocations,
                      onDropdownOpen: () {
                        setState(() {
                          dropdownOpenTime = DateTime.now().millisecondsSinceEpoch;
                        });
                      },                  
                    ),

                    SliverToBoxAdapter(
                      child: Container(
                        padding: AppPadding.screen, 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            // Filter row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                EventsFilter(
                                  onChanged: (v) => setState(() => _filterSessionType = v),
                                  filterSessionType: _filterSessionType,
                                  friendlySession: friendlySession,
                                ),

                                EventsSort(
                                  dateAsc: _dateAsc,
                                  dateDesc: _dateDesc,
                                  onChanged: (session, dateAsc, dateDesc) {
                                    setState(() {
                                      _filterSessionType = session;
                                      _dateAsc = dateAsc;
                                      _dateDesc = dateDesc;
                                    });
                                  },
                                ),
                              ],
                            ),

                            // Loading / Error / Empty States
                            if (loading)
                              const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              )
                            else if (hasError)
                              const Center(
                                child: Text(
                                  'Error loading events',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                            else if (events.isEmpty)
                              const Center(
                                child: Text(
                                  'No sessions found',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            else
                              // Events list
                              Column(
                                children: events
                                    .map(
                                      (e) => EventTile(
                                        summary: e,
                                        isUser: isUser,
                                        isSuspended: isSuspended,
                                        suspensionUntil: suspensionUntil,
                                        canManage: canManage,
                                        loadDetail: (id) => AuthHttpClient.getNoAuth('/api/events/$id')
                                            .then((r) => EventDetail.fromJson(jsonDecode(r.body))),
                                        onAction: _refresh,
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        )      
      );
  }
}