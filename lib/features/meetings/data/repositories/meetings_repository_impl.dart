import '../../domain/repositories/meetings_repository.dart';
import '../datasources/meetings_local_data_source.dart';
import '../datasources/meetings_remote_data_source.dart';
import '../models/meeting_model.dart';

class MeetingsRepositoryImpl implements MeetingsRepository {
  MeetingsRepositoryImpl({
    required MeetingsRemoteDataSource remoteDataSource,
    required MeetingsLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final MeetingsRemoteDataSource _remoteDataSource;
  final MeetingsLocalDataSource _localDataSource;

  @override
  Future<PaginatedMeetings> getMeetings({int page = 1, int limit = 20}) async {
    try {
      final remote = await _remoteDataSource.fetchMeetings(page: page, limit: limit);
      final models = remote
          .whereType<Map>()
          .map((json) => MeetingModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      if (page == 1) {
        await _localDataSource.cacheMeetings(models);
      }
      return PaginatedMeetings(
        items: models,
        hasMore: models.length >= limit,
      );
    } catch (_) {
      final cached = await _localDataSource.getCachedMeetings();
      return PaginatedMeetings(items: cached, hasMore: false);
    }
  }

  @override
  Future<void> syncPendingData() async {
    // Placeholder for queued write actions sync when internet is restored.
  }
}
