import '../entities/meeting_tasks_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../../meetings/domain/entities/meeting_entity.dart';

abstract class TasksRepository {
  Future<List<MeetingTasksEntity>> getAllMeetingsTasks();
  Future<List<MeetingEntity>> getAllMeetings();
  Future<List<TaskEntity>> getMeetingTasks(String meetingId);
  Future<void> updateTaskStatus(String meetingId, String taskId, String status);
}
