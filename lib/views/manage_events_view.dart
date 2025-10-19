import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/EventExpandableCard/event_summary.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/search_bar.dart';
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
      final resp = await AuthHttpClient.get('/api/events/manage');
      final list = jsonDecode(resp.body) as List<dynamic>;
      _allEvents = list.cast<Map<String, dynamic>>().map(EventSummary.fromJson).toList();
      _filtered = List.from(_allEvents);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load events: $e'), backgroundColor: Colors.redAccent),
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
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Events'),
      body: Padding(
        padding: AppPadding.screen,
        child: Column(
        children: [
          // Search bar
          CustomSearchBar(
            hintText: 'Search',
            controller: _searchCtrl, 
            onSearch: () { _filter(); }, 
            onClear: () { _searchCtrl.clear(); _filter(); }
          ),

          const SizedBox(height: 8),

          Text(
            'You can search by location, time, date, or session.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

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
                        padding: EdgeInsetsGeometry.symmetric(vertical: 8),                       
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManageEventDetailView(event: e),
                            ),
                          ),
                          child: EventSummaryCard(summary: e, isExpanded: false),
                        )                                                
                      );
                    },
                  ),
                ),
          ),         
        ],
      ),
      ),     
    );
  }
}
