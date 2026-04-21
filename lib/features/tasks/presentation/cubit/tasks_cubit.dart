import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../../domain/entities/task_entity.dart';
import '../../../meetings/domain/entities/meeting_entity.dart';

part 'tasks_state.dart';

class TasksCubit extends Cubit<TasksState> {
  final TasksRepository repository;

  TasksCubit({required this.repository}) : super(const TasksState());

  Future<void> fetchMeetings() async {
    safeEmit(state.copyWith(meetingsLoading: true, meetingsError: null));
    try {
      final meetings = await repository.getAllMeetings();
      safeEmit(state.copyWith(meetings: meetings, meetingsLoading: false));
    } catch (e) {
      safeEmit(state.copyWith(meetingsError: e.toString(), meetingsLoading: false));
    }
  }

  Future<void> fetchTasksForMeeting(String meetingId, {bool forceRefetch = false}) async {
    // If already loaded or currently loading, skip unless forceRefetch is true
    if (!forceRefetch && (state.tasksByMeeting.containsKey(meetingId) || state.tasksLoading[meetingId] == true)) {
      return;
    }

    final newLoading = Map<String, bool>.from(state.tasksLoading)..[meetingId] = true;
    safeEmit(state.copyWith(tasksLoading: newLoading));

    try {
      final tasks = await repository.getMeetingTasks(meetingId);
      final newTasks = Map<String, List<TaskEntity>>.from(state.tasksByMeeting)..[meetingId] = tasks;
      
      final newLoadingAfter = Map<String, bool>.from(state.tasksLoading)..[meetingId] = false;
      safeEmit(state.copyWith(tasksByMeeting: newTasks, tasksLoading: newLoadingAfter));
    } catch (e) {
      final newLoadingAfter = Map<String, bool>.from(state.tasksLoading)..[meetingId] = false;
      final newErrors = Map<String, String>.from(state.tasksErrors)..[meetingId] = e.toString();
      safeEmit(state.copyWith(tasksLoading: newLoadingAfter, tasksErrors: newErrors));
    }
  }

  Future<void> completeTask(String meetingId, String taskId) async {
    try {
      await repository.updateTaskStatus(meetingId, taskId, 'Completed');
      // Silently refetch tasks for this meeting to update the UI
      await fetchTasksForMeeting(meetingId, forceRefetch: true);
    } catch (e) {
      print('Error completing task: $e');
    }
  }

  void safeEmit(TasksState newState) {
    if (!isClosed) {
      emit(newState);
    }
  }
}
