import 'dart:async';
import 'package:corpsapp/widgets/button.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../services/token_service.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';

class LandingView extends StatefulWidget {
  const LandingView({super.key});

  @override
  State<LandingView> createState() => _LandingViewState();
}

class _LandingViewState extends State<LandingView> with WidgetsBindingObserver {
  bool _loading = true;
  late VoidCallback _connListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Delay token check until after first frame so context.read works
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForToken();
      _subscribeToConnectivity();
    });

    _setupFirebaseMessaging();
  }

  void _subscribeToConnectivity() {
    // Listen for connectivity changes
    final connProvider = Provider.of<ConnectivityProvider>(context, listen: false);
    _connListener = () {
      // When we go from offline → online and we're not already loading,
      // retry the token check so we can auto‑login.
      if (!connProvider.isOffline && !_loading) {
        _attemptAutoLogin();
      }
    };
    connProvider.addListener(_connListener);
  }

  Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    print('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((msg) {
      if (msg.notification != null) {
        print('📬 Foreground notification: ${msg.notification!.title}');
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      print('📦 App opened from notification: ${msg.data}');
    });
  }

  Future<void> _attemptAutoLogin() async {
    setState(() => _loading = true);
    await _checkForToken();
  }

  Future<void> _checkForToken() async {
    final refreshToken = await TokenService.getRefreshToken();
    final offline      = context.read<ConnectivityProvider>().isOffline;

    if (refreshToken != null &&
        !JwtDecoder.isExpired(refreshToken) &&
        !offline
    ) {
      // valid token & online → load user + navigate
      final authProvider = context.read<AuthProvider>();
      await authProvider.loadUser();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
      return;
    }

    // either no token, expired, or offline → show landing buttons
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up our connectivity listener
    Provider.of<ConnectivityProvider>(context, listen: false)
        .removeListener(_connListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Image.asset(
                    'assets/logo/logo_transparent_1024px.png',
                    height: 280,
                  ),
                ),
              ),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        key: ValueKey('loading'),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Button(
                            label: 'LOGIN',
                            onPressed: () =>
                                Navigator.pushNamed(context, '/login'),
                          ),
                          const SizedBox(height: 12),
                          Button(
                            label: 'REGISTER',
                            onPressed: () =>
                                Navigator.pushNamed(context, '/register'),
                            buttonColor: Colors.white,
                            textColor: const Color(0xFF121212),
                          ),
                          const SizedBox(height: 32),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/dashboard'),
                            child: const Text(
                              'CONTINUE AS GUEST',
                              style: TextStyle(
                                fontFamily: 'WinnerSans',
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
