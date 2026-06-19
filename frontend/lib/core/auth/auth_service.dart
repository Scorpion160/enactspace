import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

class AuthService {
  static const String _tokenKey = 'enactspace_token';
  static const String _userKey = 'enactspace_current_user';

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

  Future<String?> requestPasswordResetOtp({required String email}) async {
    final response = await _apiClient.postJson(
      '/auth/password-reset/request',
      data: {'email': email},
    );

    if (response is Map<String, dynamic>) {
      return response['debug_otp']?.toString();
    }

    return null;
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
    required String gender,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    String? photoUrl,
    String? department,
    String? level,
    String? promotion,
    String? skills,
    String? linkedinUrl,
    String? githubUrl,
    String? portfolioUrl,
    String? motivation,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/join-requests',
      data: {
        'profile_type': profileType,
        'gender': gender,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
        if (department != null && department.isNotEmpty)
          'department': department,
        if (level != null && level.isNotEmpty) 'level': level,
        if (promotion != null && promotion.isNotEmpty) 'promotion': promotion,
        if (skills != null && skills.isNotEmpty) 'skills': skills,
        if (linkedinUrl != null && linkedinUrl.isNotEmpty)
          'linkedin_url': linkedinUrl,
        if (githubUrl != null && githubUrl.isNotEmpty) 'github_url': githubUrl,
        if (portfolioUrl != null && portfolioUrl.isNotEmpty)
          'portfolio_url': portfolioUrl,
        if (motivation != null && motivation.isNotEmpty)
          'motivation': motivation,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse invalide lors de la création du compte.');
    }
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

    try {
      final user = await _apiClient.get('/users/me', token: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
      return user;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await logout();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCachedCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_userKey);
    if (value == null || value.isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      await prefs.remove(_userKey);
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([prefs.remove(_tokenKey), prefs.remove(_userKey)]);
  }
}
