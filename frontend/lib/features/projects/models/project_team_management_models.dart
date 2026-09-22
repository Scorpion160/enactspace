import '../../../core/auth/user_experience.dart';
import '../../members/models/member_model.dart';
import 'project_member_model.dart';

class ProjectPositionPresentation {
  static const member = 'membre';
  static const lead = 'chef_projet';
  static const deputy = 'adjoint_chef_projet';
  static const values = [member, lead, deputy];

  static String label(String value) => switch (value) {
    lead => 'Chef de projet',
    deputy => 'Adjoint chef de projet',
    _ => 'Membre du projet',
  };

  static bool isLeadership(String value) => value == lead || value == deputy;
}

class ProjectTeamPermissions {
  final bool isGlobalManager;
  final bool isLocalManager;

  const ProjectTeamPermissions({
    required this.isGlobalManager,
    required this.isLocalManager,
  });

  factory ProjectTeamPermissions.resolve(
    UserExperience? user,
    List<ProjectMemberModel>? memberships,
  ) {
    if (user == null) {
      return const ProjectTeamPermissions(
        isGlobalManager: false,
        isLocalManager: false,
      );
    }
    final global = user.isAdmin || user.isTeamLeader || user.isSecretary;
    final local = (memberships ?? const []).any(
      (membership) =>
          membership.userId == user.id &&
          membership.isActive &&
          membership.leftAt == null &&
          ProjectPositionPresentation.isLeadership(membership.position),
    );
    return ProjectTeamPermissions(
      isGlobalManager: global,
      isLocalManager: local,
    );
  }

  bool get canManageOrdinaryMembers => isGlobalManager || isLocalManager;
  bool get canManageResponsibilities => isGlobalManager;

  bool canRemove(ProjectMemberModel membership) =>
      isGlobalManager ||
      (isLocalManager &&
          !ProjectPositionPresentation.isLeadership(membership.position));
}

class ProjectDirectoryCandidate {
  final MemberModel member;
  final ProjectMemberModel? activeMembership;

  const ProjectDirectoryCandidate({
    required this.member,
    required this.activeMembership,
  });

  bool get isEligible => member.status == 'active' && member.isAlumni == false;
  bool get alreadyInTeam => activeMembership != null;
}

enum ProjectMemberMutationKind { assigned, reactivated, responsibilityUpdated }

class ProjectMemberMutationResult {
  final ProjectMemberModel membership;
  final ProjectMemberMutationKind kind;

  const ProjectMemberMutationResult({
    required this.membership,
    this.kind = ProjectMemberMutationKind.assigned,
  });
}

String projectTeamErrorMessage(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  final normalized = message.toLowerCase();
  if (normalized.contains("n'est pas actif") ||
      normalized.contains('utilisateur inactif')) {
    return 'Cette personne ne possède pas un compte actif.';
  }
  if (normalized.contains('projet introuvable')) return 'Projet introuvable.';
  if (normalized.contains('utilisateur introuvable')) {
    return 'Utilisateur introuvable.';
  }
  if (normalized.contains('position projet invalide')) {
    return 'Responsabilité dans le projet invalide.';
  }
  if (normalized.contains('réservée') ||
      normalized.contains('seuls admin') ||
      normalized.contains('permission') ||
      normalized.contains('403')) {
    return 'Permission insuffisante pour cette opération.';
  }
  if (normalized.contains('membre non rattaché')) {
    return 'Cette personne ne fait pas partie de ce projet.';
  }
  if (normalized.contains('network') ||
      normalized.contains('socket') ||
      normalized.contains('connexion')) {
    return 'Connexion impossible. Vérifiez le réseau puis réessayez.';
  }
  return message.isEmpty ? 'Erreur serveur. Réessayez.' : message;
}
