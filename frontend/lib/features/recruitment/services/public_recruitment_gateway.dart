import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;

import '../../../core/api/api_client.dart';
import '../models/application_model.dart';
import '../models/application_tracking_model.dart';
import '../models/public_application_draft.dart';
import '../models/recruitment_campaign_model.dart';
import 'recruitment_service.dart';

enum PublicRecruitmentFailureKind {
  notFound,
  network,
  questionnaireChanged,
  duplicateApplication,
  invalidApplication,
  fileTooLarge,
  campaignClosed,
  rateLimited,
  server,
}

class PublicRecruitmentFailure implements Exception {
  final PublicRecruitmentFailureKind kind;

  const PublicRecruitmentFailure(this.kind);

  String get submissionMessage => switch (kind) {
    PublicRecruitmentFailureKind.duplicateApplication =>
      'Une candidature a déjà été reçue avec cette adresse e-mail pour cette campagne. Consulte ton e-mail de confirmation pour retrouver ton code et suivre son avancement.',
    PublicRecruitmentFailureKind.questionnaireChanged =>
      'Le questionnaire a été mis à jour. Relis les questions avant de confirmer ta candidature.',
    PublicRecruitmentFailureKind.network =>
      'La connexion a été interrompue. Ta saisie et tes documents sont conservés. Vérifie ta connexion puis réessaie.',
    PublicRecruitmentFailureKind.invalidApplication =>
      'Certaines informations ou certains documents ne sont pas acceptés. Vérifie les champs obligatoires et les fichiers joints avant de réessayer.',
    PublicRecruitmentFailureKind.fileTooLarge =>
      'Un document dépasse la taille autorisée. Choisis un fichier plus léger avant de réessayer. Tes autres informations sont conservées.',
    PublicRecruitmentFailureKind.campaignClosed =>
      'Cette campagne est désormais fermée. Consulte les campagnes disponibles pour poursuivre.',
    PublicRecruitmentFailureKind.notFound =>
      'Cette campagne n’est plus disponible. Consulte les campagnes disponibles pour poursuivre.',
    PublicRecruitmentFailureKind.rateLimited =>
      'Plusieurs tentatives ont été effectuées. Patiente quelques instants avant de réessayer. Ta saisie est conservée.',
    PublicRecruitmentFailureKind.server =>
      'Le service n’a pas pu traiter ton envoi. Ta saisie et tes documents sont conservés. Réessaie dans quelques instants.',
  };
}

abstract class PublicRecruitmentGateway {
  Future<List<RecruitmentCampaignModel>> loadCampaigns();

  Future<ApplicationModel> submitApplication(PublicApplicationDraft draft);

  Future<ApplicationTrackingModel> trackApplication({
    required String code,
    required String email,
  });
}

class RecruitmentPublicGateway implements PublicRecruitmentGateway {
  final RecruitmentService _service;

  RecruitmentPublicGateway({RecruitmentService? service})
    : _service = service ?? RecruitmentService();

  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() =>
      _guard(_service.getPublicCampaigns);

  @override
  Future<ApplicationModel> submitApplication(PublicApplicationDraft draft) {
    return _guard(
      () => _service.createApplication(
        campaignId: draft.campaignId,
        questionnaireAnswers: draft.questionnaireAnswers,
        questionnaireVersion: draft.questionnaireVersion,
        firstName: draft.firstName,
        lastName: draft.lastName,
        email: draft.email,
        gender: draft.gender,
        phone: draft.phone,
        department: draft.department,
        studyLevel: draft.studyLevel,
        className: draft.className,
        motivation: draft.motivation,
        knownEnactusFrom: draft.knownEnactusFrom,
        enactusKnowledge: draft.enactusKnowledge,
        otherClubs: draft.otherClubs,
        contribution: draft.contribution,
        projectIdeas: draft.projectIdeas,
        leadershipProfile: draft.leadershipProfile,
        preferredPole: draft.preferredPole,
        projectInterest: draft.projectInterest,
        associativeExperience: draft.associativeExperience,
        availability: draft.availability,
        publicComment: draft.publicComment,
        cvFile: draft.cvFile,
        motivationLetterFile: draft.motivationLetterFile,
        attachmentFile: draft.attachmentFile,
        cvUrl: draft.cvUrl,
        motivationLetterUrl: draft.motivationLetterUrl,
        attachmentUrl: draft.attachmentUrl,
      ),
    );
  }

  @override
  Future<ApplicationTrackingModel> trackApplication({
    required String code,
    required String email,
  }) {
    return _guard(
      () => _service.trackApplication(applicationId: code, email: email),
    );
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (error) {
      final message = error.message.toLowerCase();
      final kind = switch (error.statusCode) {
        409 when message.contains('questionnaire') =>
          PublicRecruitmentFailureKind.questionnaireChanged,
        409
            when message.contains('candidature') &&
                message.contains('existe') =>
          PublicRecruitmentFailureKind.duplicateApplication,
        404 => PublicRecruitmentFailureKind.notFound,
        413 => PublicRecruitmentFailureKind.fileTooLarge,
        422 => PublicRecruitmentFailureKind.invalidApplication,
        400 when message.contains('campagne') && message.contains('ouverte') =>
          PublicRecruitmentFailureKind.campaignClosed,
        400 => PublicRecruitmentFailureKind.invalidApplication,
        429 => PublicRecruitmentFailureKind.rateLimited,
        _ => PublicRecruitmentFailureKind.server,
      };
      throw PublicRecruitmentFailure(kind);
    } on TimeoutException {
      throw const PublicRecruitmentFailure(
        PublicRecruitmentFailureKind.network,
      );
    } on SocketException {
      throw const PublicRecruitmentFailure(
        PublicRecruitmentFailureKind.network,
      );
    } on ClientException {
      throw const PublicRecruitmentFailure(
        PublicRecruitmentFailureKind.network,
      );
    } on PublicRecruitmentFailure {
      rethrow;
    } catch (_) {
      throw const PublicRecruitmentFailure(PublicRecruitmentFailureKind.server);
    }
  }
}
