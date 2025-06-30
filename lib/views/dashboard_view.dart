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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('EXIT', style: TextStyle(color: Colors.redAccent)),
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
        extendBody: true,
        backgroundColor: Colors.black,

        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: IndexedStack(
            index: _selectedIndex,
            children: fragments,
          ),
        ),

        bottomNavigationBar: SafeArea(
          top: false,
          child: MediaQuery.removeViewPadding(
            context: context,
            removeBottom: true,
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
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
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'HOME',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.confirmation_number),
                  label: 'TICKETS',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'PROFILE',
                ),
              ],
            ),
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
                          side: const BorderSide(color: Colors.white, width: 2),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const QrScanFragment(),
                            ),
                          );
                        },
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
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Create Event coming soon'),
                              backgroundColor: Colors.grey,
                            ),
                          );
                        },
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
