import '../../documents/models/document_model.dart';
import '../../events/models/event_model.dart';
import '../../members/models/member_model.dart';
import '../../posts/models/post_model.dart';
import '../../tasks/models/task_model.dart';
import 'pole_model.dart';

class PoleTypePresentation {
  static const metier = 'metier';
  static const support = 'support';

  static String label(String value) => switch (value.trim().toLowerCase()) {
    'metier' || 'métier' => 'Pôle cœur',
    'support' => 'Pôle support',
    _ => 'Type non reconnu',
  };
}

class PoleTaskPresentation {
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

class PoleAssignee {
  final String userId;
  final String displayName;

  const PoleAssignee({required this.userId, required this.displayName});
}

class PoleNextAction {
  final TaskModel task;
  final List<PoleAssignee> assignees;

  const PoleNextAction({required this.task, this.assignees = const []});

  String get ownerLabel => assignees.isEmpty
      ? 'Porteur non renseigné'
      : assignees.map((item) => item.displayName).join(', ');
}

class PoleAlertSummary {
  final int blockedCount;
  final int overdueCount;

  const PoleAlertSummary({
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

class PolePortfolioItem {
  final PoleModel pole;
  final List<MemberModel>? members;
  final List<TaskModel>? tasks;
  final PoleNextAction? nextAction;
  final bool membersUnavailable;
  final bool tasksUnavailable;

  const PolePortfolioItem({
    required this.pole,
    required this.members,
    required this.tasks,
    required this.nextAction,
    required this.membersUnavailable,
    required this.tasksUnavailable,
  });

  List<MemberModel> get activeMembers => (members ?? const [])
      .where((member) => member.isActive != false)
      .toList();

  MemberModel? get lead => _memberAt('chef_pole');
  MemberModel? get deputy => _memberAt('adjoint_chef_pole');

  String get leadLabel {
    if (membersUnavailable) return 'Information indisponible';
    return lead?.displayName ?? 'Aucun chef de pôle affecté';
  }

  String get deputyLabel {
    if (membersUnavailable) return 'Information indisponible';
    return deputy?.displayName ?? 'Aucun adjoint affecté';
  }

  String get teamLabel {
    if (membersUnavailable) return 'Équipe indisponible';
    if (activeMembers.isEmpty) return 'Aucune équipe affectée';
    final count = activeMembers.length;
    return '$count membre${count > 1 ? 's' : ''} actif${count > 1 ? 's' : ''}';
  }

  PoleAlertSummary get alerts {
    if (tasksUnavailable) {
      return const PoleAlertSummary(blockedCount: 0, overdueCount: 0);
    }
    final now = DateTime.now();
    final safeTasks = tasks ?? const <TaskModel>[];
    return PoleAlertSummary(
      blockedCount: safeTasks.where((task) => task.status == 'bloque').length,
      overdueCount: safeTasks.where((task) {
        final due = DateTime.tryParse(task.dueDate ?? '');
        return due != null &&
            due.isBefore(now) &&
            !PoleTaskPresentation.isTerminal(task.status);
      }).length,
    );
  }

  MemberModel? _memberAt(String position) {
    for (final member in activeMembers) {
      if (member.polePosition == position) return member;
    }
    return null;
  }
}

class PoleDetailData {
  final PolePortfolioItem item;
  final List<DocumentModel>? documents;
  final List<EventModel>? events;
  final List<PostModel>? posts;
  final Map<String, List<PoleAssignee>> taskAssignees;
  final bool documentsUnavailable;
  final bool activityUnavailable;

  const PoleDetailData({
    required this.item,
    required this.documents,
    required this.events,
    required this.posts,
    this.taskAssignees = const {},
    required this.documentsUnavailable,
    required this.activityUnavailable,
  });
}

enum PoleAlertFilter {
  all,
  blocked,
  overdue,
  noNextAction,
  noLead,
  noDeputy,
  noTeam,
}
