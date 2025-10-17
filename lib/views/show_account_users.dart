import 'dart:convert';
import 'package:corpsapp/providers/auth_provider.dart';
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:corpsapp/widgets/search_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_http_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

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
        items = body;
        _total = replace ? items.length : _total + items.length;
      } else {
        items = const [];
      }

      final pageUsers = items
        .cast<Map<String, dynamic>>()
        .map<_User>((j) => _User.fromJson(j))
        .toList();
    
      // Enrich this page with strike info (bulk request)
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
                u.strikes = (d['attendanceStrikeCount'] as int?) ?? u.strikes;
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
    const threshold = 280.0;
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
  // Children + Medical (user details)
  // ---------------------------

Future<void> _openUserDetail(_User u) async {
  List<_Child> kids = [];
  bool userHasMedical = false;
  List<_MedicalCondition> userMedical = [];

  final auth = context.read<AuthProvider>();
  final isAdmin = auth.isAdmin;
  final isManager = auth.isEventManager;

  final canEditRoles = isAdmin
      ? ['Event Manager', 'Staff', 'User']
      : isManager
          ? ['Staff', 'User']
          : <String>[];

  // --- Fetch children ---
  try {
    final resp =
        await AuthHttpClient.get('/api/UserManagement/user/${u.id}/children');
    if (resp.statusCode == 200) {
      final arr = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
      kids = arr.map((e) => _Child.fromJson(e)).toList();
    } else {
      _snack('Failed to fetch children (${resp.statusCode})', error: true);
    }
  } catch (e) {
    _snack('Failed to fetch children: $e', error: true);
  }

  // --- Fetch medical info ---
  try {
    final medResp =
        await AuthHttpClient.get('/api/UserManagement/user/${u.id}/medical');
    if (medResp.statusCode == 200) {
      final js = jsonDecode(medResp.body) as Map<String, dynamic>;
      userHasMedical = (js['hasMedicalConditions'] == true);
      final list = (js['medicalConditions'] as List?) ?? const [];
      userMedical = list
          .whereType<Map<String, dynamic>>()
          .map(_MedicalCondition.fromJson)
          .toList();
    }
  } catch (_) {/* ignore */}
  if (!mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: Colors.white12,
    builder: (ctx) {
      String? selectedRole;

      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return SafeArea(
            child: Padding(
              padding: AppPadding.screen,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            u.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          ActionableContact(
                              value: u.email,
                              type: 'Email',
                              scheme: 'mailto'),
                          const SizedBox(height: 4),
                          ActionableContact(
                              value: u.phoneNumber,
                              type: 'Phone',
                              scheme: 'tel'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    _medicalBlock(
                      title: 'Medical / Allergy Info',
                      hasAny: userHasMedical,
                      items: userMedical,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Children',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    kids.isEmpty
                        ? const Text(
                            'No children registered',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : CupertinoListSection.insetGrouped(
                            backgroundColor: AppColors.background,
                            margin: EdgeInsets.zero,
                            hasLeading: false,
                            children: kids
                                .map(
                                  (kid) => CupertinoListTile(
                                    title: Text(kid.fullName),
                                    subtitle: Text(
                                      'Age ${kid.age}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    trailing: const Icon(
                                        Icons.navigate_next_rounded,
                                        color: Colors.white70),
                                    onTap: () =>
                                        openChildDetail(context, kid),
                                  ),
                                )
                                .toList(),
                          ),

                    if (u.roles.any((r) => r.toLowerCase() == 'user')) ...[
                      const SizedBox(height: 16),
                      attendanceStrikeRow(
                          context,
                          u,
                          _updating,
                          _changeStrike,
                          () => setModalState(() {})),
                    ],

                    const SizedBox(height: 16),

                    if (canEditRoles.isNotEmpty) ...[   
                      Text(
                        'Role',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              u.roles.first,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16),
                            )
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero, 
                              minimumSize: Size(0, 0),  
                            ),
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (dialogCtx) {
                                  String? dialogSelectedRole = selectedRole;
                                  bool dialogLoading = false;

                                  return StatefulBuilder(
                                    builder: (ctx, setDialogState) {
                                      return CustomAlertDialog(
                                        title: 'Change Role',
                                        info: 'Select a new role for ${u.fullName}.',
                                        cancel: true,
                                        buttonLabel: dialogLoading ? 'Saving...' : 'Save',
                                        content: DropdownButtonHideUnderline(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black12,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            child: DropdownButton<String>(
                                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.normalText,),
                                              value: dialogSelectedRole,
                                              isExpanded: true,
                                              dropdownColor: Colors.white,
                                              hint: const Text(
                                                'Select role',
                                                style: TextStyle(color: AppColors.normalText),
                                              ),
                                              items: canEditRoles
                                                  .map((r) => DropdownMenuItem(
                                                        value: r,
                                                        child: Text(
                                                          r,
                                                          style: const TextStyle(color: AppColors.normalText),
                                                        ),
                                                      ))
                                                  .toList(),
                                              onChanged: (v) =>
                                                  setDialogState(() => dialogSelectedRole = v),
                                            ),
                                          ),
                                        ),
                                        buttonAction: dialogLoading
                                            ? null
                                            : () async {
                                                if (dialogSelectedRole == null) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Please select a role')),
                                                  );
                                                  return;
                                                }

                                                setDialogState(() => dialogLoading = true);
                                                try {
                                                  final resp = await AuthHttpClient.changeUserRole(
                                                    email: u.email,
                                                    role: dialogSelectedRole!,
                                                  );

                                                  final body = resp.body.isNotEmpty
                                                      ? jsonDecode(resp.body)
                                                      : <String, dynamic>{};

                                                  _snack(
                                                    body['message'] ??
                                                        (resp.statusCode == 200
                                                            ? 'Role changed successfully'
                                                            : 'Failed (${resp.statusCode})'),
                                                    error: resp.statusCode != 200,
                                                  );

                                                  if (resp.statusCode == 200) {
                                                    setModalState(() {
                                                      selectedRole = dialogSelectedRole;
                                                      u.roles
                                                        ..clear()
                                                        ..add(dialogSelectedRole!);
                                                    });
                                                    Navigator.pop(ctx);
                                                  }
                                                } catch (e) {
                                                  _snack('Error: $e', error: true);
                                                } finally {
                                                  setDialogState(() => dialogLoading = false);
                                                }
                                              },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            child: Text('Edit Role', style: TextStyle(color: AppColors.primaryColor, fontSize: 16)))
                        ],
                      ) ,             
                    ],
                  ],
                ),
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
        content: Text(msg, style: const TextStyle(color: AppColors.normalText)),
        backgroundColor: error ? AppColors.errorColor : Colors.white,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final isManager = auth.isEventManager;

    final canViewRoles = isAdmin ? ['event manager', 'staff', 'user']
                       : isManager ? ['staff', 'user'] : <String>[]; 

    String titleCase(String role) {
      return role
          .split(' ')
          .map((word) =>
              word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
          .join(' ');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'User Management'),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: AppPadding.screen,
          child: Column(
            children: [
              // Search
              CustomSearchBar(
                controller: _searchCtrl,
                onSearch: () {
                  _query = _searchCtrl.text;
                  _fetchFirstPage();
                },
                onClear: () {
                  _searchCtrl.clear();
                  _query = '';
                  _fetchFirstPage();
                },
              ),

              const SizedBox(height: 16),

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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text('No users found', style: TextStyle(fontSize: 16)),
                                  ],
                                )
                              ],
                            )
                          : ListView(
                            controller: _scroll,
                            children: [
                              for (final role in canViewRoles) ...[
                                if (_users.any((u) =>
                                    u.roles.any((r) => r.toLowerCase() == role)))
                                  CupertinoListSection.insetGrouped(
                                    margin: EdgeInsets.all(0),
                                    backgroundColor: AppColors.background,
                                    header: Text(
                                      // Capitalize the role for display
                                      '${titleCase(role)}s',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    children: [
                                      for (final u in _users)
                                        if (u.roles.any((r) => r.toLowerCase() == role))
                                          _UserTile(
                                            user: u,
                                            onTap: () => _openUserDetail(u),
                                          ),
                                    ],                             
                                  ),
                                  const SizedBox(height: 8)
                              ]
                            ],
                          )                                               
                      ),
              ),
            ],
          ),
        ),       
      ),
    );
  }
}

