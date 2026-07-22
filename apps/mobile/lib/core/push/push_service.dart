import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../network/api_client.dart';

/// Global messenger so a foreground push can surface a snackbar from anywhere.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Background/terminated messages with a `notification` payload are shown by the
/// OS automatically; this handler exists so data-only messages don't crash.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // No work needed for MVP — the system tray renders notification payloads.
}

/// Registers this device's FCM token with the backend and shows foreground
/// pushes as snackbars. All calls are best-effort and no-op when Firebase
/// isn't initialised (e.g. in tests), so nothing here can break the app.
class PushService {
  PushService(this._api);
  final ApiClient _api;
  bool _wired = false;

  Future<void> register() async {
    if (Firebase.apps.isEmpty) return; // Firebase not initialised (e.g. tests)
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _sendToken(token);
      if (!_wired) {
        _wired = true;
        messaging.onTokenRefresh.listen(_sendToken);
        FirebaseMessaging.onMessage.listen(_showForeground);
      }
    } catch (_) {
      /* best-effort — push is non-critical */
    }
  }

  Future<void> _sendToken(String token) async {
    try {
      await _api.post('/devices', body: {'token': token, 'platform': 'android'});
    } catch (_) {
      /* retried on next refresh / app start */
    }
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final messenger = scaffoldMessengerKey.currentState;
    messenger?.showSnackBar(SnackBar(
      content: Text(n.title != null ? '${n.title}: ${n.body ?? ''}' : (n.body ?? '')),
    ));
  }
}
