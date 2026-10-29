import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../cache/hive_cache.dart';

class TokenStorage {
  TokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _accessKey, value: accessToken),
        _storage.write(key: _refreshKey, value: refreshToken),
      ]);
    } catch (_) {
      await Future.wait([
        HiveCache.putString(_accessKey, accessToken),
        HiveCache.putString(_refreshKey, refreshToken),
      ]);
    }
  }

  static Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessKey) ??
          HiveCache.getString(_accessKey);
    } catch (_) {
      return HiveCache.getString(_accessKey);
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshKey) ??
          HiveCache.getString(_refreshKey);
    } catch (_) {
      return HiveCache.getString(_refreshKey);
    }
  }

  static Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: _accessKey),
        _storage.delete(key: _refreshKey),
      ]);
    } catch (_) {
      // Some development browsers do not expose WebCrypto storage.
    }
    await Future.wait([
      HiveCache.remove(_accessKey),
      HiveCache.remove(_refreshKey),
    ]);
  }
}
