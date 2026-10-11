import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/storage/secure_storage_options.dart';
import '../../../core/storage/session_private_data.dart';
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

abstract interface class DocumentOfflineCacheStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureDocumentOfflineCacheStore implements DocumentOfflineCacheStore {
  final FlutterSecureStorage _storage;

  const SecureDocumentOfflineCacheStore({
    this._storage = enactSpaceSecureStorage,
  });

  @override
  Future<String?> read() => _storage.read(key: documentOfflineCacheSecureKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: documentOfflineCacheSecureKey, value: value);

  @override
  Future<void> delete() => _storage.delete(key: documentOfflineCacheSecureKey);
}

class DocumentsService {
  final ApiClient _apiClient;
  final AuthService _authService;
  final DocumentOfflineCacheStore _offlineCache;

  bool lastLoadUsedOfflineCache = false;

  DocumentsService({
    ApiClient? apiClient,
    AuthService? authService,
    DocumentOfflineCacheStore? offlineCache,
  }) : _apiClient = apiClient ?? ApiClient(),
       _authService = authService ?? AuthService(),
       _offlineCache = offlineCache ?? const SecureDocumentOfflineCacheStore();

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
    lastLoadUsedOfflineCache = false;
    try {
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
      if (isTemplate != null) params['is_template'] = isTemplate.toString();
      if (isOfficial != null) params['is_official'] = isOfficial.toString();

      final query = params.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&');
      final path = query.isEmpty ? '/documents/' : '/documents/?$query';
      final response = await _apiClient.get(path, token: token);
      final documents = _extractList(
        response,
      ).whereType<Map<String, dynamic>>().map(DocumentModel.fromJson).toList();

      if (_isUnfiltered(
        search: search,
        category: category,
        visibility: visibility,
        status: status,
        poleId: poleId,
        projectId: projectId,
        eventId: eventId,
        isTemplate: isTemplate,
        isOfficial: isOfficial,
      )) {
        await _writeOfflineCache(documents);
      }
      return documents;
    } catch (_) {
      final cached = await _readOfflineCache();
      if (cached == null) rethrow;
      lastLoadUsedOfflineCache = true;
      return _filterOffline(
        cached,
        search: search,
        category: category,
        visibility: visibility,
        status: status,
        poleId: poleId,
        projectId: projectId,
        eventId: eventId,
        isTemplate: isTemplate,
        isOfficial: isOfficial,
      );
    }
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
    try {
      final token = await _requireToken();
      final response = await _apiClient.get(
        '/documents/$documentId',
        token: token,
      );
      if (response is Map<String, dynamic>) {
        return DocumentModel.fromJson(response);
      }
      throw Exception('Document introuvable.');
    } catch (_) {
      final cached = await _readOfflineCache();
      if (cached == null) rethrow;
      final match = cached.where((item) => item.id == documentId).firstOrNull;
      if (match != null) {
        lastLoadUsedOfflineCache = true;
        return match;
      }
      rethrow;
    }
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
    if (token == null) throw Exception('Utilisateur non connecté.');

    final body = await _apiClient.postMultipart(
      '/files/upload',
      token: token,
      bytes: bytes,
      fileName: fileName,
      fields: {
        'storage_scope': 'document',
        'visibility': visibility,
        'is_temporary': 'true',
      },
    );
    if (body is Map<String, dynamic>) {
      return DocumentUploadedFileModel.fromJson(body);
    }
    throw Exception('Réponse invalide lors de l’upload du fichier.');
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
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/documents/$documentId/reject',
      token: token,
      data: {'reason': reason.trim()},
    );

    if (response is Map<String, dynamic>) {
      return DocumentModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors du rejet du document.');
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

  Future<void> _writeOfflineCache(List<DocumentModel> documents) async {
    final payload = {
      'version': 1,
      'cached_at': DateTime.now().toUtc().toIso8601String(),
      'documents': documents
          .map((item) => item.toJson(includeCapabilities: false))
          .toList(),
    };
    try {
      await _offlineCache.write(jsonEncode(payload));
    } catch (_) {
      // A secure-storage failure must never block the online document center.
    }
  }

  Future<List<DocumentModel>?> _readOfflineCache() async {
    try {
      final raw = await _offlineCache.read();
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        await _offlineCache.delete();
        return null;
      }
      final items = decoded['documents'];
      if (items is! List) {
        await _offlineCache.delete();
        return null;
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(DocumentModel.fromJson)
          .toList();
    } catch (_) {
      try {
        await _offlineCache.delete();
      } catch (_) {}
      return null;
    }
  }

  bool _isUnfiltered({
    String? search,
    String? category,
    String? visibility,
    String? status,
    String? poleId,
    String? projectId,
    String? eventId,
    bool? isTemplate,
    bool? isOfficial,
  }) =>
      (search == null || search.trim().isEmpty) &&
      (category == null || category.isEmpty || category == 'all') &&
      (visibility == null || visibility.isEmpty || visibility == 'all') &&
      (status == null || status.isEmpty || status == 'all') &&
      (poleId == null || poleId.isEmpty || poleId == 'all') &&
      (projectId == null || projectId.isEmpty || projectId == 'all') &&
      (eventId == null || eventId.isEmpty || eventId == 'all') &&
      isTemplate == null &&
      isOfficial == null;

  List<DocumentModel> _filterOffline(
    List<DocumentModel> documents, {
    String? search,
    String? category,
    String? visibility,
    String? status,
    String? poleId,
    String? projectId,
    String? eventId,
    bool? isTemplate,
    bool? isOfficial,
  }) {
    final query = search?.trim().toLowerCase() ?? '';
    return documents.where((item) {
      final searchable = [
        item.title,
        item.description ?? '',
        item.categoryLabel,
        item.fileTypeLabel,
      ].join(' ').toLowerCase();
      return (query.isEmpty || searchable.contains(query)) &&
          (category == null ||
              category.isEmpty ||
              category == 'all' ||
              item.category == category) &&
          (visibility == null ||
              visibility.isEmpty ||
              visibility == 'all' ||
              item.visibility == visibility) &&
          (status == null ||
              status.isEmpty ||
              status == 'all' ||
              item.status == status) &&
          (poleId == null ||
              poleId.isEmpty ||
              poleId == 'all' ||
              item.poleId == poleId) &&
          (projectId == null ||
              projectId.isEmpty ||
              projectId == 'all' ||
              item.projectId == projectId) &&
          (eventId == null ||
              eventId.isEmpty ||
              eventId == 'all' ||
              item.eventId == eventId) &&
          (isTemplate == null || item.isTemplate == isTemplate) &&
          (isOfficial == null || item.isOfficial == isOfficial);
    }).toList();
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
