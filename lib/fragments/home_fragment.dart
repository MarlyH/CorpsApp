import 'dart:convert';
import 'package:corpsapp/models/session_type_helper.dart';
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

class EventDetail {
  final String description;
  final String address;
  EventDetail.fromJson(Map<String, dynamic> json)
      : description = json['description'] as String? ?? '',
        address = json['address'] as String? ?? '';
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
  SessionType _filterSessionType = SessionType.all;

  bool _dateAsc = true;
  bool _dateDesc = false;

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
    final t = (e.endTime).trim();
    final m = RegExp(r'^(\d{1,2})\s*:\s*(\d{2})\s*(AM|PM|am|pm)?').firstMatch(t);

    int hh = 0, mm = 0;
    String? ampm;
    if (m != null) {
      hh = int.tryParse(m.group(1) ?? '0') ?? 0;
      mm = int.tryParse(m.group(2) ?? '0') ?? 0;
      ampm = m.group(3);
    }
    if (ampm != null) {
      final mer = ampm.toLowerCase();
      if (mer == 'pm' && hh < 12) hh += 12;
      if (mer == 'am' && hh == 12) hh = 0;
    }

    final d = e.startDate;
    return DateTime(d.year, d.month, d.day, hh, mm);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canManage = auth.isAdmin || auth.isEventManager;
    final isUser = auth.isUser;
    final isStaff = auth.isStaff;
    final user = auth.userProfile ?? {};
    final bool isSuspended = (user['isSuspended'] as bool?) ?? false;

    DateTime? readDate(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }
    final DateTime? suspensionUntil = readDate(
      user['suspensionUntil'] ??
          user['suspensionExpiresAt'] ??
          user['suspensionEnd'],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: canManage ? const CreateEventFAB() : null,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<event_summary.EventSummary>>(
          future: _futureSummaries,
          builder: (ctx, snap) {
            final hasError = snap.hasError;
            final all = snap.data ?? [];

            final allLocations =
                all.map((e) => e.locationName).toSet().toList()
                  ..sort();

            final String? currentLocation =
                (_filterLocation != null && allLocations.contains(_filterLocation))
                    ? _filterLocation
                    : null;
            
            if (_filterLocation != currentLocation) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _filterLocation = currentLocation);
              });
            }

            final now = DateTime.now();

            final events = all.where((e) {
              if (e.status != event_summary.EventStatus.available) return false;
              if (currentLocation != null && e.locationName != currentLocation) {
                return false;
              }
              // Filter logic updated for SessionType.all
              if (_filterSessionType != SessionType.all &&
                  e.sessionType != _filterSessionType) {
                return false;
              }
              if (!eventEndDateTime(e).isAfter(now)) return false;
              return true;
            }).toList()
              ..sort((a, b) {
                final aEnd = eventEndDateTime(a);
                final bEnd = eventEndDateTime(b);
                if (_dateAsc) {
                  final c = aEnd.compareTo(bEnd);
                  if (c != 0) return c;
                } else if (_dateDesc) {
                  final c = bEnd.compareTo(aEnd);
                  if (c != 0) return c;
                }
                return 0;
              });

            return RefreshIndicator(
              color: Colors.white,
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  EventBrowserAppBar(
                    filterLocation: currentLocation,
                    onLocationChanged: (v) => setState(() => _filterLocation = v),
                    allLocations: allLocations,
                    onDropdownOpen: () {
                      setState(() {
                        dropdownOpenTime = DateTime.now().millisecondsSinceEpoch;
                      });
                    },
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(32),
                      child: Container(
                        color: AppColors.background,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                EventsFilter(
                                  onChanged: (v) => setState(() => _filterSessionType = v ?? SessionType.all),
                                  filterSessionType: _filterSessionType,
                                ),
                                EventsSort(
                                  dateAsc: _dateAsc,
                                  dateDesc: _dateDesc,
                                  onChanged: (session, dateAsc, dateDesc) {
                                    setState(() {
                                      _filterSessionType = session ?? SessionType.all;
                                      _dateAsc = dateAsc;
                                      _dateDesc = dateDesc;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Container(
                      padding: AppPadding.screen.copyWith(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasError)
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
                            Column(
                              children: events
                                  .map(
                                    (e) => EventTile(
                                      summary: e,
                                      isStaff: isStaff,
                                      isUser: isUser,
                                      isSuspended: isSuspended,
                                      suspensionUntil: suspensionUntil,
                                      canManage: canManage,
                                      loadDetail: (id) => AuthHttpClient
                                          .getNoAuth('/api/events/$id')
                                          .then((r) => EventDetail.fromJson(
                                                jsonDecode(r.body),
                                              )),
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
      ),
    );
  }
}