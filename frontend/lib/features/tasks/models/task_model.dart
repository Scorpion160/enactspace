class TaskModel {
  final String id;
  final String title;
  final String? description;
  final String? creatorId;
  final String? assignedBy;
  final String priority;
  final String status;
  final String? dueDate;
  final bool proofRequired;
  final String? proofUrl;
  final String? createdAt;
  final String? completedAt;
  final String? validatedAt;
  final String? validatedBy;
  final String? updatedAt;
  final String? poleId;
  final String? projectId;
  final bool canManage;
  final bool currentUserAssigned;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.creatorId,
    this.assignedBy,
    required this.priority,
    required this.status,
    this.dueDate,
    required this.proofRequired,
    this.proofUrl,
    this.createdAt,
    this.completedAt,
    this.validatedAt,
    this.validatedBy,
    this.updatedAt,
    this.poleId,
    this.projectId,
    required this.canManage,
    required this.currentUserAssigned,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Tâche sans titre',
      description: json['description']?.toString(),
      creatorId: json['creator_id']?.toString(),
      assignedBy: json['assigned_by']?.toString(),
      priority: json['priority']?.toString() ?? 'normale',
      status: json['status']?.toString() ?? 'a_faire',
      dueDate: json['due_date']?.toString(),
      proofRequired: json['proof_required'] == true,
      proofUrl: json['proof_url']?.toString(),
      createdAt: json['created_at']?.toString(),
      completedAt: json['completed_at']?.toString(),
      validatedAt: json['validated_at']?.toString(),
      validatedBy: json['validated_by']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      poleId: json['pole_id']?.toString(),
      projectId: json['project_id']?.toString(),
      canManage: json['can_manage'] == true,
      currentUserAssigned: json['current_user_assigned'] == true,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'a_faire':
        return 'À faire';
      case 'en_cours':
        return 'En cours';
      case 'termine':
        return 'Terminé';
      case 'valide':
        return 'Validé';
      case 'bloque':
        return 'Bloqué';
      case 'annule':
        return 'Annulé';
      default:
        return status;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'basse':
        return 'Basse';
      case 'normale':
        return 'Normale';
      case 'haute':
        return 'Haute';
      case 'urgente':
        return 'Urgente';
      default:
        return priority;
    }
  }

  String get dueDateLabel {
    if (dueDate == null || dueDate!.isEmpty) return 'Sans échéance';

    final date = DateTime.tryParse(dueDate!);
    if (date == null) return dueDate!;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  DateTime? get dueAt => DateTime.tryParse(dueDate ?? '');

  bool get isTerminal => const {'termine', 'valide', 'annule'}.contains(status);

  bool isLateAt(DateTime now) {
    final due = dueAt;
    return due != null && due.isBefore(now) && !isTerminal;
  }
}
