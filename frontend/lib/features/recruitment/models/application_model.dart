class ApplicationModel {
  final String id;
  final String campaignId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? department;
  final String? studyLevel;
  final String? motivation;
  final String? knownEnactusFrom;
  final String? enactusKnowledge;
  final String? otherClubs;
  final String? contribution;
  final String? projectIdeas;
  final String? leadershipProfile;
  final String? cvUrl;
  final String? motivationLetterUrl;
  final String status;
  final double? finalScore;
  final String? convertedUserId;
  final String? createdAt;
  final String? updatedAt;

  const ApplicationModel({
    required this.id,
    required this.campaignId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.department,
    this.studyLevel,
    this.motivation,
    this.knownEnactusFrom,
    this.enactusKnowledge,
    this.otherClubs,
    this.contribution,
    this.projectIdeas,
    this.leadershipProfile,
    this.cvUrl,
    this.motivationLetterUrl,
    required this.status,
    this.finalScore,
    this.convertedUserId,
    this.createdAt,
    this.updatedAt,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    return ApplicationModel(
      id: json['id']?.toString() ?? '',
      campaignId: json['campaign_id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      department: json['department']?.toString(),
      studyLevel: json['study_level']?.toString(),
      motivation: json['motivation']?.toString(),
      knownEnactusFrom: json['known_enactus_from']?.toString(),
      enactusKnowledge: json['enactus_knowledge']?.toString(),
      otherClubs: json['other_clubs']?.toString(),
      contribution: json['contribution']?.toString(),
      projectIdeas: json['project_ideas']?.toString(),
      leadershipProfile: json['leadership_profile']?.toString(),
      cvUrl: json['cv_url']?.toString(),
      motivationLetterUrl: json['motivation_letter_url']?.toString(),
      status: json['status']?.toString() ?? 'received',
      finalScore: double.tryParse(json['final_score']?.toString() ?? ''),
      convertedUserId: json['converted_user_id']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  String get statusLabel {
    switch (status) {
      case 'received':
        return 'Reçue';
      case 'preselected':
        return 'Présélectionnée';
      case 'interview':
        return 'Entretien';
      case 'accepted':
        return 'Acceptée';
      case 'rejected':
        return 'Rejetée';
      default:
        return status;
    }
  }

  String get scoreLabel {
    if (finalScore == null) return 'Non noté';
    return '${finalScore!.toStringAsFixed(1)}/20';
  }

  String get anonymousCode {
    final source = id.isNotEmpty ? id : email;
    final seed = source.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) % 9999,
    );
    return 'Candidat #${seed.toString().padLeft(4, '0')}';
  }

  String get stabilityLabel {
    final level = (studyLevel ?? '').toLowerCase();

    if (level.contains('dic1') ||
        level.contains('l1') ||
        level.contains('1ere') ||
        level.contains('1ère') ||
        level.contains('premi')) {
      return 'StabilitÃ© forte';
    }

    if (level.contains('dic2') ||
        level.contains('l2') ||
        level.contains('deux')) {
      return 'Bonne stabilitÃ©';
    }

    if (level.contains('dic3') ||
        level.contains('m2') ||
        level.contains('fin') ||
        level.contains('5')) {
      return 'DÃ©part proche';
    }

    return 'StabilitÃ© Ã  qualifier';
  }

  bool get isConverted {
    return convertedUserId != null && convertedUserId!.isNotEmpty;
  }
}
