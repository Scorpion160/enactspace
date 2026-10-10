import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../members/models/member_model.dart';

class MyProfileService {
  final ApiClient _apiClient;
  final AuthService _authService;

  MyProfileService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<MemberModel> load() async {
    final data = await _authService.getCurrentUser();
    return MemberModel.fromJson(data);
  }

  Future<MemberModel> uploadPhoto({
    required List<int> bytes,
    required String fileName,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Utilisateur non connecté.');
    }
    final response = await _apiClient.postMultipart(
      '/users/me/photo',
      token: token,
      bytes: bytes,
      fileName: fileName,
    );
    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse invalide lors de l’envoi de la photo.');
    }
    return MemberModel.fromJson(response);
  }

  Future<MemberModel> deletePhoto() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Utilisateur non connecté.');
    }
    final response = await _apiClient.delete('/users/me/photo', token: token);
    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse invalide lors de la suppression de la photo.');
    }
    return MemberModel.fromJson(response);
  }

  Future<MemberModel> update({
    required String firstName,
    required String lastName,
    String? phone,
    String? photoUrl,
    String? department,
    String? cursus,
    String? studyLevel,
    String? specialty,
    String? promotion,
    String? bio,
    String? linkedinUrl,
    String? githubUrl,
    String? portfolioUrl,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Utilisateur non connecté.');
    }
    await _apiClient.patchJson(
      '/users/me',
      token: token,
      data: {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone': _nullable(phone),
        'photo_url': _nullable(photoUrl),
        'department': _nullable(department),
        'cursus': _nullable(cursus),
        'study_level': _nullable(studyLevel),
        'specialty': _nullable(specialty),
        'promotion': _nullable(promotion),
        'bio': _nullable(bio),
        'linkedin_url': _nullable(linkedinUrl),
        'github_url': _nullable(githubUrl),
        'portfolio_url': _nullable(portfolioUrl),
      },
    );
    final refreshed = await _authService.getCurrentUser();
    return MemberModel.fromJson(refreshed);
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
