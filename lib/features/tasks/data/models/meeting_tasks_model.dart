import '../../domain/entities/meeting_tasks_entity.dart';
import 'task_model.dart';

class MeetingTasksModel extends MeetingTasksEntity {
  const MeetingTasksModel({
    required super.meetingId,
    required super.meetingTitle,
    required super.tasks,
  });

  factory MeetingTasksModel.fromJson(Map<String, dynamic> json) {
    return MeetingTasksModel(
      meetingId: json['meetingId'] as String,
      meetingTitle: json['meetingTitle'] as String,
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
