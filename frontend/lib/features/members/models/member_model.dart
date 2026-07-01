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
  final String? studyLevel;
  final String? promotion;
  final String? bio;
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
    this.studyLevel,
    this.promotion,
    this.bio,
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
      studyLevel: json['study_level']?.toString(),
      promotion: json['promotion']?.toString(),
      bio: json['bio']?.toString(),
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

    return safeRoles
        .map((role) => role == 'enacteur' ? memberLabel : role)
        .join(', ');
  }

  String get primaryRoleLabel {
    if (roles.any((role) => role == 'administrateur')) return 'Admin';
    if (roles.any((role) => role == 'team_leader')) return 'Team Leader';
    if (roles.any((role) => role == 'secretaire_generale')) return 'SG';
    if (roles.any((role) => role == 'financier')) return 'Financier';
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

  String get phoneLabel => _labelOrFallback(phone);
  String get studyLevelLabel => _labelOrFallback(studyLevel);
  String get promotionLabel => _labelOrFallback(promotion);
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

  static String _labelOrFallback(String? value) {
    if (value == null || value.trim().isEmpty) return 'Non renseigné';
    return value.trim();
  }
}
