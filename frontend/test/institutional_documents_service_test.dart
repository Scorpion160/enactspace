import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/features/documents/services/institutional_documents_service.dart';

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<InstitutionalDocumentsService> serviceWith(
    Future<http.Response> Function(http.Request request) handler,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(secureStore: _MemorySecureStore());
    await storage.writeTokenPair(
      const AuthTokens(
        accessToken: 'preview-access-token',
        refreshToken: 'preview-refresh-token',
      ),
    );
    final api = ApiClient(
      client: MockClient(handler),
      authStorage: storage,
    );
    final auth = AuthService(apiClient: api, authStorage: storage);
    return InstitutionalDocumentsService(
      apiClient: api,
      authService: auth,
    );
  }

  test('preview downloads PDF bytes with the authenticated API client', () async {
    final pdf = utf8.encode('%PDF-1.7\npreview');
    final service = await serviceWith((request) async {
      expect(
        request.url.path,
        '/api/institutional-documents/requests/request-1/preview',
      );
      expect(
        request.headers['authorization'],
        'Bearer preview-access-token',
      );
      return http.Response.bytes(
        pdf,
        200,
        headers: {'content-type': 'application/pdf'},
      );
    });

    expect(await service.preview('request-1'), pdf);
  });

  test('preview rejects a non-PDF response even when HTTP succeeds', () async {
    final service = await serviceWith((request) async {
      expect(
        request.headers['authorization'],
        'Bearer preview-access-token',
      );
      return http.Response.bytes(
        utf8.encode('not-a-pdf'),
        200,
        headers: {'content-type': 'application/octet-stream'},
      );
    });

    await expectLater(service.preview('request-2'), throwsException);
  });
}
