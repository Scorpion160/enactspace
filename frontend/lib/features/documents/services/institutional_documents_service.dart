import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/institutional_document_models.dart';

class InstitutionalDocumentsService {
  final ApiClient _apiClient;
  final AuthService _authService;

  InstitutionalDocumentsService({
    ApiClient? apiClient,
    AuthService? authService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _authService = authService ?? AuthService();

  Future<List<InstitutionalTemplateModel>> getTemplates() async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/institutional-documents/templates',
      token: token,
    );
    return _extractList(response)
        .whereType<Map>()
        .map(
          (item) => InstitutionalTemplateModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<InstitutionalDocumentRequestModel>> getRequests({
    String? status,
    String? templateCode,
  }) async {
    final token = await _requireToken();
    final params = <String, String>{};
    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
    if (templateCode != null &&
        templateCode.isNotEmpty &&
        templateCode != 'all') {
      params['template_code'] = templateCode;
    }
    final query = params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    final response = await _apiClient.get(
      query.isEmpty
          ? '/institutional-documents/requests'
          : '/institutional-documents/requests?$query',
      token: token,
    );
    return _extractList(response)
        .whereType<Map>()
        .map(
          (item) => InstitutionalDocumentRequestModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<InstitutionalDocumentRequestModel> getRequest(String requestId) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/institutional-documents/requests/$requestId',
      token: token,
    );
    return _requestFrom(response);
  }

  Future<InstitutionalDocumentRequestModel> createRequest({
    required String templateCode,
    required Map<String, dynamic> payload,
    String? poleId,
    String? projectId,
    String? eventId,
    String? seasonId,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/institutional-documents/requests',
      token: token,
      data: {
        'template_code': templateCode,
        'payload': payload,
        'pole_id': _nullableId(poleId),
        'project_id': _nullableId(projectId),
        'event_id': _nullableId(eventId),
        'season_id': _nullableId(seasonId),
      },
    );
    return _requestFrom(response);
  }

  Future<InstitutionalDocumentRequestModel> updateRequest({
    required String requestId,
    required Map<String, dynamic> payload,
    String? poleId,
    String? projectId,
    String? eventId,
    String? seasonId,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.patchJson(
      '/institutional-documents/requests/$requestId',
      token: token,
      data: {
        'payload': payload,
        'pole_id': _nullableId(poleId),
        'project_id': _nullableId(projectId),
        'event_id': _nullableId(eventId),
        'season_id': _nullableId(seasonId),
      },
    );
    return _requestFrom(response);
  }

  Future<InstitutionalDocumentRequestModel> submit(String requestId) =>
      _emptyAction(requestId, 'submit');

  Future<InstitutionalDocumentRequestModel> sgValidate(String requestId) =>
      _emptyAction(requestId, 'sg-validate');

  Future<InstitutionalDocumentRequestModel> approve(String requestId) =>
      _emptyAction(requestId, 'approve');

  Future<InstitutionalDocumentRequestModel> reject(
    String requestId,
    String reason,
  ) async {
    if (reason.trim().length < 3) {
      throw ArgumentError('Le motif doit contenir au moins 3 caractères.');
    }
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/institutional-documents/requests/$requestId/reject',
      token: token,
      data: {'reason': reason.trim()},
    );
    return _requestFrom(response);
  }

  Future<InstitutionalDocumentRequestModel> cancel(
    String requestId, {
    String? reason,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/institutional-documents/requests/$requestId/cancel',
      token: token,
      data: {'reason': _nullable(reason)},
    );
    return _requestFrom(response);
  }

  Future<Uint8List> preview(String requestId) async {
    final token = await _requireToken();
    final bytes = await _apiClient.getBytes(
      '${ApiClient.baseUrl}/institutional-documents/requests/$requestId/preview',
      token: token,
    );
    if (bytes.length < 5 ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw Exception('Le serveur n’a pas retourné un aperçu PDF valide.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<InstitutionalGenerationResult> generate(String requestId) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/institutional-documents/requests/$requestId/generate',
      token: token,
      data: const {},
    );
    if (response is Map) {
      return InstitutionalGenerationResult.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    throw Exception('Réponse invalide lors de la génération du PDF.');
  }

  Future<bool> rendererAvailable() async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/institutional-documents/renderer-status',
      token: token,
    );
    return response is Map && response['available'] == true;
  }

  Future<InstitutionalDocumentRequestModel> _emptyAction(
    String requestId,
    String action,
  ) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/institutional-documents/requests/$requestId/$action',
      token: token,
      data: const {},
    );
    return _requestFrom(response);
  }

  InstitutionalDocumentRequestModel _requestFrom(dynamic response) {
    if (response is Map) {
      return InstitutionalDocumentRequestModel.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    throw Exception('Réponse institutionnelle invalide.');
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map && response['items'] is List) {
      return response['items'] as List;
    }
    if (response is Map && response['data'] is List) {
      return response['data'] as List;
    }
    return const [];
  }

  String? _nullableId(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty || normalized == 'all' || normalized == 'none') {
      return null;
    }
    return normalized;
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');
    return token;
  }
}
