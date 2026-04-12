import 'package:dio/dio.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../core/network/base_api_service.dart';

abstract class MeetingsRemoteDataSource {
  Future<List<dynamic>> fetchMeetings({int page = 1, int limit = 20});
  Future<Map<String, dynamic>> uploadRecording(String meetingId, String filePath);
  Future<Map<String, dynamic>> startMeeting(String meetingId);
  Future<Map<String, dynamic>> endMeeting(String meetingId);
  Future<Map<String, dynamic>> createMeeting({
    required String title,
    required DateTime date,
    List<String> participantIds = const [],
  });
}

class MeetingsRemoteDataSourceImpl implements MeetingsRemoteDataSource {
  MeetingsRemoteDataSourceImpl({required BaseApiService apiService}) : _apiService = apiService;

  final BaseApiService _apiService;

  @override
  Future<List<dynamic>> fetchMeetings({int page = 1, int limit = 20}) async {
    final response = await _apiService.get(
      ApiConstants.meetingsUrl,
      queryParameters: {'page': page, 'limit': limit},
    );
    return (response.data as List<dynamic>? ?? <dynamic>[]);
  }

  @override
  Future<Map<String, dynamic>> uploadRecording(String meetingId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _apiService.post(
      ApiConstants.uploadRecordingUrl(meetingId),
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> startMeeting(String meetingId) async {
    final response = await _apiService.post(ApiConstants.startMeetingUrl(meetingId));
    return (response.data as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> endMeeting(String meetingId) async {
    final response = await _apiService.post(ApiConstants.endMeetingUrl(meetingId));
    return (response.data as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> createMeeting({
    required String title,
    required DateTime date,
    List<String> participantIds = const [],
  }) async {
    final response = await _apiService.post(
      ApiConstants.meetingsUrl,
      data: {
        'title': title,
        'startTime': date.toIso8601String(),
        'participantIds': participantIds,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
