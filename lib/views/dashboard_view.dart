import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../fragments/home_fragment.dart';
import '../fragments/profile_fragment.dart';
import '../fragments/tickets_fragment.dart';
import '../fragments/qr_scan_fragment.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.black,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'EXIT APP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        content: const Text(
          'Do you want to exit the app?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('EXIT', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (shouldExit == true) SystemNavigator.pop();
    return Future.value(false);
  }

  bool _hasRole(String role) {
    final roles =
        context.read<AuthProvider>().userProfile?['roles'] as List<dynamic>? ??
            [];
    return roles.contains(role);
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = _hasRole('Staff');
    final isEventManager = _hasRole('Event Manager');
    final isAdmin = _hasRole('Admin');

    final canScanQR = isStaff || isEventManager || isAdmin;
    final canCreateEvent = isEventManager || isAdmin;
    final canAccessTickets = !isEventManager && !isAdmin;

    // Build your fragments & nav-items list
    final tabs = <MapEntry<Widget, BottomNavigationBarItem>>[
      MapEntry(
        const HomeFragment(),
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
      ),
      if (canAccessTickets)
        MapEntry(
          const TicketsFragment(),
          const BottomNavigationBarItem(
              icon: Icon(Icons.confirmation_number), label: 'TICKETS'),
        ),
      MapEntry(
        const ProfileFragment(),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE'),
      ),
    ];

    // Clamp _selectedIndex if needed
    if (_selectedIndex >= tabs.length) _selectedIndex = 0;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.black,

        // PageView for swipe gestures
        body: PageView(
          controller: _pageController,
          onPageChanged: (idx) {
            setState(() => _selectedIndex = idx);
          },
          children: tabs.map((e) => e.key).toList(),
        ),

        bottomNavigationBar: SafeArea(
          top: false,
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.black,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
            ),
            currentIndex: _selectedIndex,
            onTap: (idx) {
              setState(() => _selectedIndex = idx);
              _pageController.animateToPage(
                idx,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            items: tabs.map((e) => e.value).toList(),
          ),
        ),

        floatingActionButton: canScanQR
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 55),
                      child: FloatingActionButton(
                        heroTag: 'scanQR',
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side:
                              const BorderSide(color: Colors.white, width: 2),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const QrScanFragment()),
                        ),
                        child: const Icon(Icons.qr_code_scanner),
                      ),
                    ),
                  ),
                  if (canCreateEvent)
                    Positioned(
                      bottom: 55,
                      right: 16,
                      child: FloatingActionButton(
                        heroTag: 'createEvent',
                        backgroundColor: Colors.grey.shade900,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Create Event coming soon'),
                          backgroundColor: Colors.grey,
                        )),
                        child: const Icon(Icons.add),
                      ),
                    ),
                ],
              )
            : null,
        floatingActionButtonLocation: canScanQR
            ? FloatingActionButtonLocation.centerDocked
            : null,
      ),
    );
  }
}
