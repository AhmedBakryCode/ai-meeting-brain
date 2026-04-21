class TaskEntity {
  const TaskEntity({
    required this.id,
    required this.title,
    required this.status,
    this.assignedToUserId,
    this.assignedToUserName,
    this.dueDate,
    this.completedAt,
  });

  final String id;
  final String title;
  final String status; // 'Pending', 'Completed', etc.
  final String? assignedToUserId;
  final String? assignedToUserName;
  final DateTime? dueDate;
  final DateTime? completedAt;

  bool get isDone => status == 'Completed';
}
