import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../views/account_security_view.dart';
import '../views/notifications_view.dart';
import '../views/manage_children_view.dart';
import '../views/manage_events_view.dart';
import '../views/change_user_role_view.dart';
import '../views/manage_locations_view.dart';
import '../views/about_corps_view.dart';
import '../views/policies_view.dart';
import '../views/support_and_feedback_view.dart';
import '../views/ban_appeal_view.dart';
import '../views/banned_users_view.dart';
import '../views/show_account_users.dart';

class ProfileFragment extends StatelessWidget {
  const ProfileFragment({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userProfile ?? {};
    final isUser = auth.isUser || auth.isStaff;
    final isManager = auth.isEventManager;
    final isAdmin = auth.isAdmin;
    final isStaff = auth.isStaff;
    final age = user['age'] as int? ?? 0;
    final showStrikes = auth.isUser||auth.isStaff;
    final strikeCount = (user['attendanceStrikeCount'] as int?) ?? 0; // 0..3
    final isSuspended = (user['isSuspended'] as bool?) ?? false;
    final isGuest = !(isAdmin || isManager || isStaff || isUser);

    final first = (user['firstName'] ?? '').toString().trim();
    final last = (user['lastName'] ?? '').toString().trim();
    final handle = (user['userName'] ?? '').toString().trim();
    final hasName = first.isNotEmpty || last.isNotEmpty;
    final displayName = hasName ? ('$first $last').trim() : 'Guest';

    // Determine role labels
    String roleLabel;
    if (isAdmin) {
      roleLabel = 'Administrator';
    } else if (isManager) {
      roleLabel = 'Event Manager';
    } else if (isStaff) {
      roleLabel = 'Staff';
    } else if (isUser) {
      roleLabel = 'Member';
    } else {
      roleLabel = 'Guest Account';
    }

    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 24),
            Center(
              child: Text(
                "Profile",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'WinnerSans',
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // HEADER CARD
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Name "Guest"
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  // Username (only for signed-in users with a handle)
                  if (!isGuest && handle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '@$handle',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ] else if (isGuest) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Not signed in',
                      style: TextStyle(color: Colors.black45),
                    ),
                  ],

                  const SizedBox(height: 8),
                  Text(
                    roleLabel,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  // a gentle hint for guests
                  if (isGuest) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Limited access — sign in for full features',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ),
                  ],

                  // Attendance Strikes only for signed-in 'users'
                  if (showStrikes) ...[
                    const SizedBox(height: 12),
                    _StrikesBanner(
                      strikeCount: strikeCount.clamp(0, 3),
                      isSuspended: isSuspended,
                      onInfoTap: () => _showStrikesInfo(context),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // MENU
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if(!isGuest)...[
                    _OptionTile(
                      icon: Icons.lock,
                      label: "Account & Security",
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccountSecurityView(),
                            ),
                          ),
                    ),
                  ],
                  if (!isGuest) ...[
                    _OptionTile(
                      icon: Icons.notifications,
                      label: "Notifications",
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsView(),
                            ),
                          ),
                    ),
                  ],
                  if (isUser && age >= 16 || isStaff && age >= 16) ...[
                    _OptionTile(
                      icon: Icons.child_care,
                      label: "My Children",
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageChildrenView(),
                            ),
                          ),
                    ),
                  ],
                  if (isSuspended && isUser || isSuspended && isStaff) ...[
                    _OptionTile(
                      icon: Icons.gavel,
                      label: "Appeal Ban",
                      onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const BanAppealView())),
                    ),
                  ],
                  if (isAdmin || isManager) ...[
                    _OptionTile(
                      icon: Icons.person_2_outlined,
                      label: "View Users",
                      onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const ManageUsersView())),
                    ),
                  ],
                  if (isAdmin || isManager) ...[
                    _OptionTile(
                      icon: Icons.block,
                      label: "Ban Management",
                      onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const BannedUsersView())),
                    ),
                  ],

                  if (isManager || isAdmin) ...[
                    _OptionTile(
                      icon: Icons.event,
                      label: "Manage My Events",
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageEventsView(),
                            ),
                          ),
                    ),
                  ],
                  if (isAdmin) ...[
                    _OptionTile(
                      icon: Icons.history,
                      label: "Events History",
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccountSecurityView(),
                            ),
                            // MaterialPageRoute(builder: (_) => const EventsHistoryView()),
                          ),
                    ),
                  ],
                  if (isAdmin || isManager) ...[
                    _OptionTile(
                      icon: Icons.admin_panel_settings,
                      label: "Roles Management",
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChangeUserRoleView(),
                            ),
                          ),
                    ),
                  ],
                  if (isAdmin) ...[
                    _OptionTile(
                      icon: Icons.location_on,
                      label: "Location Management",
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageLocationsView(),
                            ),
                          ),
                    ),
                  ],
                  const Divider(
                    color: Colors.white30,
                    indent: 24,
                    endIndent: 24,
                  ),
                  _OptionTile(
                    icon: Icons.info,
                    label: "About Corps",
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutCorpsView(),
                          ),
                        ),
                  ),
                  _OptionTile(
                    icon: Icons.policy,
                    label: "Policies",
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PoliciesView(),
                          ),
                        ),
                  ),
                  _OptionTile(
                    icon: Icons.support_agent,
                    label: "Support & Feedback",
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SupportAndFeedbackView(),
                          ),
                        ),
                  ),
                  const Divider(
                    color: Colors.white30,
                    indent: 24,
                    endIndent: 24,
                  ),
                  // const SizedBox(height: 16),
                  _OptionTile(
                    icon: Icons.logout,
                    label: "Log Out",
                    onTap: () => _confirmLogout(context),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showStrikesInfo(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Attendance Strikes',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "• A strike is issued when you don’t attend a booked event.\n"
              "• If multiple children are booked for the same event and none attend, it counts as ONE strike (per event).\n"
              "• 3 strikes = a 90-day suspension from making bookings.",
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
    );
  }

  void _confirmLogout(BuildContext context) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => const _ConfirmLogoutDialog(),
        ) ??
        false;
    if (!ok) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/landing');
  }
}

class _StrikesBanner extends StatelessWidget {
  final int strikeCount; // 0..3
  final bool isSuspended;
  final VoidCallback onInfoTap;

  const _StrikesBanner({
    required this.strikeCount,
    required this.isSuspended,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final flags = List.generate(
      3,
      (i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          Icons.flag,
          size: 22,
          color: i < strikeCount ? Colors.redAccent : Colors.black26,
        ),
      ),
    );

    final subtitle = switch (strikeCount) {
      0 => 'No attendance strikes',
      1 => '1 of 3 strikes',
      2 => '2 of 3 strikes',
      _ => '3 of 3 strikes',
    };

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...flags,
            const SizedBox(width: 8),
            InkWell(
              onTap: onInfoTap,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Colors.black45,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        if (isSuspended) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE), // light red
              border: Border.all(color: Colors.redAccent),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 16, color: Colors.redAccent),
                SizedBox(width: 6),
                Text(
                  'Bookings temporarily suspended',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A single tappable row
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext c) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white30),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}

/// Confirm Log Out
class _ConfirmLogoutDialog extends StatelessWidget {
  const _ConfirmLogoutDialog();

  @override
  Widget build(BuildContext c) {
    return AlertDialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Log Out?", style: TextStyle(color: Colors.white)),
      content: const Text(
        "Are you sure you want to log out?",
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text(
            "LOG OUT",
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}
