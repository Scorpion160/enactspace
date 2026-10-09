import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';

abstract class TeamYearsGateway {
  Future<List<Map<String, dynamic>>> loadYears();
  Future<bool> canManage();
  Future<void> createYear(Map<String, dynamic> values);
  Future<void> activateYear(String id, String? expectedCurrentId);
}

class ApiTeamYearsGateway implements TeamYearsGateway {
  final ApiClient api;
  final AuthService auth;
  ApiTeamYearsGateway({ApiClient? api, AuthService? auth})
    : api = api ?? ApiClient(),
      auth = auth ?? AuthService();
  Future<String> _token() async {
    final token = await auth.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Session expirée');
    }
    return token;
  }

  @override
  Future<List<Map<String, dynamic>>> loadYears() async {
    final data = await api.get('/seasons/', token: await _token());
    if (data is! List) {
      throw StateError('Années indisponibles');
    }
    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<bool> canManage() async {
    final data = await api.get('/seasons/context', token: await _token());
    return data is Map && data['can_manage'] == true;
  }

  @override
  Future<void> createYear(Map<String, dynamic> values) async {
    await api.postJson('/seasons/', token: await _token(), data: values);
  }

  @override
  Future<void> activateYear(String id, String? expectedCurrentId) async {
    await api.postJson(
      '/seasons/$id/activate',
      token: await _token(),
      data: {'expected_current_id': expectedCurrentId},
    );
  }
}
