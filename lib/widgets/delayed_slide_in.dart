import 'package:flutter/material.dart';


class DelayedSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const DelayedSlideIn({
    super.key,
    required this.child,
    required this.delay,
  });

  @override
  State<DelayedSlideIn> createState() => _DelayedSlideInState();
}

class _DelayedSlideInState extends State<DelayedSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _offset = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
      ),
    );
  }
}
