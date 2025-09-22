import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/services/auth_http_client.dart';
import 'package:corpsapp/providers/auth_provider.dart';
import 'package:corpsapp/models/event_summary.dart' as event_summary;
import 'package:corpsapp/models/event_detail.dart';

import '../views/qr_scan_view.dart';
import '../views/create_event_view.dart';

String _friendlySession(event_summary.SessionType type) {
  switch (type) {
    case event_summary.SessionType.Ages8to11: return 'Ages 8 to 11';
    case event_summary.SessionType.Ages12to15: return 'Ages 12 to 15';
    default: return 'Ages 16+';
  }
}

String _niceDayDate(DateTime d) {
  const week = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  const mon  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final local = d.toLocal();
  return '${week[local.weekday - 1]} • ${local.day.toString().padLeft(2,'0')} ${mon[local.month - 1]} ${local.year}';
}

DateTime _eventEndDateTime(event_summary.EventSummary e) {
  final t = (e.endTime ?? '').trim();
  final m = RegExp(r'^(\d{1,2})\s*:\s*(\d{2})\s*(AM|PM|am|pm)?').firstMatch(t);

  int hh = 0, mm = 0; String? ampm;
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

class HomeHubFragment extends StatefulWidget {
  final VoidCallback? onSeeAllEvents; // use this to switch tab to Events

  const HomeHubFragment({super.key, this.onSeeAllEvents});

  @override
  State<HomeHubFragment> createState() => _HomeHubFragmentState();
}

class _HomeHubFragmentState extends State<HomeHubFragment> {
  late Future<List<event_summary.EventSummary>> _futureEvents;
  late Future<List<_ChangeItem>> _futureChanges;

  @override
  void initState() {
    super.initState();
    _futureEvents  = _loadEvents();
    _futureChanges = _loadChanges();
  }

  Future<List<event_summary.EventSummary>> _loadEvents() async {
    final resp = await AuthHttpClient.getNoAuth('/api/events');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(event_summary.EventSummary.fromJson).toList();
  }

  // Optional backend: GET /api/app/changelog -> [{title, date, text}]
  Future<List<_ChangeItem>> _loadChanges() async {
    try {
      final resp = await AuthHttpClient.getNoAuth('/api/app/changelog');
      if (resp.statusCode != 200) throw 'not ok';
      final list = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
      return list.map((j) => _ChangeItem(
        title: (j['title'] ?? '').toString(),
        date : DateTime.tryParse((j['date'] ?? '').toString()),
        text : (j['text'] ?? '').toString(),
      )).toList();
    } catch (_) {
      // Fallback sample so the section still looks nice this is just for testing
      // could add a new endpoint later for pulling dedicated change log
      return [
        _ChangeItem(
          title: 'New Home hub',
          date: DateTime.now().subtract(const Duration(days: 2)),
          text: 'A fresh dashboard with intro, quick actions and upcoming events.',
        ),
        _ChangeItem(
          title: 'QR scanner improvements',
          date: DateTime.now().subtract(const Duration(days: 7)),
          text: 'Faster scans and clearer error messages for invalid codes.',
        ),
      ];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _futureEvents  = _loadEvents();
      _futureChanges = _loadChanges();
    });
    await Future.wait([_futureEvents, _futureChanges]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.userProfile ?? {};
    final firstName = (profile['firstName'] as String?)?.trim();
    final greetingName = (firstName != null && firstName.isNotEmpty) ? firstName : 'there';

    final isAdmin = auth.isAdmin;
    final isMgr   = auth.isEventManager;
    final isStaff = auth.isStaff;

    final canCreateEvent = isAdmin || isMgr;
    final canScan        = isAdmin || isMgr || isStaff;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Colors.white,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppPadding.screen.copyWith(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCard(greetingName: greetingName),
                const SizedBox(height: 16),

                _AboutCard(),
                const SizedBox(height: 16),

                if (canCreateEvent || canScan)
                  _QuickActions(
                    canCreateEvent: canCreateEvent,
                    canScan: canScan,
                    // Use direct routes so this works even if named routes aren’t set
                    onCreateEvent: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateEventView()));
                    },
                    onScan: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanView()));
                    },
                  ),

                const SizedBox(height: 16),
                const _SectionTitle('Upcoming events'),
                const SizedBox(height: 8),

                FutureBuilder<List<event_summary.EventSummary>>(
                  future: _futureEvents,
                  builder: (ctx, snap) {
                    final loading = snap.connectionState == ConnectionState.waiting;
                    final hasError = snap.hasError;
                    final all = snap.data ?? [];

                    if (loading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(color: Colors.white)),
                      );
                    }
                    if (hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Couldn’t load events right now.', style: TextStyle(color: Colors.white70)),
                      );
                    }

                    final now = DateTime.now();
                    final upcoming = all
                        .where((e) => e.status == event_summary.EventStatus.Available && _eventEndDateTime(e).isAfter(now))
                        .toList()
                      ..sort((a, b) => a.startDate.compareTo(b.startDate));

                    if (upcoming.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No upcoming events yet. Check back soon!',
                            style: TextStyle(color: Colors.white70)),
                      );
                    }

                    final top = upcoming.take(2).toList();

                    return Column(
                      children: [
                        for (final e in top) _MiniEventTile(summary: e),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              // Switch tab to Events (index 1)
                              if (widget.onSeeAllEvents != null) {
                                widget.onSeeAllEvents!();
                              }
                            },
                            icon: const Icon(Icons.event, color: Colors.white70, size: 18),
                            label: const Text('See all events',
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),
                const _SectionTitle('What’s new'),
                const SizedBox(height: 8),
                FutureBuilder<List<_ChangeItem>>(
                  future: _futureChanges,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator(color: Colors.white)),
                      );
                    }
                    final items = snap.data ?? const <_ChangeItem>[];
                    if (items.isEmpty) {
                      return const Text('No recent updates.', style: TextStyle(color: Colors.white54));
                    }
                    return Column(
                      children: items.take(5).map((c) => _ChangeTile(item: c)).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'More features coming soon…',
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ==== UI bits ==== */

class _HeroCard extends StatelessWidget {
  final String greetingName;
  const _HeroCard({required this.greetingName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.center,
            child: Image.asset('assets/logo/logo_transparent_1024px.png', height: 62, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hey $greetingName,',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      fontFamily: 'WinnerSans',
                    )),
                const SizedBox(height: 4),
                const Text(
                  'Welcome to Your Corps — a safe, engaging community hub with guided sessions, '
                  'mentoring, and activities to help young people grow.',
                  style: TextStyle(color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('What is Your Corps?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                fontFamily: 'WinnerSans',
              )),
          SizedBox(height: 8),
          Text(
            'Your Corps connects young people, families, and mentors through '
            'free community events. Book seats, check in with QR passes, and stay updated with '
            'the latest programmes — all from this app.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool canCreateEvent;
  final bool canScan;
  final VoidCallback onCreateEvent;
  final VoidCallback onScan;

  const _QuickActions({
    required this.canCreateEvent,
    required this.canScan,
    required this.onCreateEvent,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Quick actions'),
        const SizedBox(height: 8),
        Row(
          children: [
            if (canScan)
              Expanded(child: _ActionCard(icon: Icons.qr_code_scanner, label: 'Open scanner', onTap: onScan)),
            if (canScan && canCreateEvent) const SizedBox(width: 12),
            if (canCreateEvent)
              Expanded(child: _ActionCard(icon: Icons.add_circle_outline, label: 'Create event', onTap: onCreateEvent)),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'WinnerSans',
                    )),
              ),
              const Icon(Icons.chevron_right, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        fontSize: 12,
        fontFamily: 'WinnerSans',
      ),
    );
  }
}

class _MiniEventTile extends StatelessWidget {
  final event_summary.EventSummary summary;
  const _MiniEventTile({required this.summary});

  Future<EventDetail> _loadDetail() async {
    final resp = await AuthHttpClient.getNoAuth('/api/events/${summary.eventId}');
    final js = jsonDecode(resp.body) as Map<String, dynamic>;
    return EventDetail.fromJson(js);
  }

  @override
  Widget build(BuildContext context) {
    final date = _niceDayDate(summary.startDate);
    final time = '${summary.startTime ?? '—'} • ${summary.endTime ?? '—'}';
    final session = _friendlySession(summary.sessionType);
    final venue = summary.locationName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.event, color: Colors.black87, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(venue,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        fontFamily: 'WinnerSans',
                      )),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(999)),
                  child: Text(session,
                      style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.black54, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('$date • $time', style: const TextStyle(color: Colors.black54, fontSize: 12))),
              ],
            ),
            const SizedBox(height: 6),
            FutureBuilder<EventDetail>(
              future: _loadDetail(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Row(
                    children: const [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Loading address…', style: TextStyle(color: Colors.black45, fontSize: 12)),
                    ],
                  );
                }
                if (!snap.hasData) return const SizedBox.shrink();
                final addr = snap.data!.address.trim();
                if (addr.isEmpty) return const SizedBox.shrink();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place, color: Colors.black54, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(addr, style: const TextStyle(color: Colors.black54, fontSize: 12))),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ==== Changelog UI ==== */

class _ChangeItem {
  final String title;
  final DateTime? date;
  final String text;
  _ChangeItem({required this.title, required this.date, required this.text});
}

class _ChangeTile extends StatelessWidget {
  final _ChangeItem item;
  const _ChangeTile({required this.item});

  String _fmt(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2,'0');
    const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '$dd ${mon[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFamily: 'WinnerSans',
              )),
          if (item.date != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(_fmt(item.date),
                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
            ),
          Text(item.text, style: const TextStyle(color: Colors.white70, height: 1.3, fontSize: 12)),
        ],
      ),
    );
  }
}
