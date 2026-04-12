class TaskEntity {
  const TaskEntity({
    required this.id,
    required this.title,
    required this.isDone,
  });

  final String id;
  final String title;
  final bool isDone;
}
