class ApplicationModel {
  final String id;
  final String campaignId;
  final String firstName;
  final String lastName;
  final String? gender;
  final String email;
  final String? phone;
  final String? department;
  final String? studyLevel;
  final String? className;
  final String? motivation;
  final String? knownEnactusFrom;
  final String? enactusKnowledge;
  final String? otherClubs;
  final String? contribution;
  final String? projectIdeas;
  final String? leadershipProfile;
  final String? preferredPole;
  final String? projectInterest;
  final String? associativeExperience;
  final String? availability;
  final String? publicComment;
  final DateTime? interviewAt;
  final String? interviewLocation;
  final String? interviewLink;
  final String? interviewJury;
  final String? interviewNote;
  final String? cvUrl;
  final String? motivationLetterUrl;
  final String? attachmentUrl;
  final String status;
  final String? trackingCode;
  final double? finalScore;
  final String? convertedUserId;
  final String? createdAt;
  final String? updatedAt;
  final bool isAnonymized;
  final String? serverAnonymousCode;
  final bool canConvert;

  const ApplicationModel({
    required this.id,
    required this.campaignId,
    required this.firstName,
    required this.lastName,
    this.gender,
    required this.email,
    this.phone,
    this.department,
    this.studyLevel,
    this.className,
    this.motivation,
    this.knownEnactusFrom,
    this.enactusKnowledge,
    this.otherClubs,
    this.contribution,
    this.projectIdeas,
    this.leadershipProfile,
    this.preferredPole,
    this.projectInterest,
    this.associativeExperience,
    this.availability,
    this.publicComment,
    this.interviewAt,
    this.interviewLocation,
    this.interviewLink,
    this.interviewJury,
    this.interviewNote,
    this.cvUrl,
    this.motivationLetterUrl,
    this.attachmentUrl,
    required this.status,
    this.trackingCode,
    this.finalScore,
    this.convertedUserId,
    this.createdAt,
    this.updatedAt,
    required this.isAnonymized,
    this.serverAnonymousCode,
    required this.canConvert,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    return ApplicationModel(
      id: json['id']?.toString() ?? '',
      campaignId: json['campaign_id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      gender: json['gender']?.toString(),
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      department: json['department']?.toString(),
      studyLevel: json['study_level']?.toString(),
      className: json['class_name']?.toString(),
      motivation: json['motivation']?.toString(),
      knownEnactusFrom: json['known_enactus_from']?.toString(),
      enactusKnowledge: json['enactus_knowledge']?.toString(),
      otherClubs: json['other_clubs']?.toString(),
      contribution: json['contribution']?.toString(),
      projectIdeas: json['project_ideas']?.toString(),
      leadershipProfile: json['leadership_profile']?.toString(),
      preferredPole: json['preferred_pole']?.toString(),
      projectInterest: json['project_interest']?.toString(),
      associativeExperience: json['associative_experience']?.toString(),
      availability: json['availability']?.toString(),
      publicComment: json['public_comment']?.toString(),
      interviewAt: DateTime.tryParse(json['interview_at']?.toString() ?? ''),
      interviewLocation: json['interview_location']?.toString(),
      interviewLink: json['interview_link']?.toString(),
      interviewJury: json['interview_jury']?.toString(),
      interviewNote: json['interview_note']?.toString(),
      cvUrl: json['cv_url']?.toString(),
      motivationLetterUrl: json['motivation_letter_url']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      status: json['status']?.toString() ?? 'submitted',
      trackingCode: json['tracking_code']?.toString(),
      finalScore: double.tryParse(json['final_score']?.toString() ?? ''),
      convertedUserId: json['converted_user_id']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      isAnonymized: json['is_anonymized'] == true,
      serverAnonymousCode: json['anonymous_code']?.toString(),
      canConvert: json['can_convert'] == true,
    );
  }

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  String get statusLabel {
    switch (status) {
      case 'submitted':
      case 'received':
        return 'Reçue';
      case 'under_review':
        return 'En étude';
      case 'interview_scheduled':
        return 'Entretien programmé';
      case 'preselected':
        return 'Présélectionnée';
      case 'interview':
        return 'Entretien';
      case 'accepted':
        return 'Acceptée';
      case 'rejected':
        return 'Rejetée';
      case 'waiting_list':
        return 'Liste d’attente';
      case 'cancelled':
        return 'Clôturée';
      default:
        return status;
    }
  }

  String get scoreLabel {
    if (finalScore == null) return 'Non noté';
    return '${finalScore!.toStringAsFixed(1)}/20';
  }

  String get anonymousCode {
    if (serverAnonymousCode != null && serverAnonymousCode!.isNotEmpty) {
      return serverAnonymousCode!;
    }
    final source = id.isNotEmpty ? id : email;
    final seed = source.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) % 9999,
    );
    return 'Candidat #${seed.toString().padLeft(4, '0')}';
  }

  String get publicTrackingCode {
    final value = trackingCode?.trim();
    if (value != null && value.isNotEmpty) return value;
    return id;
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

  int get screeningScore {
    var score = 0;

    if ((motivation ?? '').trim().length >= 80) score += 20;
    if ((enactusKnowledge ?? '').trim().length >= 50) score += 15;
    if ((contribution ?? '').trim().length >= 50) score += 15;
    if ((leadershipProfile ?? '').trim().length >= 40) score += 10;
    if ((projectIdeas ?? '').trim().length >= 40) score += 10;
    if ((department ?? '').trim().isNotEmpty) score += 10;
    if ((phone ?? '').trim().isNotEmpty) score += 5;

    final level = (studyLevel ?? '').toLowerCase();
    if (level.contains('dic1') ||
        level.contains('l1') ||
        level.contains('1ere') ||
        level.contains('1Ã¨re') ||
        level.contains('premi')) {
      score += 15;
    } else if (level.contains('dic2') ||
        level.contains('l2') ||
        level.contains('deux')) {
      score += 10;
    } else if (level.trim().isNotEmpty) {
      score += 5;
    }

    return score.clamp(0, 100);
  }

  String get screeningLabel {
    final score = screeningScore;
    if (score >= 75) return 'Priorité forte';
    if (score >= 55) return 'Bon potentiel';
    if (score >= 35) return 'À creuser';
    return 'Dossier incomplet';
  }

  bool get isConverted {
    return convertedUserId != null && convertedUserId!.isNotEmpty;
  }

  String get interviewLabel {
    if (interviewAt == null) return 'Entretien à programmer';
    final local = interviewAt!.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}
