import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../services/token_service.dart';
import '../providers/auth_provider.dart';

class LandingView extends StatefulWidget {
  const LandingView({super.key});

  @override
  State<LandingView> createState() => _LandingViewState();
}

class _LandingViewState extends State<LandingView> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isVideoReady = false;
  bool _hasToken = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForToken();
    _initializeVideo();
  }

  Future<void> _checkForToken() async {
    final token = await TokenService.getAccessToken();
    if (token != null) {
      await context.read<AuthProvider>().loadUser();
    }
    setState(() {
      _hasToken = token != null;
      _loading = false;
    });
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.asset("assets/videos/landingvid1.mp4")
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isVideoReady = true);
          _controller
            ?..setLooping(true)
            ..setVolume(0)
            ..play();
        }
      });
  }

  void _disposeVideo() {
    if (_controller?.value.isInitialized ?? false) {
      _controller?.pause();
    }
    _controller?.dispose();
    _controller = null;
    _isVideoReady = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideo();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!(_controller?.value.isInitialized ?? false)) return;
    if (state == AppLifecycleState.paused) {
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.play();
    }
  }

  Future<void> _navigateSafely(String route) async {
    _disposeVideo();
    await Navigator.pushNamed(context, route);
    _initializeVideo();
    _checkForToken();
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    setState(() => _hasToken = false);
  }

  String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) {
      return '*' * name.length + '@' + domain;
    }

    final visibleStart = name.substring(0, 2);
    final visibleEnd = name.length > 4 ? name.substring(name.length - 2) : '';
    final masked = '*' * (name.length - visibleStart.length - visibleEnd.length);

    return '$visibleStart$masked$visibleEnd@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userProfile;
    final email = user?['email'] ?? 'USER';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideoReady && _controller != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            Container(color: Colors.black),

          Container(color: Colors.black.withOpacity(0.5)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'assets/yourcorps_logo_vertical.png',
                    height: 220,
                  ),
                  const SizedBox(height: 120),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: _loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            key: ValueKey('loading'),
                          )
                        : Column(
                            key: ValueKey(_hasToken ? 'loggedIn' : 'loggedOut'),
                            children: _hasToken
                                ? [
                                    // Continue to Dashboard
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Colors.white, width: 4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        onPressed: () => _navigateSafely('/dashboard'),
                                        child: Text(
                                          'CONTINUE AS ${maskEmail(email)}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            letterSpacing: 1.5,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Log Out
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white, width: 4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        onPressed: _logout,
                                        child: const Text(
                                          'LOG OUT',
                                          style: TextStyle(
                                            color: Colors.white,
                                            letterSpacing: 1.5,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]
                                : [
                                    // Login
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white, width: 4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        onPressed: () => _navigateSafely('/login'),
                                        child: const Text(
                                          'LOGIN',
                                          style: TextStyle(
                                            color: Colors.white,
                                            letterSpacing: 1.5,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Register
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white, width: 4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                        onPressed: () => _navigateSafely('/register'),
                                        child: const Text(
                                          'REGISTER',
                                          style: TextStyle(
                                            color: Colors.white,
                                            letterSpacing: 1.5,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Guest Mode
                                    GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Guest mode coming soon'),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'CONTINUE AS GUEST',
                                        style: TextStyle(
                                          color: Colors.white,
                                          decoration: TextDecoration.underline,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                          ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
