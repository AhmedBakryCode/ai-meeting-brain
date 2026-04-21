import '../../domain/repositories/meetings_repository.dart';
import '../datasources/meetings_local_data_source.dart';
import '../datasources/meetings_remote_data_source.dart';
import '../datasources/meetings_webrtc_data_source.dart';
import '../models/meeting_model.dart';

class MeetingsRepositoryImpl implements MeetingsRepository {
  MeetingsRepositoryImpl({
    required MeetingsRemoteDataSource remoteDataSource,
    required MeetingsLocalDataSource localDataSource,
    required MeetingsWebRTCDataSource webrtcDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _webrtcDataSource = webrtcDataSource;

  final MeetingsRemoteDataSource _remoteDataSource;
  final MeetingsLocalDataSource _localDataSource;
  final MeetingsWebRTCDataSource _webrtcDataSource;

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
  @override
  Future<void> startAudioConnection(Map<String, dynamic> config) async {
    await _webrtcDataSource.initConnection(config);
  }
  @override
  Future<void> deleteMeeting(String meetingId) async {
    await _remoteDataSource.deleteMeeting(meetingId);
  }

  @override
  Future<List<Map<String, dynamic>>> getIceServers() async {
    return _remoteDataSource.getIceServers();
  }

  @override
  Future<Map<String, dynamic>> joinMeeting(String meetingId) async {
    return _remoteDataSource.joinMeeting(meetingId);
  }
}
