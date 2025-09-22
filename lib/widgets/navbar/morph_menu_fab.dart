// widgets/navbar/morph_menu_fab.dart
import 'package:flutter/material.dart';

class MorphMenuFab extends StatefulWidget {
  final double diameter;
  final double notchBorder;
  final VoidCallback onScan;
  final Widget Function() buildMenu;

  const MorphMenuFab({
    super.key,
    required this.diameter,
    required this.notchBorder,
    required this.onScan,
    required this.buildMenu,
  });

  @override
  State<MorphMenuFab> createState() => _MorphMenuFabState();
}

class _MorphMenuFabState extends State<MorphMenuFab> {
  bool _showScan = false;

  Future<void> _openSideMenu() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final offset = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(anim);
        return SlideTransition(position: offset, child: widget.buildMenu());
      },
    );
  }

  void _onLongPressStart(_) => setState(() => _showScan = true);

  void _onLongPressEnd(_) {
    setState(() => _showScan = false);
    widget.onScan(); // navigate to scanner on release
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.diameter + widget.notchBorder * 0,
      height: widget.diameter + widget.notchBorder * 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openSideMenu,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        child: FloatingActionButton(
          heroTag: 'morph_menu_fab',
          backgroundColor: const Color(0xFFD01417),
          elevation: 4,
          onPressed: null, // GestureDetector handles tap/long-press
          shape: const CircleBorder(
            side: BorderSide(color: Colors.black, width: 5),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            transitionBuilder: (c, anim) => FadeTransition(opacity: anim, child: c),
            child: _showScan
                ? const Icon(Icons.qr_code_scanner, key: ValueKey('scan'), size: 32, color: Colors.white)
                : const Icon(Icons.menu, key: ValueKey('menu'), size: 32, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
