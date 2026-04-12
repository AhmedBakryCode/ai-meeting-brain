import '../../domain/entities/meeting_entity.dart';

class MeetingModel extends MeetingEntity {
  const MeetingModel({
    required super.id,
    required super.title,
    required super.startAt,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    // Support both 'id' and 'meetingId' from different endpoints
    final id = (json['id'] ?? json['meetingId'] ?? '') as String;
    // Support both 'scheduledAt' (create response) and 'startAt' (list response)
    final rawDate = (json['scheduledAt'] ?? json['startAt'] ?? '') as String;
    return MeetingModel(
      id: id,
      title: json['title'] as String? ?? 'Untitled Meeting',
      startAt: DateTime.tryParse(rawDate) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startAt': startAt.toIso8601String(),
    };
  }
}
