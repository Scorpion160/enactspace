import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';

class RecruitmentSelectionApi {
  final ApiClient _api;
  final AuthService _auth;

  RecruitmentSelectionApi({ApiClient? api, AuthService? auth})
      : _api = api ?? ApiClient(),
        _auth = auth ?? AuthService();

  Future<Map<String, dynamic>> request(String path, {Map<String, dynamic>? body}) async {
    final token = await _auth.getToken();
    if (token == null) throw StateError('Connecte-toi pour poursuivre.');
    final response = body == null
        ? await _api.get('/recruitment/$path', token: token)
        : await _api.postJson('/recruitment/$path', token: token, data: body);
    return Map<String, dynamic>.from(response as Map);
  }
}
