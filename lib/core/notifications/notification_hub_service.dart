import 'dart:convert';
import '../network/signalr_service.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import 'notification_service.dart';
import '../network/api_constants.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationHubService {
  NotificationHubService({
    required SignalRService signalRService,
    required AuthLocalDataSource authLocalDataSource,
    required NotificationService notificationService,
  })  : _signalRService = signalRService,
        _authLocalDataSource = authLocalDataSource,
        _notificationService = notificationService;

  final SignalRService _signalRService;
  final AuthLocalDataSource _authLocalDataSource;
  final NotificationService _notificationService;

  Future<void> connect() async {
    final token = _authLocalDataSource.getAccessToken();
    if (token == null || token.isEmpty) return;

    final url = '${ApiConstants.notificationHubUrl}?access_token=$token';

    try {
      await _signalRService.connect(url, accessToken: token);

      _signalRService.on('ReceiveNotification', (args) {
        if (args != null && args.isNotEmpty && args[0] is Map<String, dynamic>) {
          final data = args[0] as Map<String, dynamic>;
          final title = data['title'] as String? ?? 'Notification';
          final message = data['message'] as String? ?? '';
          
          // Show foreground notification
          _notificationService.showForegroundNotification(
            RemoteMessage(
              notification: RemoteNotification(
                title: title,
                body: message,
              ),
              data: data,
            ),
          );
        }
      });
    } catch (e) {
      // Handle connection error
    }
  }

  Future<void> disconnect() async {
    try {
      await _signalRService.disconnect();
    } catch (_) {}
  }
}
