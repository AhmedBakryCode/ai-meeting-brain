import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/profile_bloc.dart';
import '../../features/meetings/data/datasources/meetings_remote_data_source.dart';
import '../../features/meetings/data/datasources/meetings_local_data_source.dart';
import '../../features/meetings/data/repositories/meetings_repository_impl.dart';
import '../../features/meetings/data/services/audio_recording_service.dart';
import '../../features/meetings/data/services/meeting_pdf_export_service.dart';
import '../../features/meetings/data/services/transcript_stream_service.dart';
import '../../features/meetings/domain/repositories/meetings_repository.dart';
import '../../features/meetings/presentation/bloc/meeting_bloc.dart';
import '../../features/notifications/data/datasources/notifications_remote_data_source.dart';
import '../../features/tasks/data/datasources/tasks_remote_data_source.dart';
import '../notifications/notification_service.dart';
import '../network/base_api_service.dart';
import '../network/signalr_service.dart';
import '../presentation/cubit/app_settings_cubit.dart';
import '../sync/sync_manager.dart';

final GetIt sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl
    ..registerLazySingleton<BaseApiService>(() => BaseApiService(authLocalDataSource: sl()))
    ..registerLazySingleton<SignalRService>(SignalRService.new)
    ..registerLazySingleton<AuthLocalDataSource>(AuthLocalDataSourceImpl.new)
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(apiService: sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
      ),
    )
    ..registerLazySingleton<MeetingsRemoteDataSource>(
      () => MeetingsRemoteDataSourceImpl(apiService: sl()),
    )
    ..registerLazySingleton<MeetingsLocalDataSource>(MeetingsLocalDataSourceImpl.new)
    ..registerLazySingleton<MeetingsRepository>(
      () => MeetingsRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
      ),
    )
    ..registerLazySingleton<AudioRecordingService>(AudioRecordingServiceImpl.new)
    ..registerLazySingleton<TranscriptStreamService>(
      () => TranscriptStreamServiceImpl(signalRService: sl()),
    )
    ..registerLazySingleton<MeetingPdfExportService>(MeetingPdfExportService.new)
    ..registerLazySingleton<NotificationService>(NotificationService.new)
    ..registerLazySingleton<SyncManager>(SyncManager.new)
    ..registerLazySingleton<TasksRemoteDataSource>(
      () => TasksRemoteDataSourceImpl(apiService: sl()),
    )
    ..registerLazySingleton<NotificationsRemoteDataSource>(
      () => NotificationsRemoteDataSourceImpl(apiService: sl()),
    )
    ..registerFactory<AppSettingsCubit>(AppSettingsCubit.new)
    ..registerFactory<AuthBloc>(
      () => AuthBloc(
        repository: sl(),
        localDataSource: sl(),
      ),
    )
    ..registerFactory<ProfileBloc>(
      () => ProfileBloc(authRepository: sl()),
    )
    ..registerFactory<MeetingBloc>(
      () => MeetingBloc(
        recordingService: sl(),
        transcriptStreamService: sl(),
      ),
    );
}
