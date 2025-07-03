import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../fragments/home_fragment.dart';
import '../fragments/profile_fragment.dart';
import '../fragments/tickets_fragment.dart';
import '../fragments/qr_scan_fragment.dart';
import '../views/create_event_view.dart';
import '../views/change_user_role_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final PageController _pageController;
  late final AnimationController _menuCtl;
  double _scrollAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _menuCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _menuCtl.dispose();
    super.dispose();
  }

  bool get _isMenuOpen => _menuCtl.value > 0;

  Future<bool> _handleBack() async {
    if (_isMenuOpen) {
      _menuCtl.reverse();
      return false;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('EXIT APP',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content:
            const Text('Do you want to exit the app?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child:
                  const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child:
                  const Text('EXIT', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (exit == true) SystemNavigator.pop();
    return Future.value(false);
  }

  bool _hasRole(String role) {
    final roles =
        context.read<AuthProvider>().userProfile?['roles'] as List<dynamic>? ?? [];
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

    final pages = _buildPages(canAccessTickets);
    final navItems = _buildNavItems(canAccessTickets);

    // Pre‐compute geometry
    final screenW = MediaQuery.of(context).size.width;
    final radius = screenW / 3;
    final diameter = radius * 2;
    final midY = MediaQuery.of(context).size.height / 2 - radius;

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.black,
        body: PageView(
          controller: _pageController,
          onPageChanged: (i) => setState(() => _selectedIndex = i),
          children: pages,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: BottomNavigationBar(
            backgroundColor: Colors.black,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (i) {
              setState(() => _selectedIndex = i);
              _pageController.animateToPage(i,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut);
            },
            items: navItems,
          ),
        ),
        floatingActionButton: canScanQR
            ? RadialMenu(
                menuCtl: _menuCtl,
                scrollAngle: _scrollAngle,
                onScrollAngleChanged: (v) => setState(() => _scrollAngle = v),
                radius: radius,
                diameter: diameter,
                midY: midY,
                tools: _buildTools(canCreateEvent),
              )
            : null,
        floatingActionButtonLocation: canScanQR
            ? FloatingActionButtonLocation.centerDocked
            : null,
      ),
    );
  }

  List<Widget> _buildPages(bool canAccessTickets) {
    return [
      const HomeFragment(),
      if (canAccessTickets) const TicketsFragment(),
      const ProfileFragment(),
    ];
  }

  List<BottomNavigationBarItem> _buildNavItems(bool canAccessTickets) {
    final items = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
    ];
    if (canAccessTickets) {
      items.add(const BottomNavigationBarItem(
          icon: Icon(Icons.confirmation_number), label: 'TICKETS'));
    }
    items.add(const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE'));
    return items;
  }

  List<_ToolButton> _buildTools(bool canCreateEvent) {
    if (!canCreateEvent) return [];
    return [
      _ToolButton(
        icon: Icons.add,
        label: 'Add Event',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateEventView()),
        ),
      ),
      _ToolButton(
        icon: Icons.settings,
        label: 'Settings',
        onTap: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings coming soon'))),
      ),
      _ToolButton(
        icon: Icons.people,
        label: 'Roles',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChangeUserRoleView()),
        ),
      ),
      _ToolButton(
        icon: Icons.query_stats,
        label: 'Reports',
        onTap: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Reports coming soon'))),
      ),
    ];
  }
}

/// The radial menu, extracted out of the main build for clarity.
class RadialMenu extends StatelessWidget {
  final AnimationController menuCtl;
  final double scrollAngle;
  final ValueChanged<double> onScrollAngleChanged;
  final double radius;
  final double diameter;
  final double midY;
  final List<_ToolButton> tools;

  const RadialMenu({
    required this.menuCtl,
    required this.scrollAngle,
    required this.onScrollAngleChanged,
    required this.radius,
    required this.diameter,
    required this.midY,
    required this.tools,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      // QR FAB
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 55),
          child: FloatingActionButton(
            heroTag: 'scanQR',
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const QrScanFragment())),
            child: const Icon(Icons.qr_code_scanner),
          ),
        ),
      ),

      // Radial tools
      AnimatedBuilder(
        animation: menuCtl,
        builder: (_, __) {
          final openPct = menuCtl.value;
          if (openPct == 0) return const SizedBox.shrink();
          final rightShift = radius * (openPct - 2);

          return Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => menuCtl.reverse(),
              child: Stack(children: [
                Positioned(
                  right: rightShift,
                  top: midY,
                  width: diameter,
                  height: diameter,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {}, // consume taps inside wheel
                    onVerticalDragUpdate: (d) {
                      final step = math.pi / (tools.length + 1);
                      final maxScroll = step * (tools.length - 1);
                      final minScroll = -maxScroll;
                      final newAngle = (scrollAngle + d.delta.dy * 0.01)
                          .clamp(minScroll, maxScroll);
                      onScrollAngleChanged(newAngle);
                    },
                    child: CustomPaint(
                      size: Size(diameter, diameter),
                      painter: _SemiCirclePainter(
                          backgroundColor: Colors.black, arcColor: Colors.white),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < tools.length; i++)
                            _buildTool(tools[i], i, tools.length)
                        ],
                      ),
                    ),
                  ),
                )
              ]),
            ),
          );
        },
      ),

      // Toggle FAB
      Positioned(
        bottom: 55,
        right: 16,
        child: FloatingActionButton(
          heroTag: 'toggle',
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          onPressed: () =>
              menuCtl.isCompleted ? menuCtl.reverse() : menuCtl.forward(),
          child: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: menuCtl),
        ),
      ),
    ]);
  }

  Widget _buildTool(_ToolButton tool, int idx, int total) {
    final base = math.pi / 2;
    final step = math.pi / (total + 1);
    final angle = base + (idx + 1) * step + scrollAngle;
    final x = radius + radius * math.cos(angle);
    final y = radius + radius * math.sin(angle);

    if (!x.isFinite || !y.isFinite) return const SizedBox.shrink();
    return Positioned(
      left: x - 24,
      top: y - 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: tool.label,
            mini: true,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            onPressed: tool.onTap,
            child: Icon(tool.icon, size: 20),
          ),
          const SizedBox(height: 4),
          Text(tool.label,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }
}

class _SemiCirclePainter extends CustomPainter {
  final Color backgroundColor;
  final Color arcColor;
  const _SemiCirclePainter({
    this.backgroundColor = Colors.black,
    this.arcColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2, cx = r, cy = r;
    final bgPaint = Paint()..color = backgroundColor..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    final arcPaint = Paint()..color = arcColor;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final path = Path()
      ..moveTo(cx, 0)
      ..arcTo(rect, -math.pi/2, math.pi, false)
      ..close();
    canvas.drawPath(path, arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ToolButton {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
