import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

class AuthService {
  static const String _tokenKey = 'enactspace_token';

  final ApiClient _apiClient;

  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final data = await _apiClient.postForm(
      '/auth/token',
      data: {'username': email, 'password': password},
    );

    final token = data['access_token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception('Token non reçu depuis le serveur.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token.toString());

    return token.toString();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final token = await getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    return await _apiClient.get('/users/me', token: token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
