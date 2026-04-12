import 'package:hive_flutter/hive_flutter.dart';

abstract class AuthLocalDataSource {
  Future<void> saveTokens({required String accessToken, required String refreshToken, required String expiry});
  Future<void> clearTokens();
  String? getAccessToken();
  String? getRefreshToken();
  String? getAccessTokenExpiry();
  bool isAuthenticated();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const String boxName = 'auth_box';
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String expiryKey = 'access_token_expiry';

  Box<dynamic> get _box => Hive.box(boxName);

  static Future<void> init() async {
    await Hive.openBox(boxName);
  }

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken, required String expiry}) async {
    await _box.put(accessTokenKey, accessToken);
    await _box.put(refreshTokenKey, refreshToken);
    await _box.put(expiryKey, expiry);
  }

  @override
  Future<void> clearTokens() async {
    await _box.delete(accessTokenKey);
    await _box.delete(refreshTokenKey);
    await _box.delete(expiryKey);
  }

  @override
  String? getAccessToken() => _box.get(accessTokenKey) as String?;

  @override
  String? getRefreshToken() => _box.get(refreshTokenKey) as String?;

  @override
  String? getAccessTokenExpiry() => _box.get(expiryKey) as String?;

  @override
  bool isAuthenticated() {
    final token = getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
