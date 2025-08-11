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
  static const double _fabBorder   = 16.0;   // black border around FAB
  static const double _bottomPad   = 8.0;   // extra bottom padding
  static const double _sideGap     = 16.0;  // extra horizontal gap around FAB

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
          SnackBar(
            content: Text(body),
            duration: Duration(seconds: 10),
          ),
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
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('EXIT APP',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Do you want to exit the app?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('EXIT',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (exit == true) SystemNavigator.pop();
    return false;
  }

  bool _hasRole(String role) {
    final roles = context
            .read<AuthProvider>()
            .userProfile?['roles'] as List<dynamic>? ??
        [];
    return roles.contains(role);
  }

  void _goTo(int page) {
    setState(() => _selectedIndex = page);
    _pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final isManagerOrAdmin = _hasRole('Event Manager') || _hasRole('Admin');
    final isGuest = context.watch<AuthProvider>().isGuest;

    // Build pages list depending on role
    final pages = <Widget>[
      const HomeFragment(),
      if (!isGuest && !isManagerOrAdmin) const TicketsFragment(),
      const ProfileFragment(),
    ];

    final inset = MediaQuery.of(context).padding.bottom;
    final barH  = kBottomNavigationBarHeight + _bottomPad;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,

        // BODY: padded so content stops above notch
        body: Padding(
          padding: EdgeInsets.only(
            bottom: barH + inset + (_fabDiameter / 2),
          ),
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: pages,
          ),
        ),

        // Display QR scanner FAB only for privileged users
        // Positioned centrally above the bottom navigation bar with a notch
        floatingActionButton: isManagerOrAdmin
            ? QrScanFab(diameter: _fabDiameter, borderWidth: _fabBorder)
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        bottomNavigationBar: BottomAppBar(
          color: Colors.black,
          // Use a notched shape to accommodate the FAB for privileged users
          shape: isManagerOrAdmin ? const CircularNotchedRectangle() : null,
          notchMargin: isManagerOrAdmin ? _fabBorder : 0,
          child: SizedBox(
            height: barH + inset,
            child: Builder(builder: (_) {
              if (isManagerOrAdmin) {
                return AdminNavBar(
                  selectedIndex: _selectedIndex,
                  onTap: _goTo,
                  fabDiameter: _fabDiameter,
                  fabBorder: _fabBorder,
                  sideGap: _sideGap,
                );
              }
              else if (isGuest) {
                return GuestNavBar(
                  selectedIndex: _selectedIndex,
                  onTap: _goTo,
                );
              }
              else {
                return UserNavBar(
                  selectedIndex: _selectedIndex,
                  onTap: _goTo,
                );
              }
            }),
          ),
        ),
      ),
    );
  }
}
