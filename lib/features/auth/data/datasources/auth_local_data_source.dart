import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveTokens({required String accessToken, required String refreshToken, required String expiry});
  Future<void> clearTokens();
  String? getAccessToken();
  String? getRefreshToken();
  String? getAccessTokenExpiry();
  bool isAuthenticated();
  Future<void> saveUser(UserModel user);
  UserModel? getUser();
  Future<void> clearUser();
  Set<String> extractUserIdentifiersFromToken(String? token);
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const String boxName = 'auth_box';
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String expiryKey = 'access_token_expiry';
  static const String userKey = 'current_user';

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

  bool isAuthenticated() {
    final token = getAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> saveUser(UserModel user) async {
    await _box.put(userKey, jsonEncode(user.toJson()));
  }

  @override
  UserModel? getUser() {
    final userJson = _box.get(userKey) as String?;
    if (userJson == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearUser() async {
    await _box.delete(userKey);
  }

  @override
  Set<String> extractUserIdentifiersFromToken(String? token) {
    if (token == null || token.isEmpty) return <String>{};
    final parts = token.split('.');
    if (parts.length < 2) return <String>{};

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map<String, dynamic>) return <String>{};

      final values = <String?>[
        payload['sub']?.toString(),
        payload['nameid']?.toString(),
        payload['name']?.toString(),
        payload['unique_name']?.toString(),
        payload['preferred_username']?.toString(),
        payload['email']?.toString(),
        payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']?.toString(),
        payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name']?.toString(),
        payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress']?.toString(),
      ];

      return values
          .whereType<String>()
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }
}
