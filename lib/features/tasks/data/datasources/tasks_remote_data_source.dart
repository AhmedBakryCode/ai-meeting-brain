import '../../../../core/network/base_api_service.dart';

abstract class TasksRemoteDataSource {
  Future<List<dynamic>> fetchTasks();
}

class TasksRemoteDataSourceImpl implements TasksRemoteDataSource {
  TasksRemoteDataSourceImpl({required BaseApiService apiService}) : _apiService = apiService;

  final BaseApiService _apiService;

  @override
  Future<List<dynamic>> fetchTasks() async {
    final response = await _apiService.get('/tasks');
    return (response.data as List<dynamic>? ?? <dynamic>[]);
  }
}
