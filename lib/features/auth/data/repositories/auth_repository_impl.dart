import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_response_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    final response = await _remoteDataSource.login(email, password);
    await _saveTokens(response);
    return response;
  }

  @override
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _remoteDataSource.register(
      name: name,
      email: email,
      password: password,
    );
  }

  @override
  Future<AuthResponseModel> refresh(
    String accessToken,
    String refreshToken,
  ) async {
    final response = await _remoteDataSource.refresh(accessToken, refreshToken);
    await _saveTokens(response);
    return response;
  }

  @override
  Future<bool> refreshTokens() async {
    final accessToken = _localDataSource.getAccessToken();
    final refreshToken = _localDataSource.getRefreshToken();

    // No stored session — user is not logged in, nothing to refresh
    if (accessToken == null || accessToken.isEmpty ||
        refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _remoteDataSource.refresh(accessToken, refreshToken);
      await _saveTokens(response);
      print('✅ [Auth] Token refreshed successfully on startup.');
      return true;
    } catch (e) {
      // Refresh failed (token expired, network error, etc.) — stay silent
      print('⚠️ [Auth] Token refresh failed on startup: $e');
      return false;
    }
  }

  Future<void> _saveTokens(AuthResponseModel response) async {
    await _localDataSource.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiry: response.accessTokenExpiry.toIso8601String(),
    );
    await _localDataSource.saveUser(response.user);
  }

  @override
  Future<UserEntity> fetchProfile() async {
    return _remoteDataSource.fetchProfile();
  }

  @override
  Future<UserEntity> updateProfile(String name) async {
    return _remoteDataSource.updateProfile(name);
  }

  @override
  Future<UserEntity> uploadAvatar(String filePath) async {
    return _remoteDataSource.uploadAvatar(filePath);
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _remoteDataSource.changePassword(currentPassword, newPassword);
  }

  @override
  Future<void> logout() async {
    try {
      await _remoteDataSource.logout();
    } finally {
      await _localDataSource.clearTokens();
      await _localDataSource.clearUser();
    }
  }
}
