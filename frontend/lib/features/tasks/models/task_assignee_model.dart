class TaskAssigneeModel {
  final String id;
  final String taskId;
  final String userId;
  final String? assignedAt;

  const TaskAssigneeModel({
    required this.id,
    required this.taskId,
    required this.userId,
    this.assignedAt,
  });

  factory TaskAssigneeModel.fromJson(Map<String, dynamic> json) {
    return TaskAssigneeModel(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      assignedAt: json['assigned_at']?.toString(),
    );
  }
}
