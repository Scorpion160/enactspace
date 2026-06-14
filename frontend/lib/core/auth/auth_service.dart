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

  Future<void> requestPasswordResetOtp({required String email}) async {
    await _apiClient.postJson(
      '/auth/password-reset/request',
      data: {'email': email},
    );
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _apiClient.postJson(
      '/auth/password-reset/confirm',
      data: {'email': email, 'otp': otp, 'new_password': newPassword},
    );
  }

  Future<void> submitJoinRequest({
    required String profileType,
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
    String? department,
    String? level,
    String? skills,
    String? motivation,
  }) async {
    await _apiClient.postJson(
      '/auth/join-requests',
      data: {
        'profile_type': profileType,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (department != null && department.isNotEmpty)
          'department': department,
        if (level != null && level.isNotEmpty) 'level': level,
        if (skills != null && skills.isNotEmpty) 'skills': skills,
        if (motivation != null && motivation.isNotEmpty)
          'motivation': motivation,
      },
    );
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
