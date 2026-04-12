class MeetingEntity {
  const MeetingEntity({
    required this.id,
    required this.title,
    required this.startAt,
  });

  final String id;
  final String title;
  final DateTime startAt;
}
