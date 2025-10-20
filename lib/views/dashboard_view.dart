import 'dart:io';

import 'package:corpsapp/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../providers/auth_provider.dart';
import '../fragments/home_fragment.dart';
import '../fragments/profile_fragment.dart';
import '../fragments/tickets_fragment.dart';
import '../services/auth_http_client.dart';
import '../widgets/navbar/admin_navbar.dart';
import '../widgets/navbar/guest_navbar.dart';
import '../widgets/navbar/qr_scanner_fab.dart';
import '../widgets/navbar/user_navbar.dart';
//import '../widgets/navbar/staff_navbar.dart';
import '../services/notification_prefs.dart';
import '../widgets/in_app_push.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  // Sizes
  static const double _fabDiameter = 84.0;
  static const double _fabBorder = 8.0; // black border around FAB
  //static const double _bottomPad = 8.0; // extra bottom padding
  static const double _sideGap = 16.0; // extra horizontal gap around FAB

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);

    // don't set up Firebase Messaging if guest user
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

    // Respect user's preference
    final enabled = await NotificationPrefs.getEnabled();
    await messaging.setAutoInitEnabled(enabled);

    // Request permission (safe on Android, needed on iOS)
    await messaging.requestPermission();
    //iOS suppresses notification alerts when the app is open unless you opt in
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );


    // get the FCM token and register it with API -> Azure Notification Hubs
    if (Platform.isAndroid && enabled) {
      final token = await messaging.getToken();
      if (token != null) {
        try {
          await AuthHttpClient.registerDeviceToken(token);
        } catch (e) {
          print('Error registering device token: $e');
        }
      }
    }
    

    // Foreground notifications: only show if enabled
   FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final on = await NotificationPrefs.getEnabled();
    if (!on) return;

    final notif = message.notification;
    if (!mounted || notif == null) return;

    final title = notif.title ?? 'Notification';
    final body  = notif.body  ?? '';

    // NEW: poppable overlay
    // ignore: use_build_context_synchronously
    showInAppPush(context, title: title, body: body);
  });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final on = await NotificationPrefs.getEnabled();
      if (!on) return;
      // Handle deep links if needed
      // print('Notification caused app to open: ${message.data}');
    });
    }

  Future<bool> _onWillPop() async {
    final exit = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'EXIT APP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Do you want to exit the app?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'EXIT',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
    if (exit == true) SystemNavigator.pop();
    return false;
  }

  bool _hasRole(String role) {
    final roles =
        context.read<AuthProvider>().userProfile?['roles'] as List<dynamic>? ??
        [];
    return roles.contains(role);
  }

  void _goTo(int page) {
    setState(() => _selectedIndex = page);
    _pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final isManagerOrAdminOrStaff = _hasRole('Event Manager') || _hasRole('Admin') || _hasRole('Staff');
    // final isStaff = _hasRole('Staff');
    final isGuest = context.watch<AuthProvider>().isGuest;

    final usesCenterDocked = isManagerOrAdminOrStaff; // only admins/managers get the notch layout
    final inset = MediaQuery.of(context).padding.bottom + 52.0;
    final barH = 0;

    // Extra body bottom clearance only when the FAB is center-docked
    final extraFabClearance = usesCenterDocked ? (_fabDiameter / 2) : 0.0;

    // Staff always gets Tickets. Regular users get Tickets. Guests don’t.
    final showTickets = (!isGuest && !isManagerOrAdminOrStaff);
    final fab = QrScanFab(diameter: _fabDiameter, borderWidth: _fabBorder);

    // Pages
    final pages = <Widget>[
      const HomeFragment(),
      if (showTickets) const TicketsFragment(),
      const ProfileFragment(),
    ];

    // Keep index valid if tab count changed (e.g., after login/role load)
    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
      _pageController.jumpToPage(0);
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,

        body: Padding(
          padding: EdgeInsets.only(bottom: barH + inset + extraFabClearance),
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: pages,
          ),
        ),

        // floatingActionButton: (isManagerOrAdmin || isStaff)
        //   ? (isStaff
        //       ? Transform.translate( 
        //           offset: const Offset(-5, 10),
        //           child: fab,
        //         )
        //       : fab)
        //   : null,

        floatingActionButton: isManagerOrAdminOrStaff
          ? Transform.translate(
              offset: const Offset(0, 20), 
              child: fab,
            )
          : null,

        floatingActionButtonLocation: usesCenterDocked
            ? FloatingActionButtonLocation.centerDocked
            : FloatingActionButtonLocation.endFloat,


        bottomNavigationBar: BottomAppBar(
          color: Colors.black,
          //shape: usesCenterDocked ? 0 : null,
          notchMargin: usesCenterDocked ? 0 : 0,
          child: SizedBox(
            height: 0,
            child: _buildBottomNav(
              isManagerOrAdminOrStaff: isManagerOrAdminOrStaff,
              isGuest: isGuest,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav({
    required bool isManagerOrAdminOrStaff,
    required bool isGuest,
    // required bool isStaff,
  }) {
    if (isManagerOrAdminOrStaff) {
      return AdminNavBar(
        selectedIndex: _selectedIndex,
        onTap: _goTo,
        fabDiameter: _fabDiameter,
        fabBorder: _fabBorder,
        sideGap: _sideGap,
      );
    }
    if (isGuest) {
      return GuestNavBar(
        selectedIndex: _selectedIndex,
        onTap: _goTo,
      );
    }
    // if (isStaff) {
    //   return StaffNavBar(
    //     selectedIndex: _selectedIndex,
    //     onTap: _goTo,
    //     fabDiameter: _fabDiameter,
    //     fabBorder: _fabBorder,
    //     sideGap: _sideGap,
    //   );
    // }
    return UserNavBar(
      selectedIndex: _selectedIndex,
      onTap: _goTo,
    );
  }
}