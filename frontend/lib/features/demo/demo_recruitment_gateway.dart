import 'package:flutter/foundation.dart';

import '../recruitment/models/application_model.dart';
import '../recruitment/models/application_tracking_model.dart';
import '../recruitment/models/public_application_draft.dart';
import '../recruitment/models/recruitment_campaign_model.dart';
import '../recruitment/services/public_recruitment_gateway.dart';

/// Used only by the nested public demo router. Never delegates to a service.
class DemoRecruitmentGateway extends ChangeNotifier
    implements PublicRecruitmentGateway {
  static const campaign = RecruitmentCampaignModel(
    id: 'demo-alumni-day',
    title: 'Découvrir Enactus ESP · Campagne de démonstration',
    description: 'Un exemple pour découvrir le parcours de candidature. Aucun recrutement réel n’est annoncé ici.',
    isActive: true,
  );
  static const code = 'DEMO-ALUMNI-2026';
  static const email = 'awa.demo@example.test';
  final statuses = <String, String>{
    'Awa Démo': 'submitted',
    'Moussa Démo': 'under_review',
    'Fatou Démo': 'interview_scheduled',
  };
  static const statusLabels = <String, String>{
    'submitted': 'Candidature reçue',
    'under_review': 'En cours d’étude',
    'interview_scheduled': 'Entretien prévu',
    'waiting_list': 'Liste d’attente',
    'accepted': 'Candidature acceptée',
    'rejected': 'Candidature non retenue',
    'cancelled': 'Candidature annulée',
  };
  ApplicationModel? lastApplication;
  int submissions = 0;

  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() async => const [
    campaign,
  ];

  @override
  Future<ApplicationModel> submitApplication(
    PublicApplicationDraft draft,
  ) async {
    submissions++;
    // Store only the fields needed by the local tracking preview, never files.
    final result = ApplicationModel(
      id: 'demo-application',
      campaignId: campaign.id,
      firstName: draft.firstName,
      lastName: draft.lastName,
      email: draft.email,
      department: draft.department,
      studyLevel: draft.studyLevel,
      className: draft.className,
      knownEnactusFrom: draft.knownEnactusFrom,
      status: 'submitted',
      trackingCode: code,
      isAnonymized: false,
      canConvert: false,
    );
    lastApplication = result;
    statuses['Ma candidature d’essai'] = 'submitted';
    notifyListeners();
    return result;
  }

  void changeStatus(String candidate, String status) {
    if (!statuses.containsKey(candidate) || !statusLabels.containsKey(status))
      return;
    statuses[candidate] = status;
    notifyListeners();
  }

  @override
  Future<ApplicationTrackingModel> trackApplication({
    required String code,
    required String email,
  }) async {
    final expectedEmail =
        lastApplication?.email ?? DemoRecruitmentGateway.email;
    if (code.trim().toUpperCase() != DemoRecruitmentGateway.code ||
        email.trim().toLowerCase() != expectedEmail.trim().toLowerCase()) {
      throw const PublicRecruitmentFailure(
        PublicRecruitmentFailureKind.notFound,
      );
    }
    final status = lastApplication == null
        ? statuses['Awa Démo']!
        : statuses['Ma candidature d’essai']!;
    return ApplicationTrackingModel(
      applicationId: 'demo-application',
      trackingCode: DemoRecruitmentGateway.code,
      campaignTitle: campaign.title,
      firstName: lastApplication?.firstName ?? 'Awa',
      lastName: lastApplication?.lastName ?? 'Démo',
      email: expectedEmail,
      department: lastApplication?.department ?? 'Génie Électrique',
      studyLevel: lastApplication?.studyLevel ?? 'DIC2',
      preferredPole: null,
      projectInterest: null,
      status: status,
      submittedAt: null,
      updatedAt: null,
      nextStep: 'Exemple local : le statut évolue depuis les cartes de démonstration de l’équipe.',
      candidateMessage:
          'Dossier fictif. Aucun e-mail, document ou compte réel n’a été créé.',
      interviewDetails: status == 'interview_scheduled'
          ? 'Entretien fictif : aucune date ni convocation réelle.'
          : null,
      finalResult: status == 'accepted'
          ? 'Acceptation simulée. Aucun accès utilisateur n’est créé.'
          : null,
      accountCreated: false,
    );
  }
}
