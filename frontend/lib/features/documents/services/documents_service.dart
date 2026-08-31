import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/document_model.dart';

class DocumentUploadedFileModel {
  final String fileId;
  final String downloadUrl;
  final String fileName;
  final String? fileType;
  final int sizeBytes;

  const DocumentUploadedFileModel({
    required this.fileId,
    required this.downloadUrl,
    required this.fileName,
    required this.fileType,
    required this.sizeBytes,
  });

  factory DocumentUploadedFileModel.fromJson(Map<String, dynamic> json) {
    return DocumentUploadedFileModel(
      fileId: json['id']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString() ?? '',
      fileName: json['original_filename']?.toString() ?? '',
      fileType: json['extension']?.toString(),
      sizeBytes: int.tryParse(json['file_size']?.toString() ?? '') ?? 0,
    );
  }
}

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
    String? status,
    String? poleId,
    String? projectId,
    String? eventId,
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

    if (status != null && status.isNotEmpty && status != 'all') {
      params['status_filter'] = status;
    }

    if (poleId != null && poleId.isNotEmpty && poleId != 'all') {
      params['pole_id'] = poleId;
    }

    if (projectId != null && projectId.isNotEmpty && projectId != 'all') {
      params['project_id'] = projectId;
    }

    if (eventId != null && eventId.isNotEmpty && eventId != 'all') {
      params['event_id'] = eventId;
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
    String? fileUrl,
    String? fileId,
    String? fileType,
    required String category,
    required String visibility,
    String? poleId,
    String? projectId,
    String? eventId,
    String? seasonId,
    bool isTemplate = false,
  }) async {
    if ((fileUrl?.trim().isEmpty ?? true) && (fileId?.trim().isEmpty ?? true)) {
      throw ArgumentError('Un fichier ou un lien est obligatoire.');
    }
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/documents/',
      token: token,
      data: {
        'title': title.trim(),
        'description': description?.trim(),
        'file_url': _nullableId(fileUrl),
        'file_id': _nullableId(fileId),
        'file_type': fileType?.trim(),
        'category': category,
        'visibility': visibility,
        'pole_id': _nullableId(poleId),
        'project_id': _nullableId(projectId),
        'event_id': _nullableId(eventId),
        'season_id': _nullableId(seasonId),
        'is_template': isTemplate,
      },
    );

    if (response is Map<String, dynamic>) {
      return DocumentModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création du document.');
  }

  Future<DocumentModel> getDocument(String documentId) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/documents/$documentId',
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return DocumentModel.fromJson(response);
    }
    throw Exception('Document introuvable.');
  }

  Future<DocumentModel> updateDocument({
    required String documentId,
    String? title,
    String? description,
    String? fileUrl,
    String? fileId,
    String? fileType,
    String? category,
    String? visibility,
    String? poleId,
    String? projectId,
    String? eventId,
    String? seasonId,
    bool? isTemplate,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.patchJson(
      '/documents/$documentId',
      token: token,
      data: {
        if (title != null) 'title': title.trim(),
        if (description != null) 'description': _nullable(description),
        if (fileUrl != null) 'file_url': _nullableId(fileUrl),
        if (fileId != null) 'file_id': _nullableId(fileId),
        if (fileType != null) 'file_type': _nullable(fileType),
        'category': ?category,
        'visibility': ?visibility,
        if (poleId != null) 'pole_id': _nullableId(poleId),
        if (projectId != null) 'project_id': _nullableId(projectId),
        if (eventId != null) 'event_id': _nullableId(eventId),
        if (seasonId != null) 'season_id': _nullableId(seasonId),
        'is_template': ?isTemplate,
      },
    );
    if (response is Map<String, dynamic>) {
      return DocumentModel.fromJson(response);
    }
    throw Exception('Réponse invalide lors de la modification du document.');
  }

  Future<DocumentModel> submitDocument(String documentId) =>
      _postAction(documentId, 'submit');

  Future<DocumentModel> archiveDocument(String documentId) =>
      _postAction(documentId, 'archive');

  Future<DocumentUploadedFileModel> uploadDocumentFile({
    required String fileName,
    required Uint8List bytes,
    required String visibility,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecte.');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.baseUrl}/files/upload'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    request.fields.addAll({
      'storage_scope': 'document',
      'visibility': visibility,
      'is_temporary': 'true',
    });
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final dynamic body = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : {};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return DocumentUploadedFileModel.fromJson(body);
      }
      throw Exception('Reponse invalide lors de l upload du fichier.');
    }

    if (body is Map<String, dynamic> && body['detail'] != null) {
      throw Exception(body['detail'].toString());
    }
    throw Exception('Erreur serveur ${response.statusCode}');
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

  Future<DocumentModel> rejectDocument({
    required String documentId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Le motif du rejet est obligatoire.');
    }
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecte.');

    final response = await _apiClient.postJson(
      '/documents/$documentId/reject',
      token: token,
      data: {'reason': reason.trim()},
    );

    if (response is Map<String, dynamic>) {
      return DocumentModel.fromJson(response);
    }

    throw Exception('Reponse invalide lors du rejet du document.');
  }

  Future<DocumentModel> _postAction(String documentId, String action) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/documents/$documentId/$action',
      token: token,
      data: {},
    );
    if (response is Map<String, dynamic>) {
      return DocumentModel.fromJson(response);
    }
    throw Exception('Réponse invalide lors de l’action sur le document.');
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

  String? _nullableId(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty || trimmed == 'all' ? null : trimmed;
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');
    return token;
  }
}
