import '../../domain/repositories/tasks_repository.dart';
import '../../domain/entities/meeting_tasks_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../datasources/tasks_remote_data_source.dart';
import '../../data/models/meeting_tasks_model.dart';
import '../../data/models/task_model.dart';
import '../../../meetings/domain/repositories/meetings_repository.dart';
import '../../../meetings/domain/entities/meeting_entity.dart';

class TasksRepositoryImpl implements TasksRepository {
  final TasksRemoteDataSource remoteDataSource;
  final MeetingsRepository meetingsRepository;

  TasksRepositoryImpl({
    required this.remoteDataSource,
    required this.meetingsRepository,
  });

  @override
  Future<List<MeetingTasksEntity>> getAllMeetingsTasks() async {
    // 1. Fetch all meetings
    final paginatedMeetings = await meetingsRepository.getMeetings(page: 1, limit: 100);
    
    // 2. Fetch tasks for each meeting
    final List<MeetingTasksEntity> allTasks = [];
    
    for (final meeting in paginatedMeetings.items) {
      try {
        final tasksData = await remoteDataSource.fetchMeetingTasks(meeting.id);
        final hasTasks = tasksData['tasks'] != null && (tasksData['tasks'] as List).isNotEmpty;
        if (tasksData.isNotEmpty && hasTasks) {
          allTasks.add(MeetingTasksModel.fromJson(tasksData));
        }
      } catch (e) {
        // If getting tasks for one meeting fails, we might still want to continue
        // Maybe log the error
      }
    }
    
    return allTasks;
  }

  @override
  Future<List<MeetingEntity>> getAllMeetings() async {
    final paginatedMeetings = await meetingsRepository.getMeetings(page: 1, limit: 100);
    return paginatedMeetings.items;
  }

  @override
  Future<List<TaskEntity>> getMeetingTasks(String meetingId) async {
    final tasksData = await remoteDataSource.fetchMeetingTasks(meetingId);
    if (tasksData.isNotEmpty && tasksData['tasks'] != null) {
      final tasksList = tasksData['tasks'] as List<dynamic>;
      return tasksList.map((e) => TaskModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Future<void> updateTaskStatus(String meetingId, String taskId, String status) async {
    await remoteDataSource.updateTaskStatus(meetingId, taskId, status);
  }
}
