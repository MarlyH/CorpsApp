// lib/views/notifications_view.dart
import 'package:corpsapp/theme/colors.dart';
import 'package:corpsapp/theme/spacing.dart';
import 'package:corpsapp/widgets/app_bar.dart';
import 'package:flutter/material.dart';
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
                'Notifications are blocked at system level. Enable them in Settings to receive alerts.',
              ),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      } else {
        // Turn OFF locally and delete token so device stops receiving
        //final fm = FirebaseMessaging.instance;
        //final token = await fm.getToken();
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
          backgroundColor: AppColors.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileAppBar(title: 'Notifications'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
            padding: AppPadding.screen,
            child: ListView(
              children: [
                SwitchListTile.adaptive(
                  title: const Text(
                    'Receive push notifications',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  value: _receivePush,
                  onChanged: _onToggle,
                  activeColor: AppColors.primaryColor,
                  contentPadding: EdgeInsets.all(0),
                ),
                Text(
                    'Note: If notifications are turned off at the system level, '
                    'you may need to enable them in Settings for this app.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),              
              ],
            ),
          )         
    );
  }
}