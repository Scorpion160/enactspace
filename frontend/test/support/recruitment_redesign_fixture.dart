// Fictitious, in-memory data only. Never contacts an API or sends notifications.
import 'dart:convert';
import 'dart:io';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/models/application_review_model.dart';
import 'package:frontend/features/recruitment/models/application_tracking_model.dart';
import 'package:frontend/features/recruitment/models/recruitment_campaign_model.dart';
import 'package:frontend/features/recruitment/models/recruitment_question_model.dart';
import 'package:frontend/features/recruitment/services/internal_recruitment_gateway.dart';
import 'package:frontend/features/recruitment/services/public_recruitment_gateway.dart';
import 'package:frontend/features/recruitment/services/recruitment_campaign_tools.dart';

const redesignDescription =
    'Tu as des idées et l’envie de faire bouger les choses ? Rejoins Enactus ESP pour apprendre en équipe, relever des défis et construire des projets utiles avec les communautés. Aucune expérience associative n’est nécessaire : ta curiosité, ton écoute et ton envie d’agir comptent.\n\nInscriptions du 4 au 8 novembre inclus. Étude des candidatures du 9 au 14 novembre. Entretiens du 16 au 21 novembre : le créneau et le format seront confirmés individuellement. Prépare tes réponses, explique tes disponibilités et retrouve ensuite chaque étape dans le suivi de ta candidature.';
const redesignCampaign = RecruitmentCampaignModel(
  id: 'redesign-fixture',
  title: 'Recrutement Enactus ESP 2026–2027',
  description: redesignDescription,
  startDate: '2026-11-04',
  endDate: '2026-11-08',
  isActive: true,
  applicationQuestions: [
    RecruitmentApplicationQuestion(
      id: 'motivation',
      label: 'Qu’est-ce qui te motive à rejoindre Enactus ESP ?',
      hint: 'Parle de ce que tu souhaites apprendre et apporter.',
      required: true,
    ),
    RecruitmentApplicationQuestion(
      id: 'community',
      label:
          'Comment écouterais-tu les personnes concernées avant de proposer une solution ?',
      required: true,
    ),
    RecruitmentApplicationQuestion(
      id: 'availability',
      label: 'Quelles sont tes disponibilités pour l’équipe ?',
      section: 'availability',
      required: true,
    ),
  ],
);

Map<String, dynamic> get redesignRubric => Map<String, dynamic>.from(
  jsonDecode(
        File(
          '../backend/app/services/recruitment_rubric.json',
        ).readAsStringSync(),
      )
      as Map,
);
ApplicationModel redesignCandidate({
  String id = 'fixture-1',
  String firstName = 'Awa',
  String lastName = 'Diop',
  String status = 'under_review',
  bool anonymous = false,
  bool scheduled = false,
}) => ApplicationModel(
  id: id,
  campaignId: redesignCampaign.id,
  firstName: anonymous ? '' : firstName,
  lastName: anonymous ? '' : lastName,
  email: anonymous ? '' : 'candidate-$id@example.test',
  trackingCode: 'REC-${id.toUpperCase()}',
  status: status,
  department: 'Génie informatique',
  studyLevel: 'DIC2',
  className: '2026–2027',
  gender: 'femme',
  phone: anonymous ? null : '+221000000000',
  campusResident: anonymous ? null : true,
  motivation:
      'Apprendre à construire des solutions utiles avec les communautés et une équipe engagée.',
  availability: 'Pause de midi et deux soirées par semaine.',
  questionnaireAnswers: const [
    {
      'id': 'motivation',
      'question': 'Qu’est-ce qui te motive à rejoindre Enactus ESP ?',
      'answer':
          'Écouter, apprendre ensemble et tester une première action utile.',
    },
  ],
  interviewAt: scheduled ? DateTime.utc(2026, 11, 16, 12, 30) : null,
  interviewEndAt: scheduled ? DateTime.utc(2026, 11, 16, 12, 50) : null,
  interviewMode: scheduled ? 'in_person' : null,
  interviewLocation: scheduled ? 'Salle de réunion ESP' : null,
  interviewTeam: scheduled ? const {'id': 'team-a', 'name': 'Équipe A'} : null,
  screeningRubric: redesignRubric,
  createdAt: '2026-11-04T10:20:00Z',
  isAnonymized: anonymous,
  canConvert: false,
);

