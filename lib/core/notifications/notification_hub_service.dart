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

    // Use a clean URL without encoded token for better reconnection support
    final url = ApiConstants.notificationHubUrl;

    try {
      await _signalRService.connect(
        url, 
        accessTokenFactory: () async => _authLocalDataSource.getAccessToken() ?? '',
      );

      _signalRService.on('ReceiveNotification', (args) {
        print('🔔 RAW NOTIFICATION ARGS: $args');
        if (args != null && args.isNotEmpty) {
          Map<String, dynamic>? data;
          
          if (args[0] is Map<String, dynamic>) {
            data = args[0] as Map<String, dynamic>;
          } else if (args[0] is String) {
            try {
              data = jsonDecode(args[0] as String) as Map<String, dynamic>;
            } catch (_) {}
          }

          if (data != null) {
            final title = data['title'] as String? ?? 'Notification';
            final message = data['message'] as String? ?? '';
            
            // Show foreground notification
            _notificationService.showForegroundNotification(
              RemoteMessage(
                notification: RemoteNotification(
                  title: title,
                  body: message,
                ),
                data: data.map((key, value) => MapEntry(key, value?.toString() ?? '')),
              ),
            );
          }
        }
      });
    } catch (e) {
      // Handle connection error
      print('❌ NotificationHubService connection error: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _signalRService.disconnect();
    } catch (_) {}
  }
}
