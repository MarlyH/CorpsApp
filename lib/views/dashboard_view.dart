import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../fragments/home_fragment.dart';
import '../fragments/profile_fragment.dart';
import '../fragments/tickets_fragment.dart';
import '../fragments/qr_scan_fragment.dart';
import '../views/create_event_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  static const double _scanDiameter = 56.0;
  static const double _plusDiameter = 48.0;

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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('EXIT APP',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Do you want to exit the app?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('EXIT',
                style: TextStyle(color: Colors.redAccent)),
          ),
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

  @override
  Widget build(BuildContext context) {
    final isStaff = _hasRole('Staff');
    final isEventManager = _hasRole('Event Manager');
    final isAdmin = _hasRole('Admin');

    final canScanQR = isStaff || isEventManager || isAdmin;
    final canPlus = isEventManager || isAdmin;
    final canAccessTickets = !isEventManager && !isAdmin;

    // 1) The pages shown in the PageView
    final pages = <Widget>[
      const HomeFragment(),
      if (canAccessTickets) const TicketsFragment(),
      const ProfileFragment(),
    ];

    // 2) The three nav icons (Home, maybe Tickets, Profile)
    final navItems = <_NavItem>[
      _NavItem(Icons.home, 'Home', 0),
      if (canAccessTickets)
        _NavItem(Icons.confirmation_number, 'Tickets', 1),
      _NavItem(Icons.person, 'Profile', pages.length - 1),
    ];

    // 3) Figure where the scan slot goes
    final totalSlots    = navItems.length + (canScanQR ? 1 : 0);
    final scanSlotIndex = (navItems.length / 2).floor();

    // 4) Measurement
    final w     = MediaQuery.of(context).size.width;
    final inset = MediaQuery.of(context).padding.bottom;
    final barH  = kBottomNavigationBarHeight;
    final halfS = _scanDiameter / 2;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.black,

        // BODY: pages + overlay circles
        body: Stack(children: [
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _selectedIndex = i),
            children: pages,
          ),

          // red “Scan” circle
          if (canScanQR)
            Positioned(
              bottom: inset + barH/2 - halfS,
              left: w * (scanSlotIndex + 0.5) / totalSlots - halfS,
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const QrScanFragment()),
                ),
                child: Container(
                  width: _scanDiameter,
                  height: _scanDiameter,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4)
                    ],
                  ),
                  child: const Icon(Icons.qr_code_scanner,
                      color: Colors.white, size: 32),
                ),
              ),
            ),

          // blue “+” circle
          if (canPlus)
            Positioned(
              bottom: inset + barH + 100, // 8px above nav bar
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CreateEventView()),
                ),
                child: Container(
                  width: _plusDiameter,
                  height: _plusDiameter,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4)
                    ],
                  ),
                  child: const Icon(Icons.add,
                      color: Colors.white, size: 32),
                ),
              ),
            ),
        ]),

        // BOTTOM NAV BAR
        bottomNavigationBar: SafeArea(
          top: false,
          bottom: true,
          child: SizedBox(
            height: barH + inset,
            child: Row(
              children: [
                for (int i = 0; i < navItems.length; i++) ...[
                  // reserve scan slot width
                  if (i == scanSlotIndex && canScanQR)
                    SizedBox(width: _scanDiameter),
                  // evenly expand each button
                  Expanded(child: _buildNavButton(navItems[i])),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(_NavItem item) {
    final selected = _selectedIndex == item.pageIndex;
    final color    = selected ? Colors.blue : Colors.grey;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selectedIndex = item.pageIndex);
        _pageController.animateToPage(
          item.pageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: color),
          const SizedBox(height: 2),
          Text(item.label,
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
class _NavItem {
  final IconData icon;
  final String label;
  final int pageIndex;
  const _NavItem(this.icon, this.label, this.pageIndex);
}
