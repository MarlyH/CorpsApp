import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../providers/auth_provider.dart';
import '../fragments/home_hub_fragment.dart';      // NEW home
import '../fragments/events_fragment.dart';       // Old Home → Events
import '../fragments/tickets_fragment.dart';
import '../fragments/profile_fragment.dart';

import '../services/auth_http_client.dart';
import '../services/notification_prefs.dart';
import '../widgets/in_app_push.dart';

import '../widgets/navbar/user_navbar.dart';
import '../widgets/navbar/guest_navbar.dart';
import '../widgets/navbar/admin_navbar.dart';
import '../widgets/navbar/morph_menu_fab.dart';  
import '../views/qr_scan_view.dart';
import '../views/create_event_view.dart'; // NEW morphing FAB

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  // Sizes for docked FAB gap
  static const double _fabDiameter = 64.0;
  static const double _fabBorder = 16.0; // notch margin
  static const double _bottomPad = 8.0;
  static const double _sideGap = 16.0;

  @override
  void initState() {
    super.initState();

    // Default landing to the NEW Home hub
    _selectedIndex = 0;
    _pageController = PageController(initialPage: _selectedIndex);

    // don't set up FCM if guest user
    if (!context.read<AuthProvider>().isGuest) {
      _setupFirebaseMessaging();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    final enabled = await NotificationPrefs.getEnabled();
    await messaging.setAutoInitEnabled(enabled);
    await messaging.requestPermission();
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    if (enabled) {
      final token = await messaging.getToken();
      if (token != null) {
        try {
          await AuthHttpClient.registerDeviceToken(token);
        } catch (e) {
          // ignore
        }
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final on = await NotificationPrefs.getEnabled();
      if (!on) return;

      final notif = message.notification;
      if (!mounted || notif == null) return;

      final title = notif.title ?? 'Notification';
      final body  = notif.body  ?? '';
      // ignore: use_build_context_synchronously
      showInAppPush(context, title: title, body: body);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final on = await NotificationPrefs.getEnabled();
      if (!on) return;
    });
  }

  Future<bool> _onWillPop() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('EXIT APP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Do you want to exit the app?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true),  child: const Text('EXIT',   style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (exit == true) SystemNavigator.pop();
    return false;
  }

  bool _hasRole(String role) {
    final roles = context.read<AuthProvider>().userProfile?['roles'] as List<dynamic>? ?? [];
    return roles.contains(role);
  }

  void _goTo(int page) {
    setState(() => _selectedIndex = page);
    _pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isGuest = auth.isGuest;

    final isAdmin = _hasRole('Admin');
    final isMgr   = _hasRole('Event Manager');
    final isStaff = _hasRole('Staff');
    final isManagerOrAdminOrStaff = isAdmin || isMgr || isStaff;

    // Pages (NEW order):
    // 0: HomeHub, 1: Events (old Home), 2: Tickets (users only), 3: Profile
    final showTickets = (!isGuest && !isManagerOrAdminOrStaff);

    // in DashboardView build() pages list
    final pages = <Widget>[
      HomeHubFragment(
        onSeeAllEvents: () => _goTo(1), // <- jump to Events tab
      ),
      const HomeFragment(), // Events list
      if (showTickets) const TicketsFragment(),
      const ProfileFragment(),
    ];


    // Keep index valid if layout changes
    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
      _pageController.jumpToPage(0);
    }

    final inset = MediaQuery.of(context).padding.bottom;
    final barH  = kBottomNavigationBarHeight + _bottomPad;
    final usesCenterDocked = isManagerOrAdminOrStaff; // show notch only for staff/manager/admin
    final extraFabClearance = usesCenterDocked ? (_fabDiameter / 2) : 0.0;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,

        body: Padding(
          padding: EdgeInsets.only(bottom: barH + inset + extraFabClearance),
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: pages,
          ),
        ),

        // NEW morphing FAB: tap = menu, long press + release = scan
        floatingActionButton: isManagerOrAdminOrStaff
          ? MorphMenuFab(
              diameter: _fabDiameter,
              notchBorder: _fabBorder,
              onScan: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanView()));
              },
              buildMenu: () => _SideMenu(
                canCreateEvent: (isAdmin || isMgr),
                canScan: (isAdmin || isMgr || isStaff),
                onCreateEvent: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateEventView()));
                },
                onScan: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanView()));
                },
                onLogout: () async {
                  await context.read<AuthProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(context, '/landing', (_) => false);
                },
              ),
            )
          : null,

        floatingActionButtonLocation:
            usesCenterDocked ? FloatingActionButtonLocation.centerDocked : FloatingActionButtonLocation.endFloat,

        bottomNavigationBar: BottomAppBar(
          color: Colors.black,
          shape: usesCenterDocked ? const CircularNotchedRectangle() : null,
          notchMargin: usesCenterDocked ? _fabBorder : 0,
          child: SizedBox(
            height: barH + inset,
            child: _buildBottomNav(
              isManagerOrAdminOrStaff: isManagerOrAdminOrStaff,
              isGuest: isGuest,
              showTickets: showTickets,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav({
    required bool isManagerOrAdminOrStaff,
    required bool isGuest,
    required bool showTickets,
  }) {
    if (isManagerOrAdminOrStaff) {
      // Admin/Manager/Staff: HOME (hub) • space for FAB • PROFILE
      return AdminNavBar(
        selectedIndex: _selectedIndex,
        onTap: _goTo,
        fabDiameter: _fabDiameter,
        fabBorder: _fabBorder,
        sideGap: _sideGap,
      );
    }

    if (isGuest) {
      // Guests: HOME (hub) • EVENTS • PROFILE
      return GuestNavBar(
        selectedIndex: _selectedIndex,
        onTap: _goTo,
      );
    }

    // Users: HOME (hub) • EVENTS • BOOKINGS • PROFILE
    return UserNavBar(
      selectedIndex: _selectedIndex,
      onTap: _goTo,
      showTickets: true,
    );
  }
}

/// Slide-in side menu content
class _SideMenu extends StatelessWidget {
  final bool canCreateEvent;
  final bool canScan;
  final VoidCallback onCreateEvent;
  final VoidCallback onScan;
  final Future<void> Function() onLogout;

  const _SideMenu({
    required this.canCreateEvent,
    required this.canScan,
    required this.onCreateEvent,
    required this.onScan,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width.clamp(280.0, 420.0).toDouble();

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo + close
                Row(
                  children: [
                    Image.asset('assets/logo/logo_transparent_1024px.png', height: 62, fit: BoxFit.contain),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Quick Actions', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                if (canScan)
                  _ActionTile(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan QR',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanView()));
                    },
                  ),
                if (canCreateEvent)
                  _ActionTile(
                    icon: Icons.add_circle_outline,
                    label: 'Create Event',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateEventView()));
                    },
                  ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),

                _ActionTile(
                  icon: Icons.logout,
                  label: 'Logout',
                  onTap: () async {
                    Navigator.pop(context);
                    await onLogout();
                  },
                ),

                const Spacer(),
                const Text('More features coming soon…',
                    style: TextStyle(color: Colors.white30, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap; // <-- simple & reliable

  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: Colors.white10,
    );
  }
}

typedef FutureOrVoidCallback = Future<void> Function();
