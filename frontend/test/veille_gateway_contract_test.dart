import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/features/veille/services/veille_gateway.dart';

class Authenticated extends AuthService {
  final String? token;
  Authenticated([this.token = 'veille-contract-token']);
  @override
  Future<String?> getToken() async => token;
}

class Storage extends AuthStorage {
  @override
  Future<AuthTokens?> readTokenPair() async => null;
}

http.Response jsonResponse(Object value, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
void main() {
  late Map<String, dynamic> fixture;
  setUpAll(() async {
    fixture =
        jsonDecode(
              await File('test/fixtures/veille_contract.json').readAsString(),
            )
            as Map<String, dynamic>;
  });
  test(
    'dashboard gateway loads the actual three envelopes with authorized scope filters',
    () async {
      final requests = <http.Request>[];
      final gateway = ApiVeilleGateway(
        authService: Authenticated(),
        apiClient: ApiClient(
          authStorage: Storage(),
          client: MockClient((request) async {
            requests.add(request);
            final kind = request.url.path.split('/').last;
            return jsonResponse((fixture['bundle'] as Map)[kind]);
          }),
        ),
      );
      final bundle = await gateway.load(
        start: DateTime(2026, 9, 28),
        end: DateTime(2026, 10, 4),
        poleId: 'pole',
        memberId: 'member',
        seasonId: 'season',
      );
      expect(requests.map((r) => r.url.path).toSet(), {
        '/api/veille/context',
        '/api/veille/summary',
        '/api/veille/records',
      });
      final summary = requests.singleWhere(
        (r) => r.url.path.endsWith('/summary'),
      );
      expect(summary.url.queryParameters, {
        'start': '2026-09-28',
        'end': '2026-10-04',
        'pole_id': 'pole',
        'member_id': 'member',
        'season_id': 'season',
      });
      for (final request in requests) {
        expect(
          request.headers['Authorization'],
          'Bearer veille-contract-token',
        );
      }
      expect((bundle['records'] as Map)['plans'], isNotEmpty);
      expect((bundle['context'] as Map)['can_decide'], true);
    },
  );
  test('task and record deep details use the supported routes', () async {
    final paths = <String>[];
    final gateway = ApiVeilleGateway(
      authService: Authenticated(),
      apiClient: ApiClient(
        authStorage: Storage(),
        client: MockClient((r) async {
          paths.add(r.url.path);
          return jsonResponse({'id': 'id'});
        }),
      ),
    );
    await gateway.detail('task', 'id');
    await gateway.detail('case', 'id');
    expect(paths, ['/api/veille/tasks/id', '/api/veille/records/case/id']);
  });
  test(
    'save, relecture, checklist and discussion preserve methods and JSON bodies',
    () async {
      final calls = <http.Request>[];
      final gateway = ApiVeilleGateway(
        authService: Authenticated(),
        apiClient: ApiClient(
          authStorage: Storage(),
          client: MockClient((r) async {
            calls.add(r);
            return jsonResponse({'id': 'saved'});
          }),
        ),
      );
      await gateway.save('/plans', {'title': 'Préparer une immersion'});
      await gateway.save('/plans/id', {'version': 1}, method: 'PATCH');
      await gateway.save('/settings', {'version': 2}, method: 'PUT');
      await gateway.taskStatus('id', 'en_cours');
      await gateway.taskProof('id', 'https://example.test/proof');
      await gateway.taskChecklist('step', true);
      await gateway.taskComment('id', 'Le partenaire a confirmé la rencontre.');
      expect(calls.map((r) => '${r.method} ${r.url.path}').toList(), [
        'POST /api/veille/plans',
        'PATCH /api/veille/plans/id',
        'PUT /api/veille/settings',
        'POST /api/tasks/id/status',
        'POST /api/tasks/id/proof',
        'PATCH /api/tasks/checklist/step',
        'POST /api/tasks/comments',
      ]);
      expect(jsonDecode(calls.first.body)['title'], 'Préparer une immersion');
      expect(jsonDecode(calls[5].body), {'is_done': true});
      expect(jsonDecode(calls.last.body)['task_id'], 'id');
    },
  );
  test('CSV export keeps the UTF-8 BOM and accented characters', () async {
    const content = '\ufeffMembre;Acceptées\nAïta Dia;2\n';
    final gateway = ApiVeilleGateway(
      authService: Authenticated(),
      apiClient: ApiClient(
        authStorage: Storage(),
        client: MockClient(
          (r) async => http.Response.bytes(
            utf8.encode(content),
            200,
            headers: {'content-type': 'text/csv; charset=utf-8'},
          ),
        ),
      ),
    );
    final bytes = await gateway.exportReport('report');
    expect(bytes.take(3).toList(), [0xef, 0xbb, 0xbf]);
    expect(utf8.decode(bytes), content.substring(1));
  });
  test('external proof never receives the session token', () async {
    String? authorization;
    final gateway = ApiVeilleGateway(
      authService: Authenticated(),
      apiClient: ApiClient(
        authStorage: Storage(),
        client: MockClient((r) async {
          authorization = r.headers['Authorization'];
          return http.Response.bytes([1, 2, 3], 200);
        }),
      ),
    );
    expect(await gateway.downloadProof('https://example.test/proof.pdf'), [
      1,
      2,
      3,
    ]);
    expect(authorization, isNull);
  });
  test('missing session blocks the request before network access', () async {
    var count = 0;
    final gateway = ApiVeilleGateway(
      authService: Authenticated(null),
      apiClient: ApiClient(
        authStorage: Storage(),
        client: MockClient((r) async {
          count++;
          return jsonResponse({});
        }),
      ),
    );
    await expectLater(gateway.detail('case', 'id'), throwsException);
    expect(count, 0);
  });
  test(
    'server conflict stays visible and is not replaced by an offline success',
    () async {
      final gateway = ApiVeilleGateway(
        authService: Authenticated(),
        apiClient: ApiClient(
          authStorage: Storage(),
          client: MockClient(
            (r) async => jsonResponse({
              'detail': 'Ce dossier a changé. Actualisez-le.',
            }, 409),
          ),
        ),
      );
      await expectLater(
        gateway.save('/cases/id/actions', {'version': 1}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 409)),
      );
    },
  );
}
