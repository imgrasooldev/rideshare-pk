import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the session (tokens + user snapshot) across app restarts.
/// shared_preferences works on all targets; swap the impl behind this same
/// interface for flutter_secure_storage on mobile if required later.
class TokenStorage {
  static const _kAccess = 'auth.accessToken';
  static const _kRefresh = 'auth.refreshToken';
  static const _kUser = 'auth.user';

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, accessToken);
    await prefs.setString(_kRefresh, refreshToken);
    await prefs.setString(_kUser, jsonEncode(user));
  }

  Future<String?> get accessToken async =>
      (await SharedPreferences.getInstance()).getString(_kAccess);

  Future<String?> get refreshToken async =>
      (await SharedPreferences.getInstance()).getString(_kRefresh);

  Future<Map<String, dynamic>?> get user async {
    final raw = (await SharedPreferences.getInstance()).getString(_kUser);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUser);
  }
}
