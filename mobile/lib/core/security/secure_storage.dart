import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyUserEmail = 'user_email';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
    String? email,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    await _storage.write(key: _keyUserId, value: userId);
    if (email != null) {
      await _storage.write(key: _keyUserEmail, value: email);
    }
  }

  Future<void> updateAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  Future<String?> getAccessToken() async => await _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() async => await _storage.read(key: _keyRefreshToken);
  Future<String?> getUserId() async => await _storage.read(key: _keyUserId);
  Future<String?> getUserEmail() async => await _storage.read(key: _keyUserEmail);

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
