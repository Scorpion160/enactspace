import '../../documents/models/document_model.dart';
import '../../events/models/event_model.dart';
import '../../tasks/models/task_model.dart';
import 'project_member_model.dart';
import 'project_model.dart';
export 'project_status_presentation.dart';

class ProjectTaskPresentation {
  static String statusLabel(String value) => switch (value) {
    'a_faire' => 'À faire',
    'en_cours' => 'En cours',
    'bloque' => 'Bloqué',
    'termine' => 'Terminé',
    'valide' => 'Validé',
    'annule' => 'Annulé',
    _ => 'Statut non reconnu',
  };

  static String priorityLabel(String value) => switch (value) {
    'basse' => 'Basse',
    'normale' => 'Normale',
    'haute' => 'Haute',
    'urgente' => 'Urgente',
    _ => 'Priorité non reconnue',
  };

  static bool isTerminal(String value) =>
      value == 'termine' || value == 'valide' || value == 'annule';
}

class ProjectImpactSnapshot {
  final String projectId;
  final double? progress;
  final int? directBeneficiaries;
  final int? indirectBeneficiaries;
  final int? reach;
  final int? jobsCreated;
  final int? livesImpacted;
  final int? treesPlanted;
  final double? wasteReduced;
  final double? waterSaved;
  final double? co2Reduced;
  final List<String> sdgs;
  final String? methodology;

  const ProjectImpactSnapshot({
    required this.projectId,
    required this.progress,
    required this.directBeneficiaries,
    required this.indirectBeneficiaries,
    required this.reach,
    required this.jobsCreated,
    required this.livesImpacted,
    required this.treesPlanted,
    required this.wasteReduced,
    required this.waterSaved,
    required this.co2Reduced,
    required this.sdgs,
    required this.methodology,
  });

  factory ProjectImpactSnapshot.fromJson(Map<String, dynamic> json) {
    double? number(dynamic value) =>
        value == null ? null : double.tryParse(value.toString());
    final rawProgress = double.tryParse(json['progress']?.toString() ?? '');
    final rawSdgs = json['sdgs'];
    return ProjectImpactSnapshot(
      projectId: json['id']?.toString() ?? '',
      progress: rawProgress?.clamp(0, 100),
      directBeneficiaries: number(json['direct_impact'])?.round(),
      indirectBeneficiaries: number(json['indirect_impact'])?.round(),
      reach: number(json['reach'])?.round(),
      jobsCreated: number(json['jobs_created'])?.round(),
      livesImpacted: number(json['lives_impacted'])?.round(),
      treesPlanted: number(json['trees_planted'])?.round(),
      wasteReduced: number(json['waste_reduced']),
      waterSaved: number(json['water_saved']),
      co2Reduced: number(json['co2_reduced']),
      sdgs: rawSdgs is List
          ? rawSdgs.map((item) => item.toString()).toList()
          : const [],
      methodology: _nonEmpty(json['methodology']),
    );
  }

  bool get hasContractualData =>
      progress != null ||
      directBeneficiaries != null ||
      indirectBeneficiaries != null ||
      reach != null ||
      jobsCreated != null ||
      livesImpacted != null ||
      treesPlanted != null ||
      wasteReduced != null ||
      waterSaved != null ||
      co2Reduced != null ||
      sdgs.isNotEmpty;
}

class ProjectAssignee {
  final String userId;
  final String displayName;

  const ProjectAssignee({required this.userId, required this.displayName});
}

class ProjectNextAction {
  final TaskModel task;
  final List<ProjectAssignee> assignees;

  const ProjectNextAction({required this.task, this.assignees = const []});

  String get ownerLabel => assignees.isEmpty
      ? 'Responsable non renseigné'
      : assignees.map((item) => item.displayName).join(', ');
}

class ProjectAlertSummary {
  final int blockedCount;
  final int overdueCount;

  const ProjectAlertSummary({
    required this.blockedCount,
    required this.overdueCount,
  });

  bool get hasAlerts => blockedCount > 0 || overdueCount > 0;

  List<String> get labels => [
    if (blockedCount > 0)
      '$blockedCount tâche${blockedCount > 1 ? 's' : ''} bloquée${blockedCount > 1 ? 's' : ''}',
    if (overdueCount > 0)
      '$overdueCount tâche${overdueCount > 1 ? 's' : ''} en retard',
  ];
}

class ProjectPortfolioItem {
  final ProjectModel project;
  final List<ProjectMemberModel>? members;
  final List<TaskModel>? tasks;
  final ProjectImpactSnapshot? impact;
  final ProjectNextAction? nextAction;
  final bool teamUnavailable;
  final bool tasksUnavailable;
  final bool impactUnavailable;

  const ProjectPortfolioItem({
    required this.project,
    required this.members,
    required this.tasks,
    required this.impact,
    required this.nextAction,
    required this.teamUnavailable,
    required this.tasksUnavailable,
    required this.impactUnavailable,
  });

  List<ProjectMemberModel> get activeMembers =>
      (members ?? const []).where((item) => item.isActive).toList();

  ProjectMemberModel? get lead => _memberAt('chef_projet');
  ProjectMemberModel? get deputy => _memberAt('adjoint_chef_projet');

  String get leadLabel {
    if (teamUnavailable) return 'Équipe indisponible';
    if (activeMembers.isEmpty) return 'Aucune équipe affectée';
    return lead?.displayName ?? 'Chef de projet non affecté';
  }

  ProjectAlertSummary get alerts {
    if (tasksUnavailable) {
      return const ProjectAlertSummary(blockedCount: 0, overdueCount: 0);
    }
    final now = DateTime.now();
    final safeTasks = tasks ?? const <TaskModel>[];
    return ProjectAlertSummary(
      blockedCount: safeTasks.where((task) => task.status == 'bloque').length,
      overdueCount: safeTasks.where((task) {
        final due = DateTime.tryParse(task.dueDate ?? '');
        return due != null &&
            due.isBefore(now) &&
            !ProjectTaskPresentation.isTerminal(task.status);
      }).length,
    );
  }

  bool get hasIncompleteData =>
      teamUnavailable || tasksUnavailable || impactUnavailable;

  bool get hasIncompleteImpactContext =>
      project.expectedImpact == null || project.expectedImpact!.trim().isEmpty;

  ProjectMemberModel? _memberAt(String position) {
    for (final member in activeMembers) {
      if (member.position == position) return member;
    }
    return null;
  }
}

class ProjectDetailData {
  final ProjectPortfolioItem item;
  final List<DocumentModel>? documents;
  final List<EventModel>? events;
  final Map<String, List<ProjectAssignee>> taskAssignees;
  final bool documentsUnavailable;
  final bool eventsUnavailable;

  const ProjectDetailData({
    required this.item,
    required this.documents,
    required this.events,
    this.taskAssignees = const {},
    required this.documentsUnavailable,
    required this.eventsUnavailable,
  });
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
