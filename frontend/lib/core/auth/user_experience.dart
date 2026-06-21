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

  bool get isAdmin =>
      hasAnyRole({'administrateur', 'admin', 'administrator', 'super_admin'});

  bool get isTeamLeader => hasAnyRole({
    'team_leader',
    'team leader',
    'tl',
    'president',
    'presidente',
  });

  bool get isSecretary => hasAnyRole({
    'secretaire_generale',
    'secretaire_general',
    'secretary',
    'sg',
  });

  bool get isFinance =>
      hasAnyRole({'financier', 'finance', 'tresorier', 'treasurer'});

  bool get isAlumni => status == 'alumni' || hasRole('alumni');
  bool get isEnactrice => gender == 'femme';
  String get memberLabel => isEnactrice ? 'Enactrice' : 'Enacteur';

  bool get isProjectOrPoleLead {
    return hasAnyRole({
      'chef_pole',
      'chef de pole',
      'adjoint_chef_pole',
      'adjoint chef pole',
      'chef_projet',
      'chef de projet',
      'adjoint_chef_projet',
      'adjoint chef projet',
      'project_lead',
      'pole_lead',
    });
  }

  bool get isRecruitmentLead {
    return hasAnyRole({
      'pole_veille',
      'veille',
      'chef_pole_veille',
      'adjoint_pole_veille',
      'recrutement',
      'recruiter',
    });
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
  bool get canViewMembersDirectory => !isAlumni || canManageMembers;
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
      '/attendance',
      '/documents',
      '/events',
      '/gamification',
      '/academy',
      '/archives',
    };

    routes.addAll({'/poles', '/projects'});

    if (user.canViewMembersDirectory) {
      routes.add('/members');
    }

    if (!user.isAlumni) {
      routes.add('/finance');
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
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
}
