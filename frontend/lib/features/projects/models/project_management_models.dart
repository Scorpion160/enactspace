import '../../../core/auth/user_experience.dart';
import 'project_member_model.dart';
import 'project_model.dart';
import 'project_status_presentation.dart';

class ProjectSeasonOption {
  final String id;
  final String name;
  final bool isCurrent;

  const ProjectSeasonOption({
    required this.id,
    required this.name,
    required this.isCurrent,
  });

  factory ProjectSeasonOption.fromJson(Map<String, dynamic> json) {
    return ProjectSeasonOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Saison sans nom',
      isCurrent: json['is_current'] == true,
    );
  }
}

class ProjectMutationDraft {
  final String? seasonId;
  final String name;
  final String description;
  final String problemStatement;
  final String solution;
  final String objectives;
  final String expectedImpact;
  final double budgetEstimated;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const ProjectMutationDraft({
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
  });

  factory ProjectMutationDraft.fromProject(ProjectModel project) {
    return ProjectMutationDraft(
      seasonId: project.seasonId,
      name: project.name,
      description: project.description ?? '',
      problemStatement: project.problemStatement ?? '',
      solution: project.solution ?? '',
      objectives: project.objectives ?? '',
      expectedImpact: project.expectedImpact ?? '',
      budgetEstimated: project.budgetEstimated,
      status: project.status,
      startedAt: project.startedAt,
      endedAt: project.endedAt,
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'season_id': _nullableId(seasonId),
    'name': name.trim(),
    'description': _nullable(description),
    'problem_statement': _nullable(problemStatement),
    'solution': _nullable(solution),
    'objectives': _nullable(objectives),
    'expected_impact': _nullable(expectedImpact),
    'budget_estimated': budgetEstimated,
    'status': status,
    'started_at': _dateOnly(startedAt),
    'ended_at': _dateOnly(endedAt),
  };

  Map<String, dynamic> toUpdateJson() => {
    'season_id': _nullableId(seasonId),
    'name': name.trim(),
    'description': _nullable(description),
    'problem_statement': _nullable(problemStatement),
    'solution': _nullable(solution),
    'objectives': _nullable(objectives),
    'expected_impact': _nullable(expectedImpact),
    'budget_estimated': budgetEstimated,
    'started_at': _dateOnly(startedAt),
    'ended_at': _dateOnly(endedAt),
  };
}

class ProjectManagementPermissions {
  static bool canCreate(UserExperience? user) =>
      user != null && (user.isAdmin || user.isTeamLeader || user.isSecretary);

  static bool canManage(
    UserExperience? user,
    List<ProjectMemberModel>? members,
  ) {
    if (user == null) return false;
    if (canCreate(user)) return true;
    return (members ?? const []).any(
      (member) =>
          member.userId == user.id &&
          member.isActive &&
          member.leftAt == null &&
          (member.position == 'chef_projet' ||
              member.position == 'adjoint_chef_projet'),
    );
  }
}

class ProjectStatusMutationPayload {
  static Map<String, dynamic> build(
    ProjectModel project,
    String targetStatus, {
    DateTime Function()? now,
  }) {
    if (!ProjectStatusPresentation.values.contains(targetStatus)) {
      throw ArgumentError.value(targetStatus, 'targetStatus');
    }
    final data = <String, dynamic>{'status': targetStatus};
    if (targetStatus == 'termine') {
      data['ended_at'] = _dateOnly(project.endedAt ?? (now ?? DateTime.now)());
    } else if (project.endedAt != null) {
      data['ended_at'] = null;
    }
    return data;
  }
}

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _nullableId(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String? _dateOnly(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
