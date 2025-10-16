import 'dart:convert';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:flutter/material.dart';
import '../services/auth_http_client.dart';

class BannedUsersView extends StatefulWidget {
  const BannedUsersView({super.key});

  @override
  State<BannedUsersView> createState() => _BannedUsersViewState();
}

class _BannedUsersViewState extends State<BannedUsersView> {
  late Future<List<BannedUser>> _future;

  // Track which rows are currently unbanning (prevents double taps)
  final Set<String> _busyIds = <String>{};

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
      builder: (_) => CustomAlertDialog(
        title: 'Clear Strikes?', 
        info: 'This will unban ${u.displayName} and clear all the associated strikes.',
        cancel: true,
        buttonLabel: 'Confirm',
        buttonAction: () => Navigator.pop(context, true),
      )
    ) ?? false;

    if (!ok) return;

    // mark this row as busy to prevent double taps
    setState(() => _busyIds.add(u.userId));

    try {
      final resp = await AuthHttpClient.postRaw(
        '/api/usermanagement/unban/${u.userId}',
        body: jsonEncode({}), // empty JSON body
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unbanned ${u.displayName}')),
        );
        await _refresh();           // <— refresh the list
        return;
      }

      // if already unbanned elsewhere, clean up the list too
      if (resp.statusCode == 404) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User already unbanned.')),
        );
        await _refresh();
        return;
      }

      final msg = _tryGetMessage(resp.body) ??
          'Unban failed (HTTP ${resp.statusCode}).';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.errorColor),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error'), backgroundColor: AppColors.errorColor),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(u.userId)); // release busy state
      }
    }
  }

  String? _tryGetMessage(String b) {
    try {
      return (jsonDecode(b) as Map<String, dynamic>)['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Ban Management'),    
      body: SafeArea(
        child: Padding(
          padding: AppPadding.screen,
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
                  separatorBuilder: (_, __) => const Divider(color: Colors.white24, height: 0),
                  itemBuilder: (ctx, i) {
                    final u = users[i];
                    final isBusy = _busyIds.contains(u.userId);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      title: Text(u.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${u.email}\n'
                        'Banned Until: ${u.untilLabel}',
                      ),
                      trailing: Button(
                        label: 'Unban', 
                        onPressed: isBusy ? null : () => _unban(u),
                        loading: isBusy,
                        buttonWidth: 100,
                        radius: 100,
                      ),                    
                    );
                  },
                );
              },
            ),
          ),
        )     
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
    final id = (j['userId'] ?? j['id'] ?? '') as String;

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
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
