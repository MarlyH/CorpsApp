import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

const _kReceivePush = 'receive_push_notifications';

class NotificationPrefs {
  static Future<bool> getEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kReceivePush) ?? true; // default ON
  }

  static Future<void> setEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kReceivePush, enabled);
  }

  /// Turn OFF: stop auto-init + delete token (device stops receiving)
  static Future<void> disablePush() async {
    final fm = FirebaseMessaging.instance;
    await fm.setAutoInitEnabled(false);
    try {
      //final token = await fm.getToken();
      // OPTIONAL: if you add an API to unregister tokens, call it here.
      // if (token != null) await AuthHttpClient.unregisterDeviceToken(token);
    } catch (_) {}
    try {
      await fm.deleteToken(); // hard stop
    } catch (_) {}
  }

  /// Turn ON: allow init + ensure permission + get token
  static Future<String?> enablePush() async {
    final fm = FirebaseMessaging.instance;
    await fm.setAutoInitEnabled(true);
    final perm = await fm.requestPermission(); // iOS: prompts if needed
    if (perm.authorizationStatus == AuthorizationStatus.denied) {
      // User refused at OS level; app cannot override.
      return null;
    }
    try {
      final token = await fm.getToken();
      return token;
    } catch (_) {
      return null;
    }
  }
}
