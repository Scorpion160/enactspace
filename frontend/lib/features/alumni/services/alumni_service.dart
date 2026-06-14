import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/alumni_profile_model.dart';
import '../models/mentorship_model.dart';

class AlumniService {
  final ApiClient _apiClient;
  final AuthService _authService;

  AlumniService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<AlumniProfileModel>> getProfiles({
    String? search,
    String? domain,
    bool? availableForMentoring,
  }) async {
    final token = await _requireToken();
    final params = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (domain != null && domain.trim().isNotEmpty) {
      params['domain'] = domain.trim();
    }
    if (availableForMentoring != null) {
      params['available_for_mentoring'] = availableForMentoring.toString();
    }

    final response = await _apiClient.get(
      _withQuery('/alumni/profiles', params),
      token: token,
    );

    return _extractList(response)
        .whereType<Map<String, dynamic>>()
        .map(AlumniProfileModel.fromJson)
        .toList();
  }

  Future<AlumniProfileModel> createProfile({
    required String userId,
    int? graduationYear,
    required String currentCompany,
    required String currentPosition,
    required String domain,
    required String skills,
    required String experienceSummary,
    required bool availableForMentoring,
    required String linkedinUrl,
    required String portfolioUrl,
    required String visibility,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/alumni/profiles',
      token: token,
      data: {
        'user_id': userId,
        'graduation_year': graduationYear,
        'current_company': _nullable(currentCompany),
        'current_position': _nullable(currentPosition),
        'domain': _nullable(domain),
        'skills': _nullable(skills),
        'experience_summary': _nullable(experienceSummary),
        'available_for_mentoring': availableForMentoring,
        'linkedin_url': _nullable(linkedinUrl),
        'portfolio_url': _nullable(portfolioUrl),
        'visibility': visibility,
      },
    );

    if (response is Map<String, dynamic>) {
      return AlumniProfileModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création du profil alumni.');
  }

  Future<List<MentorshipModel>> getMentorships({String? status}) async {
    final token = await _requireToken();
    final params = <String, String>{};

    if (status != null && status != 'all') {
      params['status_filter'] = status;
    }

    final response = await _apiClient.get(
      _withQuery('/alumni/mentorships', params),
      token: token,
    );

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(MentorshipModel.fromJson).toList();
  }

  Future<MentorshipModel> createMentorship({
    required String alumniId,
    String? projectId,
    String? poleId,
    required String title,
    required String objective,
    required String status,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/alumni/mentorships',
      token: token,
      data: {
        'alumni_id': alumniId,
        'project_id': projectId,
        'pole_id': poleId,
        'title': _nullable(title),
        'objective': _nullable(objective),
        'status': status,
      },
    );

    if (response is Map<String, dynamic>) {
      return MentorshipModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création du mentorat.');
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');
    return token;
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _withQuery(String path, Map<String, String> params) {
    if (params.isEmpty) return path;

    final query = params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    return '$path?$query';
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
}
