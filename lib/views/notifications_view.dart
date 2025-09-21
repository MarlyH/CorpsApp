// lib/views/notifications_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../providers/auth_provider.dart';
import '../services/auth_http_client.dart';
import '../services/notification_prefs.dart';

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
    _init();
  }

  Future<void> _init() async {
    final enabled = await NotificationPrefs.getEnabled();
    if (!mounted) return;
    setState(() {
      _receivePush = enabled;
      _loading = false;
    });
  }

  Future<void> _onToggle(bool newValue) async {
    setState(() => _loading = true);
    try {
      if (newValue) {
        final token = await NotificationPrefs.enablePush();
        await NotificationPrefs.setEnabled(true);
        if (token != null) {
          try {
            await AuthHttpClient.registerDeviceToken(token);
          } catch (e) {
            // Non-fatal; token exists and can be re-sent later
          }
        } else {
          // Couldn’t get a token; likely permission off at OS level
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications are blocked at OS level. Enable them in Settings to receive alerts.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        // Turn OFF locally and delete token so device stops receiving
        final fm = FirebaseMessaging.instance;
        final token = await fm.getToken();
        await NotificationPrefs.disablePush();
        await NotificationPrefs.setEnabled(false);

        // OPTIONAL: If you add an API to unregister tokens, call it here:
        // if (token != null) {
        //   try { await AuthHttpClient.unregisterDeviceToken(token); } catch (_) {}
        // }
      }

      if (!mounted) return;
      setState(() => _receivePush = newValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newValue
              ? 'Push notifications enabled'
              : 'Push notifications disabled'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Notifications',
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
                  secondary:
                      const Icon(Icons.notifications, color: Colors.white70),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Note: If notifications are turned off at the system level, '
                    'you may need to enable them in Settings for this app.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}