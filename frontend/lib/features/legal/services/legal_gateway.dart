import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/legal_models.dart';

abstract interface class LegalGateway {
  Future<LegalDocument?> loadPublicDocument(String type);
  Future<LegalDocument?> loadDocumentForAcceptance(LegalStatus status);
  Future<List<LegalStatus>> loadStatus();
  Future<void> accept(LegalStatus status, String source);
}

class ApiLegalGateway implements LegalGateway {
  final ApiClient _api;
  final AuthService _auth;

  ApiLegalGateway({ApiClient? apiClient, AuthService? authService})
    : _api = apiClient ?? ApiClient(),
      _auth = authService ?? AuthService();

  Future<String> _token() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException(statusCode: 401, message: 'Session expirée.');
    }
    return token;
  }

  @override
  Future<LegalDocument?> loadPublicDocument(String type) async {
    try {
      final response = await _api.get('/legal/documents/$type');
      return LegalDocument.fromJson(response as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<LegalDocument?> loadDocumentForAcceptance(LegalStatus status) async {
    final type = Uri.encodeQueryComponent(status.type);
    final response = await _api.get('/legal/documents?document_type=$type');
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(LegalDocument.fromJson)
        .where((document) => document.matchesStatus(status))
        .firstOrNull;
  }

  @override
  Future<List<LegalStatus>> loadStatus() async {
    final response = await _api.get('/legal/status/me', token: await _token());
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(LegalStatus.fromJson)
        .toList();
  }

  @override
  Future<void> accept(LegalStatus status, String source) async {
    await _api.postJson(
      '/legal/acceptances',
      data: {
        'legal_document_id': status.documentId,
        'version': status.version,
        'source': source,
      },
      token: await _token(),
    );
  }
}

String legalAcceptanceSource({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return 'web';
  return switch (platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'api',
  };
}
