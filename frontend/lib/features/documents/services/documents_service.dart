import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/document_model.dart';

class DocumentsService {
  final ApiClient _apiClient;
  final AuthService _authService;

  DocumentsService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<DocumentModel>> getDocuments({
    String? search,
    String? category,
    String? visibility,
    bool? isTemplate,
    bool? isOfficial,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final params = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    if (category != null && category.isNotEmpty && category != 'all') {
      params['category'] = category;
    }

    if (visibility != null && visibility.isNotEmpty && visibility != 'all') {
      params['visibility'] = visibility;
    }

    if (isTemplate != null) {
      params['is_template'] = isTemplate.toString();
    }

    if (isOfficial != null) {
      params['is_official'] = isOfficial.toString();
    }

    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    final path = query.isEmpty ? '/documents/' : '/documents/?$query';

    final response = await _apiClient.get(path, token: token);

    final rawList = _extractList(response);

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(DocumentModel.fromJson)
        .toList();
  }

  Future<DocumentModel> createDocument({
    required String title,
    String? description,
    required String fileUrl,
    required String fileType,
    required String category,
    required String visibility,
    bool isTemplate = false,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/documents/',
      token: token,
      data: {
        'title': title.trim(),
        'description': description?.trim(),
        'file_url': fileUrl.trim(),
        'file_type': fileType.trim(),
        'category': category,
        'visibility': visibility,
        'pole_id': null,
        'project_id': null,
        'event_id': null,
        'season_id': null,
        'is_template': isTemplate,
      },
    );

    if (response is Map<String, dynamic>) {
      return DocumentModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création du document.');
  }

  Future<DocumentModel> validateDocument(String documentId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/documents/$documentId/validate',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return DocumentModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la validation du document.');
  }

  Future<DocumentModel> unvalidateDocument(String documentId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/documents/$documentId/unvalidate',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return DocumentModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors du retrait de validation.');
  }

  Future<void> deleteDocument(String documentId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    await _apiClient.delete('/documents/$documentId', token: token);
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
