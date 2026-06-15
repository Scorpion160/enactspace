import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/application_model.dart';
import '../models/application_review_model.dart';
import '../models/recruitment_campaign_model.dart';

class RecruitmentService {
  final ApiClient _apiClient;
  final AuthService _authService;

  RecruitmentService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<RecruitmentCampaignModel>> getCampaigns() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.get(
      '/recruitment/campaigns',
      token: token,
    );

    final rawList = _extractList(response);

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(RecruitmentCampaignModel.fromJson)
        .toList();
  }

  Future<RecruitmentCampaignModel> createCampaign({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/recruitment/campaigns',
      token: token,
      data: {
        'season_id': null,
        'title': title.trim(),
        'description': description?.trim(),
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
        'is_active': isActive,
      },
    );

    if (response is Map<String, dynamic>) {
      return RecruitmentCampaignModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création de la campagne.');
  }

  Future<List<ApplicationModel>> getApplications({
    String? campaignId,
    String? status,
    String? search,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final params = <String, String>{};

    if (campaignId != null && campaignId.isNotEmpty && campaignId != 'all') {
      params['campaign_id'] = campaignId;
    }

    if (status != null && status.isNotEmpty && status != 'all') {
      params['status_filter'] = status;
    }

    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    final path = query.isEmpty
        ? '/recruitment/applications'
        : '/recruitment/applications?$query';

    final response = await _apiClient.get(path, token: token);

    final rawList = _extractList(response);

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(ApplicationModel.fromJson)
        .toList();
  }

  Future<ApplicationModel> createApplication({
    required String campaignId,
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
    String? department,
    String? studyLevel,
    String? motivation,
    String? knownEnactusFrom,
    String? enactusKnowledge,
    String? otherClubs,
    String? contribution,
    String? projectIdeas,
    String? leadershipProfile,
    String? cvUrl,
    String? motivationLetterUrl,
  }) async {
    final response = await _apiClient.postJson(
      '/recruitment/applications',
      data: {
        'campaign_id': campaignId,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim(),
        'phone': _nullIfEmpty(phone),
        'department': _nullIfEmpty(department),
        'study_level': _nullIfEmpty(studyLevel),
        'motivation': _nullIfEmpty(motivation),
        'known_enactus_from': _nullIfEmpty(knownEnactusFrom),
        'enactus_knowledge': _nullIfEmpty(enactusKnowledge),
        'other_clubs': _nullIfEmpty(otherClubs),
        'contribution': _nullIfEmpty(contribution),
        'project_ideas': _nullIfEmpty(projectIdeas),
        'leadership_profile': _nullIfEmpty(leadershipProfile),
        'cv_url': _nullIfEmpty(cvUrl),
        'motivation_letter_url': _nullIfEmpty(motivationLetterUrl),
      },
    );

    if (response is Map<String, dynamic>) {
      return ApplicationModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création de la candidature.');
  }

  Future<ApplicationModel> changeApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/recruitment/applications/$applicationId/status',
      token: token,
      data: {'status': status},
    );

    if (response is Map<String, dynamic>) {
      return ApplicationModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors du changement de statut.');
  }

  Future<ApplicationReviewModel> createReview({
    required String applicationId,
    required double score,
    String? comment,
    String recommendation = 'reserve',
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/recruitment/reviews',
      token: token,
      data: {
        'application_id': applicationId,
        'score': score,
        'comment': _nullIfEmpty(comment),
        'recommendation': recommendation,
      },
    );

    if (response is Map<String, dynamic>) {
      return ApplicationReviewModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’évaluation.');
  }

  Future<Map<String, dynamic>> convertToUser({
    required String applicationId,
    required String password,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/recruitment/applications/$applicationId/convert-to-user',
      token: token,
      data: {'password': password},
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception('Réponse invalide lors de la conversion en membre.');
  }

  Future<bool> prepareOnboardingAcademyPath({
    required String applicationId,
    required String userId,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connectÃ©.');

    try {
      await _apiClient.postJson(
        '/academy/onboarding/assign',
        token: token,
        data: {
          'application_id': applicationId,
          'user_id': userId,
          'path_id': 'onboarding',
          'notify_user': true,
          'send_email_if_available': true,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map && response['data'] is List) {
      return response['data'] as List;
    }
    if (response is Map && response['items'] is List) {
      return response['items'] as List;
    }
    return [];
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