// ---------------------------
// Widgets
// --------------------------- 
Widget attendanceStrikeRow(
  BuildContext context,
  _User u,
  bool updating,
  Future<void> Function(_User, int) changeStrike,
  void Function() refresh,
) {
  Future<void> confirmChange(int oldValue, int newValue) async {
    newValue = newValue.clamp(0, 3);
    if (newValue == oldValue) return;

    final confirmed = await showDialog<bool>(
      context: context, 
      builder: (ctx) => CustomAlertDialog(
        title: 'Confirm Strike Change', 
        info: 'Change strikes from $oldValue to $newValue?',
        cancel: true,
        buttonAction: () => Navigator.of(ctx).pop(true),
      )
    );

    if (confirmed == true) {
      await changeStrike(u, newValue - oldValue); 
    }
  }

  return Row(
    children: [
      Expanded(
        child: Text(
          'Attendance Strikes',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        )
      ),
      
      const SizedBox(width: 16),

      Container(
        padding: EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: Color(0xFF242424),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white38),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: updating
                ? null
                : () async {
                    await confirmChange(u.strikes, u.strikes - 1);
                    refresh();
                  },
              icon: Icon(Icons.remove, size: 16, color: Colors.white),
            ),

            Text(
              '${u.strikes}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            IconButton(
              onPressed: updating
                  ? null
                  : () async {
                      await confirmChange(u.strikes, u.strikes + 1);
                      refresh();
                    },
              icon: Icon(Icons.add, size: 16, color: Colors.white)
            ),
          ],
        ),
      ),
    ],
  );
}


