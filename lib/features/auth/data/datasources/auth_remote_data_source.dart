import 'dart:convert';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/base_api_service.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import 'package:dio/dio.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
  });
  Future<AuthResponseModel> refresh(String accessToken, String refreshToken);
  // Future<void> logout(String refreshToken);

  Future<UserModel> fetchProfile();
  Future<UserModel> updateProfile(String name);
  Future<UserModel> uploadAvatar(String filePath);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<List<UserModel>> fetchUsers();
  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({required BaseApiService apiService})
    : _apiService = apiService;

  final BaseApiService _apiService;

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    final response = await _apiService.post(
      ApiConstants.loginUrl,
      data: {'email': email, 'password': password},
    );
    return AuthResponseModel.fromJson(_parseData(response.data));
  }

  @override
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post(
      ApiConstants.registerUrl,
      data: {'name': name, 'email': email, 'password': password},
    );
    return AuthResponseModel.fromJson(_parseData(response.data));
  }

  @override
  Future<AuthResponseModel> refresh(
    String accessToken,
    String refreshToken,
  ) async {
    final response = await _apiService.post(
      ApiConstants.refreshUrl,
      data: {'accessToken': accessToken, 'refreshToken': refreshToken},
    );
    return AuthResponseModel.fromJson(_parseData(response.data));
  }

  @override
  Future<UserModel> fetchProfile() async {
    final response = await _apiService.get(ApiConstants.profileUrl);
    return UserModel.fromJson(_parseData(response.data));
  }

  @override
  Future<UserModel> updateProfile(String name) async {
    final response = await _apiService.put(
      ApiConstants.profileUrl,
      data: {'name': name},
    );
    return UserModel.fromJson(_parseData(response.data));
  }

  @override
  Future<UserModel> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _apiService.post(
      ApiConstants.profileUploadImageUrl,
      data: formData,
    );
    return UserModel.fromJson(_parseData(response.data));
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _apiService.patch(
      ApiConstants.profileChangePasswordUrl,
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  @override
  Future<List<UserModel>> fetchUsers() async {
    final response = await _apiService.get(ApiConstants.usersUrl);
    final List<dynamic> list = response.data is List ? response.data : [];
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  @override
  Future<void> logout() async {
    await _apiService.post(ApiConstants.logoutUrl);
  }

  Map<String, dynamic> _parseData(dynamic data) {
    if (data is String) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }
}
