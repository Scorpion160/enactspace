import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';

class AcademicProfileService {
  final ApiClient apiClient;
  final AuthService authService;

  AcademicProfileService({ApiClient? apiClient, AuthService? authService})
    : apiClient = apiClient ?? ApiClient(),
      authService = authService ?? AuthService();

  Future<String> _token() async {
    final token = await authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Reconnectez-vous pour confirmer votre profil.');
    }
    return token;
  }

  Future<Map<String, Map<String, List<String>>>> catalog() async {
    final response = await apiClient.get(
      '/academic-profile/catalog', token: await _token(),
    );
    if (response is! Map<String, dynamic> || response['departments'] is! Map) {
      throw Exception('Catalogue académique indisponible.');
    }
    final departments = response['departments'] as Map;
    final result = <String, Map<String, List<String>>>{};
    for (final entry in departments.entries) {
      final paths = <String, List<String>>{};
      for (final path in (entry.value as Map).entries) {
        paths[path.key.toString()] =
            (path.value as List).map((value) => value.toString()).toList();
      }
      result[entry.key.toString()] = paths;
    }
    return result;
  }

  Future<Map<String, dynamic>> profile() async {
    final response = await apiClient.get('/academic-profile/me', token: await _token());
    if (response is! Map<String, dynamic>) throw Exception('Profil indisponible.');
    return response;
  }

  Future<Map<String, dynamic>> confirm(Map<String, dynamic> values) async {
    final response = await apiClient.putJson(
      '/academic-profile/me/confirm', token: await _token(), data: values,
    );
    if (response is! Map<String, dynamic>) throw Exception('Confirmation indisponible.');
    return response;
  }
}
