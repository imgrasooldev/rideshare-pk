import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'models/user.dart';

/// Single source of truth for the session. Blocs never touch the network or
/// storage directly (repository pattern).
class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  /// Returns the dev OTP code when the backend runs in OTP dev mode
  /// (null in production, where the code arrives by SMS).
  Future<String?> requestOtp(String phone) async {
    final res = await _api.post('/auth/otp/request', body: {'phone': phone}, noAuth: true);
    return res['devCode'] as String?;
  }

  Future<User> verifyOtp(String phone, String code) async {
    final res = await _api.post(
      '/auth/otp/verify',
      body: {'phone': phone, 'code': code},
      noAuth: true,
    );
    final user = res['user'] as Map<String, dynamic>;
    await _storage.save(
      accessToken: res['accessToken'] as String,
      refreshToken: res['refreshToken'] as String,
      user: user,
    );
    return User.fromJson(user);
  }

  /// Restores a persisted session; refreshes the profile when possible.
  Future<User?> restoreSession() async {
    final cached = await _storage.user;
    if (cached == null || await _storage.accessToken == null) return null;
    try {
      return User.fromJson(await _api.get('/me'));
    } catch (_) {
      // Offline or expired-and-unrefreshable: fall back to the cached
      // snapshot; the API interceptor clears the session if refresh failed.
      return await _storage.accessToken != null ? User.fromJson(cached) : null;
    }
  }

  Future<User> updateProfile({String? name, String? role, String? gender, String? cnic}) async {
    final res = await _api.patch('/me', body: {
      'name': ?name,
      'role': ?role,
      'gender': ?gender,
      'cnic': ?cnic,
    });
    return User.fromJson(res);
  }

  Future<void> logout() => _storage.clear();
}
