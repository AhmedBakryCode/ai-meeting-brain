part of 'tasks_cubit.dart';

class TasksState {
  final List<MeetingEntity> meetings;
  final bool meetingsLoading;
  final String? meetingsError;
  
  final Map<String, List<TaskEntity>> tasksByMeeting;
  final Map<String, bool> tasksLoading;
  final Map<String, String> tasksErrors;

  const TasksState({
    this.meetings = const [],
    this.meetingsLoading = false,
    this.meetingsError,
    this.tasksByMeeting = const {},
    this.tasksLoading = const {},
    this.tasksErrors = const {},
  });

  TasksState copyWith({
    List<MeetingEntity>? meetings,
    bool? meetingsLoading,
    String? meetingsError,
    Map<String, List<TaskEntity>>? tasksByMeeting,
    Map<String, bool>? tasksLoading,
    Map<String, String>? tasksErrors,
  }) {
    return TasksState(
      meetings: meetings ?? this.meetings,
      meetingsLoading: meetingsLoading ?? this.meetingsLoading,
      meetingsError: meetingsError ?? this.meetingsError,
      tasksByMeeting: tasksByMeeting ?? this.tasksByMeeting,
      tasksLoading: tasksLoading ?? this.tasksLoading,
      tasksErrors: tasksErrors ?? this.tasksErrors,
    );
  }
}
