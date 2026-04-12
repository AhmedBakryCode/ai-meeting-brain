import '../../../../core/network/base_api_service.dart';
import '../../../../core/network/api_constants.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<dynamic>> fetchNotifications({bool unreadOnly = false});
  Future<int> fetchUnreadCount();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}

class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  NotificationsRemoteDataSourceImpl({required BaseApiService apiService})
      : _apiService = apiService;

  final BaseApiService _apiService;

  @override
  Future<List<dynamic>> fetchNotifications({bool unreadOnly = false}) async {
    final response = await _apiService.get(ApiConstants.notificationsUrl, queryParameters: {'unreadOnly': unreadOnly});
    return (response.data as List<dynamic>? ?? <dynamic>[]);
  }

  @override
  Future<int> fetchUnreadCount() async {
    final response = await _apiService.get(ApiConstants.notificationsUnreadCountUrl);
    return response.data as int;
  }

  @override
  Future<void> markAsRead(String id) async {
    await _apiService.patch(ApiConstants.markNotificationAsReadUrl(id));
  }

  @override
  Future<void> markAllAsRead() async {
    await _apiService.patch(ApiConstants.markAllNotificationsAsReadUrl);
  }
}
