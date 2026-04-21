import 'task_entity.dart';

class MeetingTasksEntity {
  const MeetingTasksEntity({
    required this.meetingId,
    required this.meetingTitle,
    required this.tasks,
  });

  final String meetingId;
  final String meetingTitle;
  final List<TaskEntity> tasks;
}
