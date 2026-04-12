import '../../data/models/auth_response_model.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<AuthResponseModel> login(String email, String password);
  Future<AuthResponseModel> register({required String name, required String email, required String password});
  Future<AuthResponseModel> refresh(String accessToken, String refreshToken);

  Future<UserEntity> fetchProfile();
  Future<UserEntity> updateProfile(String name);
  Future<UserEntity> uploadAvatar(String filePath);
  Future<void> changePassword(String currentPassword, String newPassword);
}
