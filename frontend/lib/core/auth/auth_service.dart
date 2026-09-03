import 'dart:convert';

import '../api/api_client.dart';
import 'auth_storage.dart';

class AuthService {
  static final AuthStorage _defaultStorage = AuthStorage.instance;

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  AuthService({ApiClient? apiClient, AuthStorage? authStorage})
    : _apiClient =
          apiClient ?? ApiClient(authStorage: authStorage ?? _defaultStorage),
      _authStorage = authStorage ?? apiClient?.authStorage ?? _defaultStorage;

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final generation = _authStorage.generation;
    final data = await _apiClient.postForm(
      '/auth/token',
      data: {'username': email, 'password': password},
    );

    final token = data['access_token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception('Token non reçu depuis le serveur.');
    }

    await _authStorage.writeTokenPair(
      AuthTokens(
        accessToken: token.toString(),
        refreshToken: data['refresh_token'] as String?,
      ),
      expectedGeneration: generation,
    );

    try {
      await getCurrentUser();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
    } catch (_) {
      // The token is enough to enter the app; navigation can refresh the
      // profile again once the shell is mounted.
    }

    return token.toString();
  }

  Future<String?> getToken() async {
    return _authStorage.readAccessToken();
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
    final pair = await _authStorage.readTokenPair();
    return pair != null &&
        (pair.accessToken.isNotEmpty ||
            (pair.refreshToken?.isNotEmpty ?? false));
  }

  Future<bool> restoreSession() async {
    if (!await isLoggedIn()) return false;
    try {
      await getCurrentUser();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) return false;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final generation = _authStorage.generation;
    try {
      final token =
          await getToken() ??
          await _apiClient.refreshSession(expectedGeneration: generation);
      final user = await _apiClient.get('/users/me', token: token);
      if (generation != _authStorage.generation) {
        throw ApiException(
          statusCode: 401,
          message: 'Session expirée. Reconnectez-vous.',
        );
      }
      await _authStorage.writeCurrentUser(
        jsonEncode(user),
        expectedGeneration: generation,
      );
      return user;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _authStorage.clearAuthSecrets(expectedGeneration: generation);
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> readCachedCurrentUser() async {
    final value = await _defaultStorage.readCurrentUser();
    if (value == null || value.isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      await _defaultStorage.deleteCurrentUser();
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCachedCurrentUser() =>
      _readCachedCurrentUser();

  Future<Map<String, dynamic>?> _readCachedCurrentUser() async {
    final value = await _authStorage.readCurrentUser();
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      await _authStorage.deleteCurrentUser();
      return null;
    }
  }

  Future<void> logout() => _apiClient.logoutSession();

  Future<void> logoutAll() => _apiClient.logoutSession(all: true);
}
