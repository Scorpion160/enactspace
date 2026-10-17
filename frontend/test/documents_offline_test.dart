import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/core/storage/session_private_data.dart';
import 'package:frontend/features/documents/services/documents_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'documents garde une copie s?curis?e et filtre hors connexion',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secure = _MemorySecureStore();
      final storage = AuthStorage(secureStore: secure);
      await storage.writeTokenPair(
        const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      );
      var online = true;
      final api = ApiClient(
        authStorage: storage,
        client: MockClient((request) async {
          if (!online) throw http.ClientException('offline');
          expect(request.url.path, '/api/documents/');
          return http.Response(
            jsonEncode([
              {
                'id': 'doc-1',
                'title': 'PV r?union g?n?rale',
                'description': 'Compte rendu',
                'file_url': 'https://example.test/pv.pdf',
                'file_type': 'pdf',
                'status': 'validated',
                'category': 'pv',
                'visibility': 'internal',
                'is_template': false,
                'is_official': true,
                'can_manage': true,
                'can_validate': true,
                'is_permanent': true,
              },
              {
                'id': 'doc-2',
                'title': 'Budget projet',
                'status': 'validated',
                'category': 'budget',
                'visibility': 'internal',
                'is_template': false,
                'is_official': false,
                'can_manage': true,
                'can_validate': false,
                'is_permanent': true,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final cache = _MemoryDocumentCache();
      final service = DocumentsService(
        apiClient: api,
        authService: AuthService(apiClient: api, authStorage: storage),
        offlineCache: cache,
      );

      final onlineDocuments = await service.getDocuments();
      expect(onlineDocuments, hasLength(2));
      expect(service.lastLoadUsedOfflineCache, isFalse);
      expect(cache.value, isNotNull);

      online = false;
      final offline = await service.getDocuments(
        search: 'r?union',
        category: 'pv',
        isOfficial: true,
      );
      expect(service.lastLoadUsedOfflineCache, isTrue);
      expect(offline, hasLength(1));
      expect(offline.single.id, 'doc-1');
      expect(offline.single.canManage, isFalse);
      expect(offline.single.canValidate, isFalse);

      final detail = await service.getDocument('doc-1');
      expect(detail.title, 'PV r?union g?n?rale');
      expect(service.lastLoadUsedOfflineCache, isTrue);
    },
  );

  test(
    'changement ou fin de session efface le cache documents priv?',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secure = _MemorySecureStore();
      final storage = AuthStorage(secureStore: secure);
      await storage.writeTokenPair(
        const AuthTokens(accessToken: 'first', refreshToken: 'first-refresh'),
      );
      secure.values[documentOfflineCacheSecureKey] =
          'private-document-metadata';

      await storage.writeTokenPair(
        const AuthTokens(accessToken: 'second', refreshToken: 'second-refresh'),
      );
      expect(secure.values[documentOfflineCacheSecureKey], isNull);

      secure.values[documentOfflineCacheSecureKey] =
          'private-document-metadata';
      await storage.clearAuthSecrets();
      expect(secure.values[documentOfflineCacheSecureKey], isNull);
    },
  );
}

class _MemoryDocumentCache implements DocumentOfflineCacheStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
