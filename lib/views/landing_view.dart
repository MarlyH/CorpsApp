import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/token_service.dart';
import '../providers/auth_provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class LandingView extends StatefulWidget {
  const LandingView({super.key});

  @override
  State<LandingView> createState() => _LandingViewState();
}

class _LandingViewState extends State<LandingView> with WidgetsBindingObserver {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForToken();
  }

  Future<void> _checkForToken() async {
    final token = await TokenService.getRefreshToken();

    if (token != null && !JwtDecoder.isExpired(token)) {
      // the refresh token exists and is valid, try to load profile
      final authProvider = context.read<AuthProvider>();
      await authProvider.loadUser();

      if (mounted) {
        // if logged in, immediately take user to the dashboard.
        Navigator.pushReplacementNamed(context, '/dashboard');
        return;
      }
    }

    // token is bad, show landing view
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  /*String maskEmail(String email) {
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
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Container(color: Colors.black.withOpacity(0.5)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'assets/logo/logo_transparent_1024px.png',
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
                            children: [
                                    // LOGIN (blue)
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF4A90E2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () => Navigator.pushNamed(context, '/login'),
                                        child: const Text(
                                          'LOGIN',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // REGISTER (white)
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () => Navigator.pushNamed(context, '/register'),
                                        child: const Text(
                                          'REGISTER',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // CONTINUE AS GUEST
                                    GestureDetector(
                                      onTap: () => Navigator.pushNamed(context, '/dashboard'),
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
