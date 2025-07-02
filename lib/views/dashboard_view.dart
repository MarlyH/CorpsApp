import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../fragments/home_fragment.dart';
import '../fragments/profile_fragment.dart';
import '../fragments/tickets_fragment.dart';
import '../fragments/qr_scan_fragment.dart';
import './change_user_role_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

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

  Future<bool> _onWillPop() async {
    // if menu open, close it first
    if (_menuCtl.value > 0) {
      _menuCtl.reverse();
      return false;
    }
    // otherwise confirm exit
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
            child:
                const Text('EXIT', style: TextStyle(color: Colors.redAccent)),
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

    // Pages & NavItems
    final tabs = <MapEntry<Widget, BottomNavigationBarItem>>[
      MapEntry(const HomeFragment(),
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME')),
      if (canAccessTickets)
        MapEntry(
            const TicketsFragment(),
            const BottomNavigationBarItem(
                icon: Icon(Icons.confirmation_number), label: 'TICKETS')),
      MapEntry(const ProfileFragment(),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE')),
    ];
    if (_selectedIndex >= tabs.length) _selectedIndex = 0;

    // Tools for the radial wheel
    final tools = <_ToolButton>[];
    if (canCreateEvent) {
      tools.addAll([
        _ToolButton(
          icon: Icons.add,
          label: 'Add',
          onTap: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Create Event coming soon'))),
        ),
        _ToolButton(
          icon: Icons.settings,
          label: 'Settings',
          onTap: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Settings coming soon'))),
        ),
        _ToolButton(
          icon: Icons.people_sharp,
          label: 'Roles',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ChangeUserRoleView(),
              ),
            );
          },
        ),
        _ToolButton(
          icon: Icons.query_stats,
          label: 'Reports',
          onTap: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Generate reports coming soon'))),
        ),
      ]);
    }

    // Geometry
    final screenW = MediaQuery.of(context).size.width;
    final radius = screenW / 3; // 1/3 screen width
    final diameter = radius * 2;
    final midY = MediaQuery.of(context).size.height / 2 - radius;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.black,

        // Swipeable pages
        body: PageView(
          controller: _pageController,
          onPageChanged: (i) => setState(() => _selectedIndex = i),
          children: tabs.map((e) => e.key).toList(),
        ),

        // Bottom bar
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
            items: tabs.map((e) => e.value).toList(),
          ),
        ),

        // FABs
        floatingActionButton: canScanQR
            ? Stack(clipBehavior: Clip.none, children: [
                // QR Scanner FAB
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 55),
                    child: FloatingActionButton(
                      heroTag: 'scanQR',
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QrScanFragment()),
                      ),
                      child: const Icon(Icons.qr_code_scanner),
                    ),
                  ),
                ),

                // Radial drawer + outside‐tap detector
                if (tools.isNotEmpty)
                  AnimatedBuilder(
                    animation: _menuCtl,
                    builder: (_, __) {
                      final openPct = _menuCtl.value;
                      if (openPct == 0) return const SizedBox.shrink();

                      final rightShift = radius * (openPct - 2);

                      return Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent, // catch taps only
                          onTap: () => _menuCtl.reverse(),
                          child: Stack(
                            children: [
                              // wheel area
                              Positioned(
                                right: rightShift,
                                top: midY,
                                width: diameter,
                                height: diameter,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () {}, // consume inner taps
                                  onVerticalDragUpdate: (d) => setState(() {
                                    final step = math.pi / (tools.length + 1);
                                    final maxScroll = step * (tools.length - 1);
                                    final minScroll = -maxScroll;
                                    _scrollAngle = (_scrollAngle + d.delta.dy * 0.01)
                                        .clamp(minScroll, maxScroll);
                                  }),
                                  child: CustomPaint(
                                    size: Size(diameter, diameter),
                                    painter: _SemiCirclePainter(
                                      backgroundColor: Colors.black,
                                      arcColor: Colors.white,
                                    ),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        for (var i = 0; i < tools.length; i++)
                                          _buildToolItem(
                                              tools[i], i, tools.length, radius),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // Toggle drawer FAB
                if (tools.isNotEmpty)
                  Positioned(
                    bottom: 55,
                    right: 16,
                    child: FloatingActionButton(
                      heroTag: 'toggle',
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      onPressed: () {
                        _menuCtl.isCompleted ? _menuCtl.reverse() : _menuCtl.forward();
                      },
                      child: AnimatedIcon(
                        icon: AnimatedIcons.menu_close,
                        progress: _menuCtl,
                      ),
                    ),
                  ),
              ])
            : null,
        floatingActionButtonLocation:
            canScanQR ? FloatingActionButtonLocation.centerDocked : null,
      ),
    );
  }

  Widget _buildToolItem(_ToolButton tool, int idx, int total, double r) {
    final base = math.pi / 2;
    final step = math.pi / (total + 1);
    final angle = base + (idx + 1) * step + _scrollAngle;
    final x = r + r * math.cos(angle);
    final y = r + r * math.sin(angle);

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
          Text(
            tool.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SemiCirclePainter extends CustomPainter {
  final Color backgroundColor;
  final Color arcColor;

  _SemiCirclePainter({
    this.backgroundColor = Colors.black,
    this.arcColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);

    // draw full‐circle black background
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r, bgPaint);

    // draw white semi‐circle on top
    final arcPaint = Paint()..color = arcColor;
    final circleRect = Rect.fromCircle(center: center, radius: r);
    final path = Path()
      ..moveTo(r, 0)
      ..arcTo(circleRect, -math.pi / 2, math.pi, false)
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