Future<void> openChildDetail(BuildContext context, _Child child) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    useSafeArea: true,
    barrierColor: Colors.black87,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: AppPadding.screen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              Center(
                child: Column(
                  children: [
                    Text(
                      child.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 4),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Birthdate: ${child.dobLabel}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                        const SizedBox(width: 16),
                        Text('Age: ${child.age}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),                                  
                  ],                
                ),               
              ),

              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Contact', 
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Text(child.emergencyContactName, style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(width: 8),
                      ActionableContact(value: child.emergencyContactPhone, type: 'Phone', scheme: 'tel'),
                    ],
                  ),
                ],
              ),
               
              const SizedBox(height: 16),

              _medicalBlock(
                title: 'Medical / Allergy Info',
                hasAny: child.hasMedicalConditions,
                items: child.medicalConditions,
              ),            
            ],
          ),
        ),
      );
    },
  );
}

class ActionableContact extends StatelessWidget {
  final String? value; 
  final String type; 
  final String scheme; 

  const ActionableContact({
    required this.value,
    required this.type,
    required this.scheme
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = (value ?? '').trim();
    final isEmpty = trimmed.isEmpty;

    final style = TextStyle(
      color: isEmpty ? Colors.white38 : AppColors.primaryColor,
      fontSize: 16,
      decoration: TextDecoration.none,
    );

    Future<void> launch() async {
      if (isEmpty) return;

      final uri = Uri(scheme: scheme, path: trimmed);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _copy(context);
      }
    }

    return GestureDetector(
      onTap: launch,
      onLongPress: () => _copy(context),
      child: Text(isEmpty ? '' : trimmed, style: style),
    );
  }

