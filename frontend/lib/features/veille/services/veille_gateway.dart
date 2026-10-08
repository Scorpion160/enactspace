import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';

typedef VeilleJson = Map<String, dynamic>;

List<VeilleJson> veilleRows(dynamic value) => value is List
    ? value.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
    : <VeilleJson>[];

abstract interface class VeilleGateway {
  Future<VeilleJson> load({
    required DateTime start,
    required DateTime end,
    String? poleId,
    String? projectId,
    String? memberId,
    String? seasonId,
  });
  Future<VeilleJson> detail(String kind, String id);
  Future<VeilleJson> save(
    String path,
    VeilleJson data, {
    String method = 'POST',
  });
  Future<VeilleJson> taskStatus(String id, String status);
  Future<VeilleJson> taskProof(String id, String url);
  Future<VeilleJson> taskChecklist(String id, bool done);
  Future<VeilleJson> taskComment(String id, String content);
  Future<Uint8List> exportReport(String id);
  Future<Uint8List> downloadProof(String url);
}

class ApiVeilleGateway implements VeilleGateway {
  final ApiClient api;
  final AuthService auth;
  ApiVeilleGateway({ApiClient? apiClient, AuthService? authService})
    : api = apiClient ?? ApiClient(),
      auth = authService ?? AuthService();

  Future<String> _token() async {
    final token = await auth.getToken();
    if (token == null) {
      throw Exception('Connectez-vous pour retrouver votre suivi.');
    }
    return token;
  }

  VeilleJson _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw Exception('Le suivi est temporairement indisponible. Réessayez.');
  }

  @override
  Future<VeilleJson> load({
    required DateTime start,
    required DateTime end,
    String? poleId,
    String? projectId,
    String? memberId,
    String? seasonId,
  }) async {
    final token = await _token();
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final query = Uri(
      queryParameters: {
        'start': date(start),
        'end': date(end),
        'pole_id': ?poleId,
        'project_id': ?projectId,
        'member_id': ?memberId,
        'season_id': ?seasonId,
      },
    ).query;
    final results = await Future.wait([
      api.get('/veille/context', token: token),
      api.get('/veille/summary?$query', token: token),
      api.get('/veille/records', token: token),
    ]);
    return {
      'context': _map(results[0]),
      'summary': _map(results[1]),
      'records': _map(results[2]),
    };
  }

  @override
  Future<VeilleJson> detail(String kind, String id) async => _map(
    await api.get(
      kind == 'task' ? '/veille/tasks/$id' : '/veille/records/$kind/$id',
      token: await _token(),
    ),
  );

  @override
  Future<VeilleJson> save(
    String path,
    VeilleJson data, {
    String method = 'POST',
  }) async {
    final token = await _token();
    return _map(switch (method) {
      'PATCH' => await api.patchJson('/veille$path', data: data, token: token),
      'PUT' => await api.putJson('/veille$path', data: data, token: token),
      _ => await api.postJson('/veille$path', data: data, token: token),
    });
  }

  @override
  Future<VeilleJson> taskStatus(String id, String status) async => _map(
    await api.postJson(
      '/tasks/$id/status',
      data: {'status': status},
      token: await _token(),
    ),
  );

  @override
  Future<VeilleJson> taskProof(String id, String url) async => _map(
    await api.postJson(
      '/tasks/$id/proof',
      data: {'proof_url': url},
      token: await _token(),
    ),
  );

  @override
  Future<VeilleJson> taskChecklist(String id, bool done) async => _map(
    await api.patchJson(
      '/tasks/checklist/$id',
      data: {'is_done': done},
      token: await _token(),
    ),
  );
  @override
  Future<VeilleJson> taskComment(String id, String content) async => _map(
    await api.postJson(
      '/tasks/comments',
      data: {'task_id': id, 'content': content},
      token: await _token(),
    ),
  );

  @override
  Future<Uint8List> exportReport(String id) async => Uint8List.fromList(
    await api.getBytes(
      '${ApiClient.baseUrl}/veille/reports/$id/export',
      token: await _token(),
    ),
  );

  @override
  Future<Uint8List> downloadProof(String url) async {
    final uri = Uri.parse(ApiClient.serverUrl).resolve(url);
    if (!{'http', 'https'}.contains(uri.scheme)) {
      throw Exception('Le lien du justificatif doit utiliser HTTP ou HTTPS.');
    }
    return Uint8List.fromList(
      await api.getBytes(uri.toString(), token: await _token()),
    );
  }
}
