import '../../../../core/network/base_api_service.dart';

abstract class TasksRemoteDataSource {
  Future<List<dynamic>> fetchTasks();
  Future<Map<String, dynamic>> fetchMeetingTasks(String meetingId);
  Future<void> updateTaskStatus(String meetingId, String taskId, String status);
}

class TasksRemoteDataSourceImpl implements TasksRemoteDataSource {
  TasksRemoteDataSourceImpl({required BaseApiService apiService}) : _apiService = apiService;

  final BaseApiService _apiService;

  @override
  Future<List<dynamic>> fetchTasks() async {
    final response = await _apiService.get('/tasks');
    return (response.data as List<dynamic>? ?? <dynamic>[]);
  }

  @override
  Future<Map<String, dynamic>> fetchMeetingTasks(String meetingId) async {
    final response = await _apiService.get('/meetings/$meetingId/results/tasks');
    return (response.data as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

  @override
  Future<void> updateTaskStatus(String meetingId, String taskId, String status) async {
    await _apiService.patch(
      '/meetings/$meetingId/results/tasks/$taskId/status',
      data: {'status': status},
    );
  }
}
