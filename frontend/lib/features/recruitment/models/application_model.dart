import 'application_review_model.dart';
import 'application_status_presentation.dart';
import 'application_history_model.dart';

class ApplicationModel {
  final List<ApplicationHistoryModel> history;
  final List<Map<String, dynamic>> questionnaireAnswers;
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
  final double? humanScreeningScore;
  final int screeningReviewCount;
  final double? screeningSpread;
  final Map<String, dynamic>? screeningRubric;
  final ApplicationReviewModel? myReview;
  final String? convertedUserId;
  final String? createdAt;
  final String? updatedAt;
  final bool isAnonymized;
  final String? serverAnonymousCode;
  final bool canConvert;

  const ApplicationModel({
    this.history = const [],
    this.questionnaireAnswers = const [],
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
    this.humanScreeningScore,
    this.screeningReviewCount = 0,
    this.screeningSpread,
    this.screeningRubric,
    this.myReview,
    this.convertedUserId,
    this.createdAt,
    this.updatedAt,
    required this.isAnonymized,
    this.serverAnonymousCode,
    required this.canConvert,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    return ApplicationModel(
      history: (json['history'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (row) => ApplicationHistoryModel.tryParse(
              Map<String, dynamic>.from(row),
            ),
          )
          .whereType<ApplicationHistoryModel>()
          .toList(),
      questionnaireAnswers: (json['questionnaire_answers'] as List? ?? const [])
          .whereType<Map>()
          .map((q) => Map<String, dynamic>.from(q))
          .toList(),
      myReview: json['my_review'] is Map
          ? ApplicationReviewModel.fromJson(
              Map<String, dynamic>.from(json['my_review']),
            )
          : null,
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
      humanScreeningScore: double.tryParse(
        json['screening_score']?.toString() ?? '',
      ),
      screeningReviewCount:
          (json['screening_review_count'] as num?)?.toInt() ?? 0,
      screeningSpread: double.tryParse(
        json['screening_spread']?.toString() ?? '',
      ),
      screeningRubric: json['screening_rubric'] is Map
          ? Map<String, dynamic>.from(json['screening_rubric'])
          : null,
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

  String get statusLabel =>
      ApplicationStatusPresentation.fromStatus(status).title;

  String get scoreLabel {
    if (screeningScore != null) {
      return '${(screeningScore! / 5).toStringAsFixed(1)}/20';
    }
    if (finalScore == null) return 'Non évalué';
    return 'Note antérieure : ${finalScore!.toStringAsFixed(1)}/20';
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

  double? get screeningScore => humanScreeningScore;
  String get screeningLabel {
    if (screeningScore == null) return 'Évaluation à réaliser';
    if (screeningReviewCount < 2) return 'Un avis à croiser';
    if ((screeningSpread ?? 0) >= 20) return 'Écart à discuter en jury';
    return 'Avis du jury enregistrés';
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
