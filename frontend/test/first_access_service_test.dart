import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/features/first_access/services/first_access_service.dart';

http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthStorage storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = AuthStorage(secureStore: _MemorySecureStore());
    await storage.writeTokenPair(
      const AuthTokens(
        accessToken: 'existing-access',
        refreshToken: 'existing-refresh',
      ),
    );
  });
  test(
    'activation uses public endpoints without a bearer or automatic new session',
    () async {
      final calls = <http.Request>[];
      final api = ApiClient(
        authStorage: storage,
        client: MockClient((request) async {
          calls.add(request);
          return response({'message': 'Code préparé.'});
        }),
      );
      final service = FirstAccessService(
        apiClient: api,
        authService: AuthService(apiClient: api),
      );
      await service.requestActivation('  member@example.com  ');
      await service.activate(
        'member@example.com',
        '12345678',
        '  My own password 2026  ',
      );
      expect(calls.map((request) => request.url.path), [
        '/api/auth/activation/request',
        '/api/auth/activation/confirm',
      ]);
      expect(
        calls.every((request) => !request.headers.containsKey('authorization')),
        isTrue,
      );
      expect(
        jsonDecode(calls.last.body)['new_password'],
        '  My own password 2026  ',
      );
      expect((await storage.readTokenPair())!.accessToken, 'existing-access');
    },
  );
  test(
    'incomplete cached profile is refreshed before deciding the welcome gate',
    () async {
      var calls = 0;
      final api = ApiClient(
        authStorage: storage,
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/users/me');
          return response({
            'id': 'synthetic',
            'onboarding_required': true,
            'onboarding_completed_at': null,
          });
        }),
      );
      final service = FirstAccessService(
        apiClient: api,
        authService: AuthService(apiClient: api),
      );
      expect(await service.needsOnboarding(), isTrue);
      expect(calls, 1);
    },
  );
  test('completed cached welcome supports subsequent offline access', () async {
    var calls = 0;
    final api = ApiClient(
      authStorage: storage,
      client: MockClient((request) async {
        calls++;
        return response({
          'id': 'synthetic',
          'onboarding_required': false,
          'onboarding_completed_at': '2026-10-07T20:00:00',
        });
      }),
    );
    final auth = AuthService(apiClient: api);
    await auth.getCurrentUser();
    expect(
      await FirstAccessService(
        apiClient: api,
        authService: auth,
      ).needsOnboarding(),
      isFalse,
    );
    expect(calls, 1);
  });
  test(
    'structured errors show a human message and never echo validation inputs',
    () {
      final api = ApiClient(authStorage: storage);
      expect(
        () => api.decodeResponse(
          response({
            'detail': {
              'code': 'onboarding_required',
              'message': 'Complétez votre profil.',
            },
          }, 403),
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Complétez votre profil.',
          ),
        ),
      );
      expect(
        () => api.decodeResponse(
          response({
            'detail': [
              {'input': 'Sensitive password', 'type': 'string_too_short'},
            ],
          }, 422),
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            isNot(contains('Sensitive password')),
          ),
        ),
      );
      expect(
        () => api.decodeResponse(
          response({'detail': 'Database stack trace'}, 500),
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            isNot(contains('Database')),
          ),
        ),
      );
    },
  );
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
