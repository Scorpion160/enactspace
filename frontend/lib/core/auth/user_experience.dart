class UserExperience {
  final String id;
  final String email;
  final String displayName;
  final String status;
  final Set<String> roles;

  const UserExperience({
    required this.id,
    required this.email,
    required this.displayName,
    required this.status,
    required this.roles,
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
      roles: _parseRoles(json['roles']),
    );
  }

  bool hasRole(String role) => roles.contains(role);

  bool hasAnyRole(Set<String> values) {
    return roles.intersection(values).isNotEmpty;
  }

  bool get isAdmin => hasRole('administrateur');
  bool get isTeamLeader => hasRole('team_leader');
  bool get isSecretary => hasRole('secretaire_generale');
  bool get isFinance => hasRole('financier');
  bool get isAlumni => status == 'alumni' || hasRole('alumni');

  bool get isProjectOrPoleLead {
    return hasAnyRole({
      'chef_pole',
      'adjoint_chef_pole',
      'chef_projet',
      'adjoint_chef_projet',
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
  bool get canViewRecruitment =>
      isAdmin || isTeamLeader || isSecretary || isEnacchef;
  bool get canViewImpact => isEnacchef;
  bool get canCreateOperationalWork => isEnacchef;
  bool get canManageAttendance => isEnacchef;

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
    return 'Espace Enacteur';
  }

  String get dashboardTitle {
    if (isAlumni) return 'Espace alumni';
    if (isMemberExperience) return 'Mon espace Enacteur';
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

    final routes = <String>{
      '/dashboard',
      '/notifications',
      '/posts',
      '/chat',
      '/tasks',
      '/documents',
      '/events',
      '/gamification',
    };

    if (!user.isAlumni) {
      routes.addAll({'/poles', '/projects', '/attendance'});
    }

    if (user.isAlumni) {
      routes.add('/alumni');
    }

    if (user.canManageMembers) {
      routes.add('/members');
    }

    if (user.canViewFinance) {
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
    return value.map((item) => item.toString()).toSet();
  }
  return {};
}
