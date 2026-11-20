import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/features/help/services/help_gateway.dart';

class TokenAuth extends AuthService {
  final String? token;
  TokenAuth(this.token);
  @override
  Future<String?> getToken() async => token;
}

http.Response response(Map<String, dynamic> value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthStorage storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = AuthStorage(secureStore: MemoryStore());
    await storage.writeTokenPair(
      const AuthTokens(
        accessToken: 'synthetic-access',
        refreshToken: 'synthetic-refresh',
      ),
    );
  });
  test(
    'ticket and reply preserve retry identifiers on personal endpoints',
    () async {
      final calls = <http.Request>[];
      final api = ApiClient(
        authStorage: storage,
        client: MockClient((request) async {
          calls.add(request);
          return response({
            'id': 'ticket',
            'created_at': '2026-10-07T12:00:00',
          });
        }),
      );
      final gateway = ApiHelpGateway(
        apiClient: api,
        authService: TokenAuth('synthetic-access'),
      );
      await gateway.createTicket(
        subject: 'Accès',
        category: 'technical',
        priority: 'normal',
        message: 'Mon quiz ne répond pas',
        clientRequestId: 'ceab70f7-46a6-47f6-a20f-e2c2bc3201ad',
      );
      await gateway.replyToTicket(
        'ticket',
        'Une précision',
        clientRequestId: '232e7e43-5cd3-40eb-9fdd-e0d66bf6e405',
      );
      expect(calls.map((request) => request.url.path), [
        '/api/support/tickets',
        '/api/support/tickets/ticket/messages',
      ]);
      expect(
        calls.every(
          (request) =>
              request.headers['authorization'] == 'Bearer synthetic-access',
        ),
        isTrue,
      );
      expect(
        jsonDecode(calls.first.body)['client_request_id'],
        'ceab70f7-46a6-47f6-a20f-e2c2bc3201ad',
      );
      expect(
        jsonDecode(calls.last.body)['client_request_id'],
        '232e7e43-5cd3-40eb-9fdd-e0d66bf6e405',
      );
    },
  );
  test(
    'feedback optional metadata is serialized while member response ignores private notes',
    () async {
      late http.Request call;
      final gateway = ApiHelpGateway(
        authService: TokenAuth('synthetic-access'),
        apiClient: ApiClient(
          authStorage: storage,
          client: MockClient((request) async {
            call = request;
            return response({
              'id': 'feedback',
              'message': 'Suggestion',
              'status': 'reviewed',
              'public_reply': 'Merci',
              'admin_note': 'Private staff diagnosis',
            });
          }),
        ),
      );
      final result = await gateway.createFeedback(
        category: 'idea',
        message: 'Suggestion',
        platform: 'android',
        appVersion: '1.0.0',
        buildNumber: 14,
        clientRequestId: 'ceab70f7-46a6-47f6-a20f-e2c2bc3201ad',
      );
      final body = jsonDecode(call.body) as Map;
      expect(call.url.path, '/api/feedback');
      expect(body['platform'], 'android');
      expect(body['build_number'], 14);
      expect(body['app_version'], '1.0.0');
      expect(body.containsKey('rating'), isFalse);
      expect(body.containsKey('admin_note'), isFalse);
      expect(result.publicReply, 'Merci');
      expect(result.statusLabel, 'Étudié');
    },
  );
  test(
    'triage sends expected UTC revision and separates visible response from internal note',
    () async {
      final calls = <http.Request>[];
      final gateway = ApiHelpGateway(
        authService: TokenAuth('synthetic-access'),
        apiClient: ApiClient(
          authStorage: storage,
          client: MockClient((request) async {
            calls.add(request);
            return response({
              'id': 'feedback',
              'updated_at': '2026-10-07T12:00:00',
              'public_reply': 'Réponse membre',
              'admin_note': 'Diagnostic interne',
            });
          }),
        ),
      );
      final expected = DateTime.utc(2026, 10, 7, 12);
      await gateway.manageTicket(
        'ticket',
        assignedToId: 'staff',
        updateAssignment: true,
        expectedUpdatedAt: expected,
      );
      final result = await gateway.manageFeedback(
        'feedback',
        status: 'reviewed',
        publicReply: 'Réponse membre',
        adminNote: 'Diagnostic interne',
        expectedUpdatedAt: expected,
      );
      expect(calls.map((request) => request.url.path), [
        '/api/admin/support/tickets/ticket',
        '/api/admin/feedback/feedback',
      ]);
      expect(calls.every((request) => request.method == 'PATCH'), isTrue);
      expect(jsonDecode(calls.first.body)['assigned_to_id'], 'staff');
      expect(
        jsonDecode(calls.last.body)['expected_updated_at'],
        '2026-10-07T12:00:00.000Z',
      );
      expect(result.feedback.publicReply, 'Réponse membre');
      expect(result.adminNote, 'Diagnostic interne');
      expect(result.feedback.updatedAt, expected);
    },
  );
  test('missing session cannot submit a request to the server', () async {
    int calls = 0;
    final gateway = ApiHelpGateway(
      authService: TokenAuth(null),
      apiClient: ApiClient(
        authStorage: storage,
        client: MockClient((request) async {
          calls++;
          return response({});
        }),
      ),
    );
    await expectLater(
      gateway.loadTickets(),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 401),
      ),
    );
    expect(calls, 0);
  });
}

class MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};
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
