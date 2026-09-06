import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/settings_models.dart';

abstract interface class SettingsGateway {
  Future<UserPreferences> loadPreferences();
  Future<UserPreferences> updatePreferences(Map<String, dynamic> changes);
  Future<AccountDataExport> requestDataExport();
  Future<AccountDeletionRequest?> loadDeletionRequest();
  Future<AccountDeletionRequest> requestDeletion(String? reason);
  Future<AccountDeletionRequest> cancelDeletionRequest();
}

class ApiSettingsGateway implements SettingsGateway {
  final ApiClient _api;
  final AuthService _auth;

  ApiSettingsGateway({ApiClient? apiClient, AuthService? authService})
    : _api = apiClient ?? ApiClient(),
      _auth = authService ?? AuthService();

  Future<String> _token() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException(statusCode: 401, message: 'Session expirée.');
    }
    return token;
  }

  @override
  Future<UserPreferences> loadPreferences() async {
    final response = await _api.get(
      '/users/me/preferences',
      token: await _token(),
    );
    return UserPreferences.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<UserPreferences> updatePreferences(
    Map<String, dynamic> changes,
  ) async {
    final response = await _api.patchJson(
      '/users/me/preferences',
      data: changes,
      token: await _token(),
    );
    return UserPreferences.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<AccountDataExport> requestDataExport() async {
    final response = await _api.postJson(
      '/users/me/data-export',
      data: const {},
      token: await _token(),
    );
    return AccountDataExport(response as Map<String, dynamic>);
  }

  @override
  Future<AccountDeletionRequest?> loadDeletionRequest() async {
    final response = await _api.get(
      '/users/me/deletion-request',
      token: await _token(),
    );
    if (response == null) return null;
    return AccountDeletionRequest.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<AccountDeletionRequest> requestDeletion(String? reason) async {
    final response = await _api.postJson(
      '/users/me/deletion-request',
      data: {if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim()},
      token: await _token(),
    );
    return AccountDeletionRequest.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<AccountDeletionRequest> cancelDeletionRequest() async {
    final response = await _api.postJson(
      '/users/me/deletion-request/cancel',
      data: const {},
      token: await _token(),
    );
    return AccountDeletionRequest.fromJson(response as Map<String, dynamic>);
  }
}
