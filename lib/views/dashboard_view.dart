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

  // Sizes
  static const double _fabDiameter = 64.0;
  static const double _fabBorder   = 8.0;   // black border around FAB
  static const double _bottomPad   = 8.0;   // extra bottom padding
  static const double _sideGap     = 16.0;  // extra horizontal gap around FAB

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
    final isManagerOrAdmin =
        _hasRole('Event Manager') || _hasRole('Admin');
    final showScanFAB    = isManagerOrAdmin;
    final showTicketsTab = !showScanFAB;

    // Build pages array
    final pages = <Widget>[
      const HomeFragment(),
      if (showTicketsTab) const TicketsFragment(),
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

        // CENTER-DOCKED SCAN FAB
        floatingActionButton: showScanFAB
            ? SizedBox(
                width: _fabDiameter + _fabBorder * 2,
                height: _fabDiameter + _fabBorder * 2,
                child: FloatingActionButton(
                  backgroundColor: Colors.red,
                  elevation: 4,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QrScanFragment()),
                  ),
                  shape: CircleBorder(
                    side: BorderSide(color: Colors.black, width: _fabBorder),
                  ),
                  child: const Icon(Icons.qr_code_scanner, size: 32),
                ),
              )
            : null,
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerDocked,

        // BOTTOM NAV BAR
        bottomNavigationBar: BottomAppBar(
          color: Colors.black,
          shape: showScanFAB ? const CircularNotchedRectangle() : null,
          notchMargin: showScanFAB ? _fabBorder : 0,
          child: SizedBox(
            height: barH + inset,
            child: showScanFAB
                // Two-item layout with extra gap around center FAB
                ? Row(
                    children: [
                      // HOME
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _goTo(0),
                          behavior: HitTestBehavior.opaque,
                          child: _buildIconLabel(
                            icon: Icons.home,
                            label: 'HOME',
                            isSelected: _selectedIndex == 0,
                          ),
                        ),
                      ),

                      // Spacer: FAB diameter + double border + sideGap
                      SizedBox(
                        width: _fabDiameter + _fabBorder * 2 + _sideGap,
                      ),

                      // PROFILE (page index = 1)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _goTo(1),
                          behavior: HitTestBehavior.opaque,
                          child: _buildIconLabel(
                            icon: Icons.person,
                            label: 'PROFILE',
                            isSelected: _selectedIndex == 1,
                          ),
                        ),
                      ),
                    ],
                  )
                // Three-item layout (Home, Tickets, Profile)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // HOME
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _goTo(0),
                          behavior: HitTestBehavior.opaque,
                          child: _buildIconLabel(
                            icon: Icons.home,
                            label: 'HOME',
                            isSelected: _selectedIndex == 0,
                          ),
                        ),
                      ),
                      // TICKETS (page index = 1)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _goTo(1),
                          behavior: HitTestBehavior.opaque,
                          child: _buildIconLabel(
                            icon: Icons.confirmation_number,
                            label: 'TICKETS',
                            isSelected: _selectedIndex == 1,
                          ),
                        ),
                      ),
                      // PROFILE (page index = 2)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _goTo(2),
                          behavior: HitTestBehavior.opaque,
                          child: _buildIconLabel(
                            icon: Icons.person,
                            label: 'PROFILE',
                            isSelected: _selectedIndex == 2,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconLabel({
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    final color = isSelected ? Colors.white : Colors.grey[600];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
