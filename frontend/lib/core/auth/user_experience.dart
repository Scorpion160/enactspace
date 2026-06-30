const Set<String> _adminRoles = {
  'administrateur',
  'admin',
  'administrator',
  'super_admin',
};

const Set<String> _teamLeaderRoles = {
  'team_leader',
  'tl',
  'president',
  'presidente',
};

const Set<String> _secretaryRoles = {
  'secretaire_generale',
  'secretaire_general',
  'secretary',
  'sg',
};

const Set<String> _financeRoles = {
  'financier',
  'financiere',
  'finance',
  'tresorier',
  'tresoriere',
  'treasurer',
};

const Set<String> _poleLeadRoles = {
  'chef_pole',
  'chef_de_pole',
  'adjoint_chef_pole',
  'adjoint_chef_de_pole',
  'pole_lead',
};

const Set<String> _projectLeadRoles = {
  'chef_projet',
  'chef_de_projet',
  'adjoint_chef_projet',
  'adjoint_chef_de_projet',
  'project_lead',
};

const Set<String> _recruitmentRoles = {
  'pole_veille',
  'veille',
  'chef_pole_veille',
  'adjoint_pole_veille',
  'recrutement',
  'recruiter',
};

class UserExperience {
  final String id;
  final String email;
  final String displayName;
  final String status;
  final String? gender;
  final String profileType;
  final Set<String> roles;
  final bool canReviewJoinRequests;

  const UserExperience({
    required this.id,
    required this.email,
    required this.displayName,
    required this.status,
    required this.gender,
    required this.profileType,
    required this.roles,
    required this.canReviewJoinRequests,
  });

  factory UserExperience.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name']?.toString().trim() ?? '';
    final lastName = json['last_name']?.toString().trim() ?? '';
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    final email = json['email']?.toString() ?? '';

    return UserExperience(
      id: json['id']?.toString() ?? '',
      email: email,
      displayName: fullName.isNotEmpty ? fullName : email,
      status: json['status']?.toString() ?? 'active',
      gender: json['gender']?.toString(),
      profileType:
          json['profile_type']?.toString() ??
          (json['status']?.toString() == 'alumni' ? 'alumni' : 'enacteur'),
      roles: _parseRoles(json['roles']),
      canReviewJoinRequests: json['can_review_join_requests'] == true,
    );
  }

  bool hasRole(String role) => roles.contains(_normalizeRole(role));

  bool hasAnyRole(Set<String> values) {
    return roles.intersection(values.map(_normalizeRole).toSet()).isNotEmpty;
  }

  bool get isAdmin => hasAnyRole(_adminRoles);

  bool get isTeamLeader => hasAnyRole(_teamLeaderRoles);

  bool get isSecretary => hasAnyRole(_secretaryRoles);

  bool get isFinance => hasAnyRole(_financeRoles);

  bool get isAlumni => status == 'alumni' || hasRole('alumni');
  String get normalizedGender => gender?.trim().toLowerCase() ?? '';
  bool get isEnactrice =>
      {'femme', 'feminin', 'féminin', 'female'}.contains(normalizedGender);
  bool get isEnacteur =>
      {'homme', 'masculin', 'male'}.contains(normalizedGender);

  String get memberLabel {
    if (isEnactrice) return 'Enactrice';
    if (isEnacteur) return 'Enacteur';
    return 'Enacteur/Enactrice';
  }

  bool get isProjectOrPoleLead {
    return hasAnyRole(_poleLeadRoles) || hasAnyRole(_projectLeadRoles);
  }

  bool get isRecruitmentLead {
    return hasAnyRole(_recruitmentRoles);
  }

  bool get isEnacchef {
    return isAdmin ||
        isTeamLeader ||
        isSecretary ||
        isFinance ||
        hasRole('faculty_advisor') ||
        isProjectOrPoleLead;
  }

  bool get canManageMembers => isAdmin || isTeamLeader || isSecretary;
  bool get canViewFinance => isAdmin || isTeamLeader || isFinance;
  bool get canManageFinance => isAdmin || isTeamLeader || isFinance;
  bool get canViewRecruitment =>
      isAdmin || isTeamLeader || isSecretary || isRecruitmentLead || isEnacchef;
  bool get canViewImpact => isEnacchef;
  bool get canCreateOperationalWork => isEnacchef;
  bool get canCreateTasks =>
      isAdmin || isTeamLeader || isSecretary || isProjectOrPoleLead;
  bool get canManageAttendance => isAdmin || isTeamLeader || isSecretary;
  bool get canManageGamification => isAdmin || isTeamLeader || isSecretary;
  bool get canViewMembersDirectory => canManageMembers || isProjectOrPoleLead;
  bool get canViewOperations => !isAlumni;

  bool get isMemberExperience {
    return !isAdmin &&
        !isTeamLeader &&
        !isSecretary &&
        !isFinance &&
        !isProjectOrPoleLead;
  }

  String get audienceLabel {
    if (isAdmin) return 'Administration';
    if (isTeamLeader) return 'Team Leader';
    if (isSecretary) return 'Secrétariat général';
    if (isFinance) return 'Finance';
    if (isProjectOrPoleLead) return 'Enacchef';
    if (isAlumni) return 'Alumni';
    return 'Espace $memberLabel';
  }

  String get dashboardTitle {
    if (isAlumni) return 'Espace alumni';
    if (isMemberExperience) return 'Mon espace $memberLabel';
    return 'Tableau de bord';
  }

  String get dashboardSubtitle {
    if (isAlumni) {
      return 'Opportunités, mentorat, actualités et contributions alumni.';
    }
    if (isMemberExperience) {
      return 'Tes tâches, annonces, documents, événements et notifications utiles.';
    }
    if (isFinance) {
      return 'Suivi des paiements, cotisations et alertes financières.';
    }
    if (isSecretary) {
      return 'Présences, membres, recrutements et coordination administrative.';
    }
    return 'Le cockpit quotidien de Enactus ESP.';
  }

  static List<String> visibleRoutesFor(UserExperience? user) {
    if (user == null) {
      return const ['/dashboard', '/posts', '/tasks', '/notifications'];
    }

    if (user.isAlumni) {
      return const [
        '/dashboard',
        '/notifications',
        '/posts',
        '/chat',
        '/events',
        '/academy',
        '/archives',
        '/alumni',
      ];
    }

    final routes = <String>{
      '/dashboard',
      '/notifications',
      '/posts',
      '/chat',
      '/tasks',
      '/documents',
      '/gamification',
      '/academy',
      '/archives',
    };

    if (user.canViewMembersDirectory) {
      routes.add('/members');
    }

    if (user.canViewFinance) {
      routes.add('/finance');
    }

    if (user.canManageAttendance || user.isProjectOrPoleLead) {
      routes.add('/attendance');
    }

    if (user.isEnacchef) {
      routes.addAll({'/poles', '/projects', '/events'});
    } else {
      routes.add('/events');
    }

    if (user.canViewRecruitment) {
      routes.add('/recruitment');
    }

    if (user.canViewImpact) {
      routes.add('/impact');
    }

    if (user.isAdmin ||
        user.isTeamLeader ||
        user.isSecretary ||
        user.isProjectOrPoleLead) {
      routes.add('/alumni');
    }

    return routes.toList();
  }
}

Set<String> _parseRoles(dynamic value) {
  if (value is List) {
    return value.map((item) => _normalizeRole(item.toString())).toSet();
  }
  return {};
}

String _normalizeRole(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll(RegExp('[- ]+'), '_');
}
