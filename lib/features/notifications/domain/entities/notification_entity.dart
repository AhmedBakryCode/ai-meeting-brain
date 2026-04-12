class NotificationEntity {
  const NotificationEntity({
    required this.id,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String message;
  final DateTime createdAt;
}
