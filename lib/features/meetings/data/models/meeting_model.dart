import '../../domain/entities/meeting_entity.dart';

class MeetingModel extends MeetingEntity {
  const MeetingModel({
    required super.id,
    required super.title,
    required super.startAt,
    super.creatorId,
    super.creatorName,
    super.status = 'Scheduled',
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    // Support both 'id' and 'meetingId' from different endpoints
    final id = (json['id'] ?? json['meetingId'] ?? '') as String;
    final rawDate =
        (json['scheduledAt'] ?? json['startAt'] ?? json['startTime'] ?? '') as String;
    return MeetingModel(
      id: id,
      title: json['title'] as String? ?? 'Untitled Meeting',
      startAt: DateTime.tryParse(rawDate) ?? DateTime.now(),
      creatorId: json['creatorId'] as String? ?? '',
      creatorName: json['creatorName'] as String? ?? '',
      status: json['status'] as String? ?? 'Scheduled',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startAt': startAt.toIso8601String(),
      'creatorId': creatorId,
      'creatorName': creatorName,
      'status': status,
    };
  }
}