class RedesignTools implements RecruitmentCampaignTools {
  bool canManage;
  final members = <Map<String, dynamic>>[
    {
      'id': 'm1',
      'user_id': 'u1',
      'name': 'Aïssatou Exemple',
      'status': 'member',
      'active': true,
      'appointed': true,
    },
    {
      'id': 'm2',
      'user_id': 'u2',
      'name': 'Moussa Exemple',
      'status': 'alumni',
      'active': true,
      'appointed': true,
    },
  ];
  RedesignTools({this.canManage = true});
  @override
  Future<Map<String, dynamic>> loadAccess() async => {
    'can_manage_campaigns': canManage,
  };
  @override
  Future<Map<String, dynamic>> loadJury(String campaignId) async => {
    'can_manage': canManage,
    'members': members,
    'teams': [
      {
        'id': 'team-a',
        'name': 'Équipe A',
        'revision': 1,
        'active': true,
        'available': true,
        'members': members,
        'interviews': <Map<String, dynamic>>[],
      },
    ],
    'interviews_needing_reassignment': <Map<String, dynamic>>[],
  };
  @override
  Future<List<Map<String, dynamic>>> eligibleJury(
    String campaignId,
    String search,
  ) async => [
    {'id': 'u3', 'name': 'Fatou Exemple', 'status': 'alumni'},
  ];
  @override
  Future<Map<String, dynamic>> loadPersonality(String applicationId) async => {
    'status': 'not_invited',
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected mutation in UI fixture: ${invocation.memberName}',
  );
}

class RedesignGateway
    implements InternalRecruitmentGateway, CampaignToolsProvider {
  @override
  final RedesignTools campaignTools;
  List<ApplicationModel> applications;
  List<RecruitmentCampaignModel> campaigns;
  List<Map<String, dynamic>>? savedQuestions;
  int writes = 0;
  RedesignGateway({
    bool canManage = true,
    List<ApplicationModel>? applications,
    List<RecruitmentCampaignModel>? campaigns,
  }) : campaignTools = RedesignTools(canManage: canManage),
       applications =
           applications ??
           [
             redesignCandidate(),
             redesignCandidate(
               id: 'fixture-2',
               firstName: 'Moussa',
               lastName: 'Ba',
               status: 'interview_scheduled',
               scheduled: true,
             ),
           ],
       campaigns = campaigns ?? [redesignCampaign];
  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() async =>
      List.of(campaigns);
  @override
  Future<List<ApplicationModel>> loadApplications() async =>
      List.of(applications);
  @override
  Future<ApplicationModel> loadApplication(
    String applicationId, {
    bool anonymized = false,
  }) async => anonymized
      ? redesignCandidate(id: applicationId, anonymous: true)
      : applications.firstWhere((a) => a.id == applicationId);
  @override
  Future<List<ApplicationReviewModel>> loadReviews(
    String applicationId,
  ) async => [];
  @override
  Future<RecruitmentCampaignModel> createCampaign({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<Map<String, dynamic>>? applicationQuestions,
    bool isActive = false,
  }) async {
    writes++;
    savedQuestions = applicationQuestions;
    final result = RecruitmentCampaignModel(
      id: 'created-fixture',
      title: title,
      description: description,
      startDate: startDate?.toIso8601String(),
      endDate: endDate?.toIso8601String(),
      isActive: isActive,
      applicationQuestions:
          applicationQuestions
              ?.map(RecruitmentApplicationQuestion.fromJson)
              .toList() ??
          defaultRecruitmentQuestions,
    );
    campaigns = [...campaigns, result];
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected mutation in UI fixture: ${invocation.memberName}',
  );
}

class RedesignPublicGateway implements PublicRecruitmentGateway {
  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() async => [
    redesignCampaign,
  ];
  @override
  Future<ApplicationTrackingModel> trackApplication({
    required String code,
    required String email,
  }) async => ApplicationTrackingModel.fromJson({
    'application_id': 'fixture-1',
    'tracking_code': code,
    'email': email,
    'campaign_title': redesignCampaign.title,
    'first_name': 'Awa',
    'last_name': 'Exemple',
    'status': 'interview_scheduled',
    'submitted_at': '2026-11-04T10:20:00Z',
    'next_step': 'Ton entretien est prévu le 16 novembre à 12 h 30 à Dakar.',
    'interview_details': 'Salle de réunion ESP · Présentiel',
    'candidate_message':
        'Merci pour ton engagement. Prépare une idée et tes questions pour notre rencontre.',
  });
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('No submissions from visual previews');
}
