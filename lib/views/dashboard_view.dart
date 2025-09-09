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
import '../widgets/navbar/staff_navbar.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  // Sizes
  static const double _fabDiameter = 64.0;
  static const double _fabBorder = 16.0; // black border around FAB
  static const double _bottomPad = 8.0; // extra bottom padding
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

    // Request permission
    await messaging.requestPermission();

    // get the FCM token and register it with API -> Azure Notification Hubs
    final token = await messaging.getToken();
    if (token != null) {
      try {
        await AuthHttpClient.registerDeviceToken(token);
      } catch (e) {
        print('Error registering device token: $e');
      }
    }

    // handle notifications when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;

      if (notification != null) {
        final title = notification.title ?? 'Notification';
        final body = notification.body ?? '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body), duration: Duration(seconds: 10)),
        );
      }
    });

    // Handle when the app is opened from a notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification caused app to open: ${message.data}');
      // Navigate or update UI based on message.data here
      // Example:
      // Navigator.pushNamed(context, '/someRoute', arguments: message.data);
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
    final inset = MediaQuery.of(context).padding.bottom;
    final barH  = kBottomNavigationBarHeight + _bottomPad;

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

        // floatingActionButton: (isManagerOrAdmin || isStaff)
        //   ? (isStaff
        //       ? Transform.translate( 
        //           offset: const Offset(-5, 10),
        //           child: fab,
        //         )
        //       : fab)
        //   : null,

        floatingActionButton: isManagerOrAdminOrStaff ? fab : null,

        floatingActionButtonLocation: usesCenterDocked
            ? FloatingActionButtonLocation.centerDocked
            : FloatingActionButtonLocation.endFloat,

        bottomNavigationBar: BottomAppBar(
          color: Colors.black,
          shape: usesCenterDocked ? const CircularNotchedRectangle() : null,
          notchMargin: usesCenterDocked ? _fabBorder : 0,
          child: SizedBox(
            height: barH + inset,
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