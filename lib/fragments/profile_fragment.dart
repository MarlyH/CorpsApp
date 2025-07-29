// lib/views/profile_fragment.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../views/account_security_view.dart';
import '../views/notifications_view.dart';
import '../views/manage_children_view.dart';
import '../views/manage_events_view.dart';
import '../views/events_history_view.dart';
import '../views/change_user_role_view.dart';
import '../views/manage_locations_view.dart';
import '../views/about_corps_view.dart';
import '../views/policies_view.dart';
import '../views/support_and_feedback_view.dart';

class ProfileFragment extends StatelessWidget {
  const ProfileFragment({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userProfile ?? {};
    final isUser = auth.isUser || auth.isStaff;
    final isManager = auth.isEventManager;
    final isAdmin = auth.isAdmin;
    final age = user['age'] as int? ?? 0;

    // Determine role label
    String roleLabel;
    if (isAdmin) {
      roleLabel = "Admin";
    } else if (isManager)
      roleLabel = "Event Manager";
    else
      roleLabel = "User";

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

           // ─── HEADER CARD ───────────────────────────────────────
            Container(
              // make it as wide as possible
              width: double.infinity,
              // optional: add horizontal margin if you don’t want it flush with the screen
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // left‑align the text
                children: [
                  Text(
                    "${user['firstName'] ?? ''} ${user['lastName'] ?? ''}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "@${user['userName'] ?? ''}",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    roleLabel,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── MENU ───────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
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

                  if (isUser && age >= 16) ...[
                    _OptionTile(
                      icon: Icons.child_care,
                      label: "My Children",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManageChildrenView()),
                      ),
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
                    ////////////////////////////////////////////////////////
                    ///
                    ///this needs to be adjusted when logic is created for
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

                  if (isAdmin) ...[
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

                  const SizedBox(height: 16),

                  // ─── LOG OUT ─────────────────────────────────────────
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
