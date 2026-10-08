class MemberModel {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? phone;
  final String? status;
  final bool? isActive;
  final bool? emailVerified;
  final String? corePoleId;
  final String? polePosition;
  final String? gender;
  final String? profileType;
  final List<String> roles;
  final String? department;
  final String? cursus;
  final String? studyLevel;
  final String? specialty;
  final String? promotion;
  final int? enactusJoinYear;
  final String? bio;
  final String? linkedinUrl;
  final String? githubUrl;
  final String? portfolioUrl;
  final String? createdAt;
  final String? photoUrl;

  const MemberModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.fullName,
    this.phone,
    this.status,
    this.isActive,
    this.emailVerified,
    this.corePoleId,
    this.polePosition,
    this.gender,
    this.profileType,
    this.roles = const [],
    this.department,
    this.cursus,
    this.studyLevel,
    this.specialty,
    this.promotion,
    this.enactusJoinYear,
    this.bio,
    this.linkedinUrl,
    this.githubUrl,
    this.portfolioUrl,
    this.createdAt,
    this.photoUrl,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      fullName:
          json['full_name']?.toString() ??
          json['name']?.toString() ??
          _buildFullName(json),
      phone: json['phone']?.toString(),
      status: json['status']?.toString(),
      isActive: json['is_active'] is bool ? json['is_active'] as bool : null,
      emailVerified: json['email_verified'] is bool
          ? json['email_verified'] as bool
          : null,
      corePoleId: json['core_pole_id']?.toString(),
      polePosition: json['pole_position']?.toString(),
      gender: json['gender']?.toString(),
      profileType: json['profile_type']?.toString(),
      roles: _parseRoles(json['roles']),
      department: json['department']?.toString(),
      cursus: json['cursus']?.toString(),
      studyLevel: json['study_level']?.toString(),
      specialty: json['specialty']?.toString(),
      promotion: json['promotion']?.toString(),
      enactusJoinYear: json['enactus_join_year'] is num
          ? (json['enactus_join_year'] as num).toInt()
          : int.tryParse(json['enactus_join_year']?.toString() ?? ''),
      bio: json['bio']?.toString(),
      linkedinUrl: json['linkedin_url']?.toString(),
      githubUrl: json['github_url']?.toString(),
      portfolioUrl: json['portfolio_url']?.toString(),
      createdAt: json['created_at']?.toString(),
      photoUrl:
          json['photo_url']?.toString() ??
          json['avatar_url']?.toString() ??
          json['profile_photo_url']?.toString(),
    );
  }

  static List<String> _parseRoles(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static String? _buildFullName(Map<String, dynamic> json) {
    final firstName = json['first_name']?.toString();
    final lastName = json['last_name']?.toString();

    final parts = [
      if (firstName != null && firstName.trim().isNotEmpty) firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty) lastName.trim(),
    ];

    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!;
    }

    final parts = [
      if (firstName != null && firstName!.trim().isNotEmpty) firstName!.trim(),
      if (lastName != null && lastName!.trim().isNotEmpty) lastName!.trim(),
    ];

    if (parts.isNotEmpty) return parts.join(' ');

    return email;
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Actif';
      case 'pending':
        return profileType == 'alumni' ? 'Alumni en validation' : 'En attente';
      case 'inactive':
        return 'Inactif';
      case 'alumni':
        return 'Alumni';
      case 'suspended':
        return 'Suspendu';
      case 'rejected':
        return 'Rejeté';
      case 'resigned':
        return 'Démissionné';
      case 'removed':
        return 'Renvoyé';
      default:
        return status ?? 'Non renseigné';
    }
  }

  bool get isAlumni => status == 'alumni' || profileType == 'alumni';
  bool get isPendingAlumniValidation =>
      status == 'pending' && profileType == 'alumni';

  String get memberLabel {
    if (isAlumni) return 'Alumni';

    switch (gender?.trim().toLowerCase()) {
      case 'homme':
      case 'masculin':
      case 'male':
        return 'Enacteur';
      case 'femme':
      case 'feminin':
      case 'féminin':
      case 'female':
        return 'Enactrice';
      default:
        return 'Enacteur/Enactrice';
    }
  }

  String get rolesLabel {
    final safeRoles = roles.where((role) => role.trim().isNotEmpty).toList();

    if (safeRoles.isEmpty) return memberLabel;

    return safeRoles.map(_roleLabel).toSet().join(', ');
  }

  String get primaryRoleLabel {
    if (roles.any((role) => role == 'administrateur')) {
      return 'Administrateur';
    }
    if (roles.any((role) => role == 'team_leader')) return 'Team Leader';
    if (roles.any((role) => role == 'secretaire_generale')) {
      return 'Secrétaire générale';
    }
    if (roles.any((role) => role == 'financier')) return 'Financier';
    if (roles.contains('pole_veille')) return 'Pôle Veille';
    if (roles.any((role) => role == 'chef_pole')) return 'Chef de pôle';
    if (roles.any((role) => role == 'adjoint_chef_pole')) {
      return 'Adjoint de pôle';
    }
    if (roles.any((role) => role == 'chef_projet')) return 'Chef de projet';
    if (roles.any((role) => role == 'adjoint_chef_projet')) {
      return 'Adjoint de projet';
    }
    return memberLabel;
  }

  String _roleLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'administrateur':
        return 'Administrateur';
      case 'team_leader':
        return 'Team Leader';
      case 'secretaire_generale':
        return 'Secrétaire générale';
      case 'financier':
        return 'Financier';
      case 'pole_veille':
        return 'Pôle Veille';
      case 'chef_pole':
        return 'Chef de pôle';
      case 'adjoint_chef_pole':
        return 'Adjoint de pôle';
      case 'chef_projet':
        return 'Chef de projet';
      case 'adjoint_chef_projet':
        return 'Adjoint de projet';
      case 'alumni':
        return 'Alumni';
      case 'enacteur':
        return memberLabel;
      default:
        return value;
    }
  }

  String get phoneLabel => _labelOrFallback(phone);
  String get cursusLabel => _labelOrFallback(cursus);
  String get studyLevelLabel => _labelOrFallback(studyLevel);
  String get specialtyLabel => _labelOrFallback(specialty);
  String get promotionLabel => _labelOrFallback(promotion);
  String get polePositionLabel => _formatPolePosition(polePosition);
  String get enactusJoinYearLabel =>
      enactusJoinYear?.toString() ?? 'Non renseigné';
  String get bioLabel => _labelOrFallback(bio);
  String get joinedAtLabel {
    final parsed = DateTime.tryParse(createdAt ?? '');
    if (parsed == null) return 'Non renseigné';
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  String get departmentLabel {
    return _labelOrFallback(department);
  }

  static int compareAlphabetically(MemberModel left, MemberModel right) {
    final leftLast = _alphabeticKey(
      left.lastName?.trim().isNotEmpty == true
          ? left.lastName!
          : _fallbackLastName(left.displayName),
    );
    final rightLast = _alphabeticKey(
      right.lastName?.trim().isNotEmpty == true
          ? right.lastName!
          : _fallbackLastName(right.displayName),
    );
    final lastCompare = leftLast.compareTo(rightLast);
    if (lastCompare != 0) return lastCompare;

    final leftFirst = _alphabeticKey(
      left.firstName?.trim().isNotEmpty == true
          ? left.firstName!
          : _fallbackFirstName(left.displayName),
    );
    final rightFirst = _alphabeticKey(
      right.firstName?.trim().isNotEmpty == true
          ? right.firstName!
          : _fallbackFirstName(right.displayName),
    );
    final firstCompare = leftFirst.compareTo(rightFirst);
    if (firstCompare != 0) return firstCompare;

    final displayCompare = _alphabeticKey(
      left.displayName,
    ).compareTo(_alphabeticKey(right.displayName));
    if (displayCompare != 0) return displayCompare;

    return left.email.toLowerCase().compareTo(right.email.toLowerCase());
  }

  static String _fallbackLastName(String displayName) {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    return parts.last;
  }

  static String _fallbackFirstName(String displayName) {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return displayName.trim();
    return parts.sublist(0, parts.length - 1).join(' ');
  }

  static String _alphabeticKey(String value) {
    var result = value.trim().toLowerCase();
    const replacements = <String, String>{
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ã': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'í': 'i',
      'ô': 'o',
      'ö': 'o',
      'ó': 'o',
      'õ': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ú': 'u',
      'ÿ': 'y',
      'œ': 'oe',
    };
    replacements.forEach((source, target) {
      result = result.replaceAll(source, target);
    });
    return result.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _formatPolePosition(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return 'Non renseigné';

    final normalized = raw
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'\s+'), '_');

    String suffixLabel(String prefix) {
      final suffix = normalized.substring(prefix.length);
      if (suffix.isEmpty) return '';
      return suffix
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');
    }

    for (final prefix in const ['chef_de_pole_', 'chef_pole_']) {
      if (normalized.startsWith(prefix)) {
        final pole = suffixLabel(prefix);
        return pole.isEmpty ? 'Chef de pôle' : 'Chef du pôle $pole';
      }
    }
    if (normalized == 'chef_pole' || normalized == 'chef_de_pole') {
      return 'Chef de pôle';
    }

    for (final prefix in const [
      'adjoint_chef_de_pole_',
      'adjoint_chef_pole_',
    ]) {
      if (normalized.startsWith(prefix)) {
        final pole = suffixLabel(prefix);
        return pole.isEmpty ? 'Adjoint du pôle' : 'Adjoint du pôle $pole';
      }
    }
    if (normalized == 'adjoint_chef_pole' ||
        normalized == 'adjoint_chef_de_pole') {
      return 'Adjoint du pôle';
    }
    if (normalized == 'membre' || normalized == 'membre_pole') {
      return 'Membre du pôle';
    }

    final words = raw.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (words.isEmpty) return 'Non renseigné';
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  static String _labelOrFallback(String? value) {
    if (value == null || value.trim().isEmpty) return 'Non renseigné';
    return value.trim();
  }
}
