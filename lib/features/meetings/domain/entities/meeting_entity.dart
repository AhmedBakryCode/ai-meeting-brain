class MeetingEntity {
  const MeetingEntity({
    required this.id,
    required this.title,
    required this.startAt,
    this.creatorId = '',
    this.creatorName = '',
    this.status = 'Scheduled',
  });

  final String id;
  final String title;
  final DateTime startAt;
  final String creatorId;
  final String creatorName;
  final String status;
}
