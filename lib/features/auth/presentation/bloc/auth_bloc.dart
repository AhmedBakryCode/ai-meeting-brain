import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/models/user_model.dart';
import '../../../../core/notifications/notification_hub_service.dart';
import 'dart:async';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final UserModel user;
  AuthSuccess(this.user);
}

class AuthFailure extends AuthState {
  final String error;
  AuthFailure(this.error);
}

class AuthRegisterSuccess extends AuthState {}

abstract class AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested(this.email, this.password);
}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
  });
}

class AuthCheckRequested extends AuthEvent {}

class AuthLogoutRequested extends AuthEvent {}

class _TokenRefreshRequested extends AuthEvent {}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;
  final AuthLocalDataSource _localDataSource;
  final NotificationHubService _notificationHubService;
  Timer? _refreshTimer;

  AuthBloc({
    required AuthRepository repository,
    required AuthLocalDataSource localDataSource,
    required NotificationHubService notificationHubService,
  }) : _repository = repository,
       _localDataSource = localDataSource,
       _notificationHubService = notificationHubService,
       super(AuthInitial()) {
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthCheckRequested>(_onCheck);
    on<AuthLogoutRequested>(_onLogout);
    on<_TokenRefreshRequested>(_onTokenRefresh);
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _repository.login(event.email, event.password);
      _scheduleRefresh();
      _notificationHubService.connect();
      emit(AuthSuccess(response.user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _repository.register(
        name: event.name,
        email: event.email,
        password: event.password,
      );
      // User requested to navigate to login after register, so we can emit a specific state
      emit(AuthRegisterSuccess());
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onCheck(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (_localDataSource.isAuthenticated()) {
      emit(AuthLoading());
      try {
        final accessToken = _localDataSource.getAccessToken()!;
        final refreshToken = _localDataSource.getRefreshToken()!;
        final response = await _repository.refresh(accessToken, refreshToken);
        _scheduleRefresh();
        _notificationHubService.connect();
        emit(AuthSuccess(response.user));
      } catch (e) {
        await _localDataSource.clearTokens();
        _notificationHubService.disconnect();
        emit(AuthFailure("Session expired. Please login again."));
      }
    } else {
      emit(AuthInitial());
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repository.logout();
    } catch (_) {
      // Even if API logout fails, clear local tokens
    }
    await _localDataSource.clearTokens();
    await _localDataSource.clearUser();
    _refreshTimer?.cancel();
    _notificationHubService.disconnect();
    emit(AuthInitial());
  }

  Future<void> _onTokenRefresh(
    _TokenRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (_localDataSource.isAuthenticated()) {
      try {
        final accessToken = _localDataSource.getAccessToken()!;
        final refreshToken = _localDataSource.getRefreshToken()!;
        await _repository.refresh(accessToken, refreshToken);
        _scheduleRefresh();
      } catch (e) {
        // If refresh fails, sign out
        await _localDataSource.clearTokens();
        emit(AuthFailure("Session expired. Please login again."));
      }
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    // Refresh every 2 hours
    _refreshTimer = Timer(const Duration(hours: 2), () {
      add(_TokenRefreshRequested());
    });
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }
}
