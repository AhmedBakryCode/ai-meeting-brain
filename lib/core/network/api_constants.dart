class ApiConstants {
  static const String _serverBase = 'https://aimeetingbrain.runasp.net';
  // static const String _serverBase = 'http://192.168.1.23:5083';
  static const String baseUrl = '$_serverBase/api';
  static const String meetingsHubUrl = '$_serverBase/hubs/meeting';

  // Auth endpoints
  static const String loginUrl = '/auth/login';
  static const String registerUrl = '/auth/register';
  static const String refreshUrl = '/auth/refresh';
  static const String logoutUrl = '/auth/logout';
  static const String usersUrl = '/auth/users';

  // SignalR Hubs — must NOT include /api prefix
  static const String meetingHubUrl = '$_serverBase/hubs/meeting';
  static const String notificationHubUrl = '$_serverBase/hubs/notification';

  // Meetings REST APIs
  static const String meetingsUrl = '/meetings';
  static String startMeetingUrl(String meetingId) =>
      '/meetings/$meetingId/start';
  static String joinMeetingUrl(String meetingId) => '/meetings/$meetingId/join';
  static String leaveMeetingUrl(String meetingId) =>
      '/meetings/$meetingId/leave';
  static String uploadRecordingUrl(String meetingId) =>
      '/meetings/$meetingId/upload-recording-file';
  static String endMeetingUrl(String meetingId) => '/meetings/$meetingId/end';
  static const String iceServersUrl = '/meetings/ice-servers';

  // Notifications REST APIs
  static const String notificationsUrl = '/notifications';
  static const String notificationsUnreadCountUrl =
      '/notifications/unread-count';
  static String markNotificationAsReadUrl(String id) =>
      '/notifications/$id/read';
  static const String markAllNotificationsAsReadUrl = '/notifications/read-all';

  // Profile REST APIs
  static const String profileUrl = '/profile';
  static const String profileUploadImageUrl = '/profile/upload-image';
  static const String profileChangePasswordUrl = '/profile/change-password';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
