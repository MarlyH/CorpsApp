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

  Future<void> _handlePop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Exit App', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Do you want to exit the app?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (shouldExit == true) SystemNavigator.pop();
  }

  bool _hasRole(String role) {
    final roles = context.read<AuthProvider>().userProfile?['roles'] as List<dynamic>? ?? [];
    return roles.contains(role);
  }

  @override
  Widget build(BuildContext context) {
    final isStaff        = _hasRole('Staff');
    final isEventManager = _hasRole('Event Manager');
    final isAdmin        = _hasRole('Admin');

    final canScanQR      = isStaff || isEventManager || isAdmin;
    final canCreateEvent = isEventManager || isAdmin;

    final fragments = <Widget>[
      const HomeFragment(),
      const TicketsFragment(),
      const ProfileFragment(),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        extendBody: true, // so FAB notch floats cleanly
        backgroundColor: Colors.black,

        // main content
        body: IndexedStack(
          index: _selectedIndex,
          children: fragments,
        ),

        // bottom nav
        bottomNavigationBar: MediaQuery.removeViewPadding(
          context: context,
          removeBottom: true, // zero out system nav inset
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            backgroundColor: Colors.black,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.confirmation_number),
                label: 'Tickets',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),

        // FABs
        floatingActionButton: canScanQR
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  // QR‐scan button in center
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: FloatingActionButton(
                        heroTag: 'scanQR',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QrScanFragment(),
                            ),
                          );
                        },
                        backgroundColor: Colors.deepPurple,
                        child: const Icon(Icons.qr_code_scanner),
                      ),
                    ),
                  ),
                  // Create‐event button bottom‐right
                  if (canCreateEvent)
                    Positioned(
                      bottom: 40,
                      right: 16,
                      child: FloatingActionButton(
                        heroTag: 'createEvent',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Create Event coming soon')),
                          );
                        },
                        backgroundColor: Colors.grey.shade700,
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
