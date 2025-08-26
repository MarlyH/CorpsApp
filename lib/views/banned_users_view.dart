import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_http_client.dart';

class BannedUsersView extends StatefulWidget {
  const BannedUsersView({super.key});

  @override
  State<BannedUsersView> createState() => _BannedUsersViewState();
}

class _BannedUsersViewState extends State<BannedUsersView> {
  late Future<List<BannedUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BannedUser>> _load() async {
    final resp = await AuthHttpClient.getBannedUsers();
    final list = (jsonDecode(resp.body) as List)
        .map((e) => BannedUser.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }


  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _unban(BannedUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear strikes?', style: TextStyle(color: Colors.white)),
        content: Text('This will restore access for ${u.displayName}.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('CLEAR STRIKES', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    ) ?? false;
    if (!ok) return;

    try {
      // use postRaw so we can read error instead of throwing
      final resp = await AuthHttpClient.postRaw(
        '/api/usermanagement/unban/${u.userId}',
        body: jsonEncode({}), // empty JSON body
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unbanned ${u.displayName}')),
        );
        await _refresh();
        return;
      }

      // show server-provided message to see the real cause (403/404/etc)
      final msg = _tryGetMessage(resp.body) ??
          'Unban failed (HTTP ${resp.statusCode}).';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error'), backgroundColor: Colors.redAccent),
      );
    }
  }


  String? _tryGetMessage(String b) {
    try { return (jsonDecode(b) as Map<String,dynamic>)['message'] as String?; }
    catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Ban Management', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.white,
          onRefresh: _refresh,
          child: FutureBuilder<List<BannedUser>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snap.hasError) {
                return Center(
                  child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.white)),
                );
              }
              final users = snap.data ?? const [];
              if (users.isEmpty) {
                return const Center(
                  child: Text('No active bans', style: TextStyle(color: Colors.white70)),
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                itemBuilder: (ctx, i) {
                  final u = users[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const Icon(Icons.person_off, color: Colors.white70),
                    title: Text(u.displayName, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      '${u.email}\n'
                      'Strikes: ${u.attendanceStrikeCount}  •  '
                      'Last: ${u.lastStrikeLabel}  •  '
                      'Until: ${u.untilLabel}',
                      style: const TextStyle(color: Colors.white70, height: 1.25),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _unban(u),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4C85D0),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('UNBAN',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class BannedUser {
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final int attendanceStrikeCount;
  final DateTime? dateOfLastStrike;
  final DateTime? suspensionUntil;

  BannedUser({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.attendanceStrikeCount,
    required this.dateOfLastStrike,
    required this.suspensionUntil,
  });

  String get displayName {
    final fn = firstName.trim(), ln = lastName.trim();
    return (fn.isEmpty && ln.isEmpty) ? email : '$fn $ln'.trim();
  }

  String get lastStrikeLabel =>
      dateOfLastStrike != null ? _yyyyMmDd(dateOfLastStrike!) : '—';

  String get untilLabel =>
      suspensionUntil != null ? _yyyyMmDd(suspensionUntil!) : '—';

  static String _yyyyMmDd(DateTime dt) =>
      dt.toLocal().toIso8601String().split('T').first;

  factory BannedUser.fromJson(Map<String, dynamic> j) {
    // Accept either 'userId' or 'id' from API
    final id = (j['userId'] ?? j['id'] ?? '') as String;
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      // DateOnly likely "yyyy-MM-dd"
      try { return DateTime.parse(v.toString()); } catch (_) { return null; }
    }

    return BannedUser(
      userId: id,
      email: (j['email'] ?? '') as String,
      firstName: (j['firstName'] ?? '') as String,
      lastName: (j['lastName'] ?? '') as String,
      attendanceStrikeCount: (j['attendanceStrikeCount'] ?? 0) as int,
      dateOfLastStrike: parseDate(j['dateOfLastStrike']),
      suspensionUntil: parseDate(j['suspensionUntil']),
    );
  }
}
