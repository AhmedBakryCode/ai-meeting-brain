import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

// EVENTS
abstract class ProfileEvent {
  const ProfileEvent();
}
class FetchProfileEvent extends ProfileEvent {
  const FetchProfileEvent();
}
class UpdateProfileEvent extends ProfileEvent {
  const UpdateProfileEvent(this.name);
  final String name;
}
class UploadAvatarEvent extends ProfileEvent {
  const UploadAvatarEvent(this.filePath);
  final String filePath;
}
class ChangePasswordEvent extends ProfileEvent {
  const ChangePasswordEvent(this.currentPassword, this.newPassword);
  final String currentPassword;
  final String newPassword;
}

// STATES
abstract class ProfileState {
  const ProfileState();
}
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}
class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.user);
  final UserEntity user;
}
class ProfileError extends ProfileState {
  const ProfileError(this.message);
  final String message;
}
class ProfilePasswordChanged extends ProfileState {
  const ProfilePasswordChanged();
}

// BLOC
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const ProfileInitial()) {
    on<FetchProfileEvent>(_onFetchProfile);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<UploadAvatarEvent>(_onUploadAvatar);
    on<ChangePasswordEvent>(_onChangePassword);
  }

  final AuthRepository _authRepository;
  UserEntity? _currentUser;

  Future<void> _onFetchProfile(FetchProfileEvent event, Emitter<ProfileState> emit) async {
    emit(const ProfileLoading());
    try {
      _currentUser = await _authRepository.fetchProfile();
      emit(ProfileLoaded(_currentUser!));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onUpdateProfile(UpdateProfileEvent event, Emitter<ProfileState> emit) async {
    emit(const ProfileLoading());
    try {
      _currentUser = await _authRepository.updateProfile(event.name);
      emit(ProfileLoaded(_currentUser!));
    } catch (e) {
      emit(ProfileError(e.toString()));
      if (_currentUser != null) emit(ProfileLoaded(_currentUser!));
    }
  }

  Future<void> _onUploadAvatar(UploadAvatarEvent event, Emitter<ProfileState> emit) async {
    emit(const ProfileLoading());
    try {
      _currentUser = await _authRepository.uploadAvatar(event.filePath);
      emit(ProfileLoaded(_currentUser!));
    } catch (e) {
      emit(ProfileError(e.toString()));
      if (_currentUser != null) emit(ProfileLoaded(_currentUser!));
    }
  }

  Future<void> _onChangePassword(ChangePasswordEvent event, Emitter<ProfileState> emit) async {
    emit(const ProfileLoading());
    try {
      await _authRepository.changePassword(event.currentPassword, event.newPassword);
      emit(const ProfilePasswordChanged());
      if (_currentUser != null) emit(ProfileLoaded(_currentUser!));
    } catch (e) {
      emit(ProfileError(e.toString()));
      if (_currentUser != null) emit(ProfileLoaded(_currentUser!));
    }
  }
}
