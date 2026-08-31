import '../../../core/auth/user_experience.dart';
import '../../members/models/member_model.dart';
import 'pole_model.dart';

class PoleMutationDraft {
  final String name;
  final String shortName;
  final String type;
  final String description;
  final String objectives;

  const PoleMutationDraft({
    required this.name,
    required this.shortName,
    required this.type,
    required this.description,
    required this.objectives,
  });

  factory PoleMutationDraft.fromPole(PoleModel pole) => PoleMutationDraft(
    name: pole.name,
    shortName: pole.shortName ?? '',
    type: pole.type,
    description: pole.description ?? '',
    objectives: pole.objectives ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'short_name': _nullable(shortName),
    'type': type,
    'description': _nullable(description),
    'objectives': _nullable(objectives),
  };
}

class PolePositionPresentation {
  static const member = 'membre';
  static const lead = 'chef_pole';
  static const deputy = 'adjoint_chef_pole';

  static bool isLeadership(String? value) => value == lead || value == deputy;

  static String label(String? value) => switch (value) {
    lead => 'Chef de pôle',
    deputy => 'Adjoint du pôle',
    _ => 'Membre du pôle',
  };
}

class PoleManagementPermissions {
  final bool isGlobalManager;
  final bool isLocalManager;

  const PoleManagementPermissions({
    required this.isGlobalManager,
    required this.isLocalManager,
  });

  factory PoleManagementPermissions.resolve(
    UserExperience? user,
    List<MemberModel>? memberships,
  ) {
    if (user == null) {
      return const PoleManagementPermissions(
        isGlobalManager: false,
        isLocalManager: false,
      );
    }
    final global = canCreate(user);
    final local = (memberships ?? const []).any(
      (membership) =>
          membership.id == user.id &&
          membership.isActive != false &&
          PolePositionPresentation.isLeadership(membership.polePosition),
    );
    return PoleManagementPermissions(
      isGlobalManager: global,
      isLocalManager: local,
    );
  }

  static bool canCreate(UserExperience? user) =>
      user != null && (user.isAdmin || user.isTeamLeader || user.isSecretary);

  bool get canEditPole => isGlobalManager || isLocalManager;
  bool get canManageOrdinaryMembers => isGlobalManager || isLocalManager;
  bool get canManageResponsibilities => isGlobalManager;

  bool canRemove(MemberModel membership) =>
      isGlobalManager ||
      (isLocalManager &&
          !PolePositionPresentation.isLeadership(membership.polePosition));
}

class PoleDirectoryCandidate {
  final MemberModel member;
  final MemberModel? activeMembership;

  const PoleDirectoryCandidate({
    required this.member,
    required this.activeMembership,
  });

  bool get isEligible => member.status == 'active' && !member.isAlumni;
  bool get alreadyInTeam => activeMembership != null;
}

enum PoleMemberMutationKind { assigned, reactivated, responsibilityUpdated }

class PoleMemberMutationResult {
  final MemberModel membership;
  final PoleMemberMutationKind kind;

  const PoleMemberMutationResult({
    required this.membership,
    this.kind = PoleMemberMutationKind.assigned,
  });
}

String poleManagementErrorMessage(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  final normalized = message.toLowerCase();
  if (normalized.contains('inactif') ||
      normalized.contains("n'est pas actif")) {
    return 'Cette personne ne possède pas un compte actif.';
  }
  if (normalized.contains('permission') ||
      normalized.contains('réservée') ||
      normalized.contains('403')) {
    return 'Permission insuffisante pour cette opération.';
  }
  if (normalized.contains('introuvable')) return 'Pôle ou membre introuvable.';
  if (normalized.contains('network') ||
      normalized.contains('socket') ||
      normalized.contains('connexion')) {
    return 'Connexion impossible. Vérifiez le réseau puis réessayez.';
  }
  return message.isEmpty ? 'Erreur serveur. Réessayez.' : message;
}

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
