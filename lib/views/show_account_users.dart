import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_http_client.dart';

class ManageUsersView extends StatefulWidget {
  const ManageUsersView({super.key});

  @override
  State<ManageUsersView> createState() => _ManageUsersViewState();
}

class _ManageUsersViewState extends State<ManageUsersView> {
  // Paging
  static const int _pageSize = 20;
  int _page = 1;
  int _total = 0;
  bool _loadingFirstPage = true;
  bool _loadingMore = false;
  bool _updating = false;
  bool _hasMore = true;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // Data
  final List<_User> _users = [];
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchFirstPage();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------
  // Networking
  // ---------------------------

  Future<void> _fetchFirstPage() async {
    setState(() {
      _loadingFirstPage = true;
      _page = 1;
      _hasMore = true;
      _total = 0;
      _users.clear();
    });
    await _fetchPage(_page, replace: true);
    if (mounted) setState(() => _loadingFirstPage = false);
  }

  Future<void> _fetchNextPage() async {
    if (!_hasMore || _loadingMore || _loadingFirstPage) return;
    setState(() => _loadingMore = true);
    _page += 1;
    await _fetchPage(_page, replace: false);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _fetchPage(int page, {required bool replace}) async {
    try {
      final uri = Uri(
        path: '/api/UserManagement/users',
        queryParameters: {
          if (_query.trim().isNotEmpty) 'q': _query.trim(),
          'page': '$page',
          'pageSize': '$_pageSize',
        },
      ).toString();

      final resp = await AuthHttpClient.get(uri);
      if (resp.statusCode != 200) {
        _snack('Failed to load users (${resp.statusCode})', error: true);
        return;
      }

      final body = jsonDecode(resp.body);
      late final List items;
      if (body is Map<String, dynamic>) {
        _total = (body['total'] as int?) ?? 0;
        items = (body['items'] as List?) ?? const [];
      } else if (body is List) {
        // If your API returns a flat array (no paging metadata)
        items = body;
        _total = replace ? items.length : _total + items.length;
      } else {
        items = const [];
      }

      final pageUsers = items
          .cast<Map<String, dynamic>>()
          .map<_User>((j) => _User.fromJson(j))
          .toList();

      // Enrich this page with strike info
      if (pageUsers.isNotEmpty) {
        final ids = pageUsers.map((u) => u.id).where((id) => id.isNotEmpty).toList();
        try {
          final detailsResp = await AuthHttpClient.postRaw(
            '/api/UserManagement/users/by-ids',
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ids': ids}),
          );
          if (detailsResp.statusCode == 200) {
            final details = (jsonDecode(detailsResp.body) as List)
                .where((e) => e != null)
                .cast<Map<String, dynamic>>();

            final map = {for (final d in details) (d['id'] ?? '').toString(): d};
            for (final u in pageUsers) {
              final d = map[u.id];
              if (d != null) {
                u.strikes = (d['attendanceStrikeCount'] as int?) ?? 0;
                u.dateOfLastStrike = d['dateOfLastStrike']?.toString();
                u.isSuspended = d['isSuspended'] == true;
              }
            }
          }
        } catch (_) {/* best effort */}
      }

      if (replace) {
        _users
          ..clear()
          ..addAll(pageUsers);
      } else {
        _users.addAll(pageUsers);
      }

      // Update hasMore if we have paging metadata
      if (_total > 0) {
        _hasMore = _users.length < _total;
      } else {
        // No total provided: infer from page size
        _hasMore = pageUsers.length == _pageSize;
      }

      if (mounted) setState(() {});
    } catch (e) {
      _snack('Failed to load users: $e', error: true);
    }
  }

  Future<void> _refresh() async => _fetchFirstPage();

  void _maybeLoadMore() {
    if (!_hasMore || _loadingMore || _loadingFirstPage) return;
    final threshold = 280.0; // px from bottom to prefetch
    if (_scroll.position.pixels + threshold >= _scroll.position.maxScrollExtent) {
      _fetchNextPage();
    }
  }

  Future<void> _changeStrike(_User u, int delta) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      final endpoint = delta > 0
          ? '/api/UserManagement/strikes/increment'
          : '/api/UserManagement/strikes/decrement';

      final payload = {
        'userId': u.id,
        'amount': (delta.abs() == 0 ? 1 : delta.abs()),
      };

      final resp = await AuthHttpClient.postRaw(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body) as Map<String, dynamic>;
        final updated = js['user'] as Map<String, dynamic>?;
        if (updated != null) {
          u.strikes = (updated['attendanceStrikeCount'] as int?) ?? (u.strikes + delta).clamp(0, 9999);
          u.dateOfLastStrike = updated['dateOfLastStrike']?.toString();
          u.isSuspended = updated['isSuspended'] == true;
        } else {
          u.strikes = (u.strikes + delta).clamp(0, 9999);
        }
        if (mounted) setState(() {});
        _snack(delta > 0 ? 'Strike added to ${u.fullName}' : 'Strike removed from ${u.fullName}');
      } else if (resp.statusCode == 403) {
        _snack('Not allowed: ${resp.body}', error: true);
      } else {
        _snack('Strike update failed (${resp.statusCode}): ${resp.body}', error: true);
      }
    } catch (e) {
      _snack('Strike update failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  // ---------------------------
  // Children (user details)
  // ---------------------------

  Future<void> _openUserDetail(_User u) async {
    List<_Child> kids = [];
    try {
      final resp = await AuthHttpClient.get('/api/UserManagement/user/${u.id}/children');
      if (resp.statusCode == 200) {
        final arr = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
        kids = arr.map((e) => _Child.fromJson(e)).toList();
      } else {
        _snack('Failed to fetch children (${resp.statusCode})', error: true);
      }
    } catch (e) {
      _snack('Failed to fetch children: $e', error: true);
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (ctx, scrollCtrl) {
            return SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            u.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Text(u.email, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 12),

                    const Text('Children', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),

                    if (kids.isEmpty)
                      const Text('No children on file.', style: TextStyle(color: Colors.white54))
                    else
                      Expanded(
                        child: ListView.separated(
                          controller: scrollCtrl,
                          itemCount: kids.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = kids[i];
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.fullName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.cake, size: 14, color: Colors.white70),
                                      const SizedBox(width: 6),
                                      Text(
                                        c.dobLabel,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                      const SizedBox(width: 12),
                                      Text('Age: ${c.age}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.phone, size: 14, color: Colors.white70),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${c.emergencyContactName} • ${c.emergencyContactPhone}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------
  // UI
  // ---------------------------

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black)),
        backgroundColor: error ? Colors.redAccent : Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'User Management',
          style: TextStyle(
            letterSpacing: 1.2,
            fontFamily: 'WinnerSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadingFirstPage ? null : _fetchFirstPage,
            icon: const Icon(Icons.refresh, color: Colors.white),
          )
        ],
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField
                        (
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          decoration: const InputDecoration(
                            hintText: 'Search by name or email',
                            hintStyle: TextStyle(color: Colors.black),
                            border: InputBorder.none,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) {
                            _query = _searchCtrl.text;
                            _fetchFirstPage();
                          },
                        ),

                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.black54),
                        onPressed: () {
                          _searchCtrl.clear();
                          _query = '';
                          _fetchFirstPage();
                        },
                      ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: _loadingFirstPage
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : RefreshIndicator(
                      color: Colors.white,
                      onRefresh: _refresh,
                      child: _users.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 80),
                                Center(
                                  child: Text('No users found', style: TextStyle(color: Colors.white54)),
                                ),
                                SizedBox(height: 400),
                              ],
                            )
                          : ListView.separated(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: _users.length + (_loadingMore || _hasMore ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                if (i >= _users.length) {
                                  // Loader at the end
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: _hasMore
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : const Text('No more users',
                                              style: TextStyle(color: Colors.white54)),
                                    ),
                                  );
                                }
                                final u = _users[i];
                                return _UserTile(
                                  user: u,
                                  busy: _updating,
                                  onAddStrike: () => _changeStrike(u, 1),
                                  onRemoveStrike: () => _changeStrike(u, -1),
                                  onTap: () => _openUserDetail(u),
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

// ---------------------------
// Widgets
// ---------------------------

class _UserTile extends StatelessWidget {
  final _User user;
  final VoidCallback onAddStrike;
  final VoidCallback onRemoveStrike;
  final VoidCallback onTap;
  final bool busy;

  const _UserTile({
    required this.user,
    required this.onAddStrike,
    required this.onRemoveStrike,
    required this.onTap,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.firstName, user.lastName);
    final suspended = user.isSuspended == true;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: suspended ? Colors.red.shade700 : Colors.white24,
              child: Text(initials, style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  if (suspended)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'SUSPENDED',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Strike controls
            Container(
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: busy ? null : onRemoveStrike,
                    icon: const Icon(Icons.remove, size: 18, color: Colors.white),
                    tooltip: 'Remove strike',
                    splashRadius: 18,
                  ),
                  Text(
                    '${user.strikes}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : onAddStrike,
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    tooltip: 'Add strike',
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String f, String l) {
    final a = f.isNotEmpty ? f[0].toUpperCase() : '';
    final b = l.isNotEmpty ? l[0].toUpperCase() : '';
    return (a + b).isEmpty ? 'U' : (a + b);
  }
}

// ---------------------------
// Models
// ---------------------------

class _User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;

  int strikes; // enriched via /users/by-ids
  String? dateOfLastStrike;
  bool? isSuspended;

  _User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.strikes = 0,
    this.dateOfLastStrike,
    this.isSuspended,
  });

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();

  factory _User.fromJson(Map<String, dynamic> j) => _User(
        id: (j['id'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        firstName: (j['firstName'] ?? '').toString(),
        lastName: (j['lastName'] ?? '').toString(),
        // If your /users endpoint already returns these, they’ll be used; otherwise enriched later.
        strikes: j['attendanceStrikeCount'] is int ? j['attendanceStrikeCount'] as int : 0,
        dateOfLastStrike: j['dateOfLastStrike']?.toString(),
        isSuspended: j['isSuspended'] as bool?,
      );
}

class _Child {
  final int childId;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final int age;

  _Child({
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.age,
  });

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();
  String get dobLabel {
    if (dateOfBirth == null) return 'Unknown DOB';
    final y = dateOfBirth!.year.toString().padLeft(4, '0');
    final m = dateOfBirth!.month.toString().padLeft(2, '0');
    final d = dateOfBirth!.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  factory _Child.fromJson(Map<String, dynamic> j) {
    DateTime? parseDob(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      try {
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
          final parts = s.split('-').map(int.parse).toList();
          return DateTime(parts[0], parts[1], parts[2]);
        }
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    return _Child(
      childId: (j['childId'] ?? j['ChildId'] ?? 0) as int,
      firstName: (j['firstName'] ?? j['FirstName'] ?? '').toString(),
      lastName: (j['lastName'] ?? j['LastName'] ?? '').toString(),
      dateOfBirth: parseDob(j['dateOfBirth'] ?? j['DateOfBirth']),
      emergencyContactName: (j['emergencyContactName'] ?? j['EmergencyContactName'] ?? '').toString(),
      emergencyContactPhone: (j['emergencyContactPhone'] ?? j['EmergencyContactPhone'] ?? '').toString(),
      age: (j['age'] ?? j['Age'] ?? 0) as int,
    );
  }
}
