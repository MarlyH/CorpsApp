import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/views/login_view.dart';
import 'package:corpsapp/widgets/ProfileLists/admin_list.dart';
import 'package:corpsapp/widgets/ProfileLists/guest_list.dart';
import 'package:corpsapp/widgets/ProfileLists/list_tile.dart';
import 'package:corpsapp/widgets/ProfileLists/manager_list.dart';
import 'package:corpsapp/widgets/ProfileLists/user_list.dart';
import 'package:corpsapp/widgets/alert_dialog.dart';
import 'package:corpsapp/widgets/button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../views/account_security_view.dart';
import '../views/notifications_view.dart';
import '../views/about_corps_view.dart';
import '../views/policies_view.dart';
import '../views/support_and_feedback_view.dart';


class ProfileFragment extends StatelessWidget {
  const ProfileFragment({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userProfile ?? {};
    final isUser = auth.isUser;
    final isManager = auth.isEventManager;
    final isAdmin = auth.isAdmin;
    final isStaff = auth.isStaff;
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
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: AppPadding.screen,
          child:         
            Column(
              children: [
                Center(
                  child: Text(
                    "PROFILE",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'WinnerSans',
                      fontSize: 32,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // HEADER CARD
                Container(
                  width: double.infinity,
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
                          color: AppColors.normalText,
                        ),
                      ),

                      // Username (only for signed-in users with a handle)
                      if (!isGuest && handle.isNotEmpty) ...[
                        Text(
                          '@$handle',
                          style: const TextStyle(color: Color(0xFF646464), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ] else if (isGuest) ...[
                        const Text(
                          'Not signed in',
                          style: TextStyle(color: Color(0xFF646464)),
                        ),
                      ],

                      const SizedBox(height: 8),

                      if (isManager || isAdmin || isStaff) ... [
                        Text(
                          roleLabel,
                          style: const TextStyle(
                            color: AppColors.normalText,
                            fontSize: 12,
                          ),
                        ),
                      ],

                      // Attendance Strikes only for signed-in 'users'
                      if (isUser) ...[
                        const SizedBox(height: 4),
                        if (strikeCount > 0) ... [
                          _StrikesBanner(
                            strikeCount: strikeCount.clamp(0, 3),
                            isSuspended: isSuspended,
                            onInfoTap: () => _showStrikesInfo(context),
                          ),
                        ]                      
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // MENU
                Expanded(
                  child: ListView(
                    children: [
                      if (isGuest) ... [
                        const SizedBox(height: 16),
                        Button(
                          label: 'Sign In', 
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => LoginView()));
                          }
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (!isGuest) ... [
                        CupertinoListSection.insetGrouped(
                          margin: EdgeInsets.fromLTRB(0,16,0,8),
                          backgroundColor: Colors.transparent,
                          children: [
                            OptionTile(
                              icon: Icons.lock,
                              label: "Account",
                              view: AccountSecurityView(),           
                            ),
                            OptionTile(
                              icon: Icons.notifications,
                              label: "Notifications",
                              view: NotificationsView(),
                            ),
                          ],
                        ),
                      ],

                      if (isUser) UserList(age: user['age'] ?? 0, isSuspended: isSuspended),                     
                      if (isManager) ManagerList(),
                      if (isAdmin) AdminList(),
                      if (isGuest) GuestList(),      

                      CupertinoListSection.insetGrouped(
                        margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        backgroundColor: Colors.transparent,
                        children: [
                          OptionTile(
                            icon: Icons.info, 
                            label: 'About Corps', 
                            view: AboutCorpsView()
                          ),

                          OptionTile(
                            icon: Icons.policy, 
                            label: 'Policies', 
                            view: PoliciesView()
                          ),

                          OptionTile(
                            icon: Icons.support_agent, 
                            label: 'Support & Feedback', 
                            view: SupportAndFeedbackView()
                          ),
                        ],
                      ),

                      if (!isGuest) ... [
                        CupertinoListSection.insetGrouped(
                          margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                          backgroundColor: Colors.transparent,
                          children: [
                            OptionTile(
                              icon: Icons.logout,                              
                              label: 'Log Out', 
                              onTap: () => _confirmLogout(context)
                            ),
                          ],
                        ),       
                      ],                                                                                                                                                                                                                                                                                  
                    ],
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }

  static void _showStrikesInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CustomAlertDialog(
        title: 'Attendance Strikes', 
        info: 
          "A strike is issued when you do not attend or cancel an event.\n\n"
          "Strikes are issued per event. e.g. If there were bookings for multiple attendees for the same event and none attend, only one strike will be given.\n\n"
          "Once having three strikes accumulated, the account will be suspended from making bookings for 90 days."
      )       
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
    final auth = context.watch<AuthProvider>();
    final user = auth.userProfile ?? {};
    final suspendedTillRaw = user['suspensionUntil']; 

    final suspendedTill = suspendedTillRaw != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(suspendedTillRaw))
        : null;

    final flags = List.generate(
      3,
      (i) => Icon(
          Icons.flag,
          size: 20,
          color: i < strikeCount ? AppColors.errorColor : AppColors.disabled,
        ),
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...flags,

            const SizedBox(width: 4),

            InkWell(
              onTap: onInfoTap,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.black45,
              ),
            ),
          ],
        ),
        
        if (isSuspended) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              border: Border.all(color: AppColors.errorColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                //const Icon(Icons.block, size: 16, color: AppColors.errorColor),
                const SizedBox(width: 6),
                Text(
                  suspendedTill != null
                      ? 'Bookings suspended until \n$suspendedTill'
                      : 'Bookings Suspended',
                  style: const TextStyle(
                    color: AppColors.errorColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
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
      title: const Text("LOG OUT?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'WinnerSans')),
      content: const Text(
        "Are you sure you want to log out?",
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text(
            "LOG OUT",
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