  void _copy(BuildContext context) {
    if ((value ?? '').trim().isEmpty) return;

    Clipboard.setData(ClipboardData(text: value!.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final _User user;

  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.firstName, user.lastName);
    final suspended = user.isSuspended == true;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: suspended ? AppColors.errorColor : Colors.white12,
              child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                  ),

                  const SizedBox(height: 4),
                  
                  Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 12)),

                  if (suspended) ... [
                    const SizedBox(height: 4),

                    Text(
                      'SUSPENDED',
                      style: TextStyle(
                        color: AppColors.errorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),   
                  ]                
                ],
              ),
            ),
            const SizedBox(width: 4),

            Icon(Icons.navigate_next, color: Colors.white70),
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
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final List<String> roles;

  int strikes; // enriched via /users/by-ids
  String? dateOfLastStrike;
  bool? isSuspended;

  _User({
    required this.id,
    required this.email,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    this.strikes = 0,
    this.dateOfLastStrike,
    this.isSuspended,
    required this.roles,
  });

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();

  factory _User.fromJson(Map<String, dynamic> j) => _User(
    id: (j['id'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    phoneNumber: j['phoneNumber'].toString(),
    firstName: (j['firstName'] ?? '').toString(),
    lastName: (j['lastName'] ?? '').toString(),
    strikes: j['attendanceStrikeCount'] is int ? j['attendanceStrikeCount'] as int : 0,
    dateOfLastStrike: j['dateOfLastStrike']?.toString(),
    isSuspended: j['isSuspended'] as bool?,
    roles: (j['roles'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );
}

class _MedicalCondition {
  final int id;
  final String name;
  final String? notes;
  final bool isAllergy;

  _MedicalCondition({
    required this.id,
    required this.name,
    required this.notes,
    required this.isAllergy,
  });

  factory _MedicalCondition.fromJson(Map<String, dynamic> j) => _MedicalCondition(
        id: (j['id'] ?? j['Id'] ?? 0) as int,
        name: (j['name'] ?? j['Name'] ?? '').toString(),
        notes: (j['notes'] ?? j['Notes'])?.toString(),
        isAllergy: j['isAllergy'] == true || j['IsAllergy'] == true,
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

  // Medical
  final bool hasMedicalConditions;
  final List<_MedicalCondition> medicalConditions;

  _Child({
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.age,
    required this.hasMedicalConditions,
    required this.medicalConditions,
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

    final medsRaw = (j['medicalConditions'] ?? j['MedicalConditions']) as List<dynamic>? ?? const [];
    final meds = medsRaw.whereType<Map<String, dynamic>>().map(_MedicalCondition.fromJson).toList();

    return _Child(
      childId: (j['childId'] ?? j['ChildId'] ?? 0) as int,
      firstName: (j['firstName'] ?? j['FirstName'] ?? '').toString(),
      lastName: (j['lastName'] ?? j['LastName'] ?? '').toString(),
      dateOfBirth: parseDob(j['dateOfBirth'] ?? j['DateOfBirth']),
      emergencyContactName: (j['emergencyContactName'] ?? j['EmergencyContactName'] ?? '').toString(),
      emergencyContactPhone: (j['emergencyContactPhone'] ?? j['EmergencyContactPhone'] ?? '').toString(),
      age: (j['age'] ?? j['Age'] ?? 0) as int,
      hasMedicalConditions: (j['hasMedicalConditions'] ?? j['HasMedicalConditions']) == true || meds.isNotEmpty,
      medicalConditions: meds,
    );
  }
}

// ---------------------------
// Medical UI helpers
// ---------------------------

Widget _medicalBlock({
  required String title,
  required bool hasAny,
  required List<_MedicalCondition> items,
}) {
  final showNone = !hasAny || items.isEmpty;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (showNone)
        Text('None reported',
            style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, fontSize: 14))
      else
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map(_medicalTile).toList(),
        ),
    ],
  );
}

Widget _medicalTile(_MedicalCondition m) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white38),
      color: Color(0xFF242424),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: m.isAllergy ? 8 : 0,   
            right: m.isAllergy ? 8 : 0, 
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16
                ),
              ),
              if ((m.notes ?? '').trim().isNotEmpty)...[
                const SizedBox(height: 4),
                Text(
                  m.notes!,
                  style: const TextStyle(color: Colors.white),
                ),
              ]
            ],
          ),
        ),

        if (m.isAllergy)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x33FF5252),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.errorColor),
              ),
              child: const Text(
                'ALLERGY',
                style: TextStyle(
                  color: AppColors.errorColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

