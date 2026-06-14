class ProjectModel {
  final String id;
  final String? seasonId;
  final String name;
  final String? description;
  final String? problemStatement;
  final String? solution;
  final String? objectives;
  final String? expectedImpact;
  final double budgetEstimated;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  const ProjectModel({
    required this.id,
    required this.seasonId,
    required this.name,
    required this.description,
    required this.problemStatement,
    required this.solution,
    required this.objectives,
    required this.expectedImpact,
    required this.budgetEstimated,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.createdAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id']?.toString() ?? '',
      seasonId: json['season_id']?.toString(),
      name: json['name']?.toString() ?? 'Projet sans nom',
      description: json['description']?.toString(),
      problemStatement: json['problem_statement']?.toString(),
      solution: json['solution']?.toString(),
      objectives: json['objectives']?.toString(),
      expectedImpact: json['expected_impact']?.toString(),
      budgetEstimated:
          double.tryParse(json['budget_estimated']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'idee',
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
      endedAt: DateTime.tryParse(json['ended_at']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'etude':
        return 'Étude';
      case 'prototype':
        return 'Prototype';
      case 'test':
        return 'Test';
      case 'deploiement':
        return 'Déploiement';
      case 'termine':
        return 'Terminé';
      case 'suspendu':
        return 'Suspendu';
      default:
        return 'Idée';
    }
  }

  int get progress {
    switch (status) {
      case 'etude':
        return 18;
      case 'prototype':
        return 38;
      case 'test':
        return 58;
      case 'deploiement':
        return 78;
      case 'termine':
        return 100;
      case 'suspendu':
        return 28;
      default:
        return 8;
    }
  }
}
