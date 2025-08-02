// lib/views/notifications_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  _NotificationsViewState createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  bool _receivePush = false;
  bool _loading     = true;

  @override
  void initState() {
    super.initState();
    // Initialize from provider
    final auth = context.read<AuthProvider>();
    // _receivePush = auth.receivePushNotifications;
    _loading = false;
  }

  Future<void> _onToggle(bool newValue) async {
    setState(() => _loading = true);
    try {
      // Update your provider (and backend if you like)
      // await context.read<AuthProvider>().setReceivePushNotifications(newValue);
      setState(() => _receivePush = newValue);
    } catch (e) {
      // show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Notifications', 
          style: TextStyle(
            fontFamily: 'WinnerSans',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              children: [
                const SizedBox(height: 24),
                SwitchListTile.adaptive(
                  title: const Text(
                    'Receive push notifications',
                    style: TextStyle(color: Colors.white70),
                  ),
                  value: _receivePush,
                  onChanged: _onToggle,
                  activeColor: Colors.blueAccent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.notifications, color: Colors.white70),
                ),
              ],
            ),
    );
  }
}
