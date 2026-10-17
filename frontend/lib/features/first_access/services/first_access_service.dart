import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';

class FirstAccessService {
  final ApiClient api;
  final AuthService auth;
  FirstAccessService({ApiClient? apiClient, AuthService? authService})
    : api = apiClient ?? ApiClient(),
      auth = authService ?? AuthService(apiClient: apiClient);
  Future<String?> token() => auth.getToken();
  Future<bool> needsOnboarding() async {
    final cached = await auth.getCachedCurrentUser();
    if (cached?['onboarding_completed_at'] != null &&
        cached?['onboarding_required'] != true) {
      return false;
    }
    final user = await auth.getCurrentUser();
    return user['onboarding_required'] == true &&
        user['onboarding_completed_at'] == null;
  }

  Future<Map<String, dynamic>> status() async => Map<String, dynamic>.from(
    await api.get('/first-access/me', token: await token()),
  );
  Future<Map<String, dynamic>> catalog() async => Map<String, dynamic>.from(
    await api.get('/first-access/catalog', token: await token()),
  );
  Future<void> complete(Map<String, dynamic> data) async {
    await api.postJson(
      '/first-access/me/complete',
      data: data,
      token: await token(),
    );
    await auth.getCurrentUser();
  }

  Future<String> requestActivation(String identifier) async {
    final data = await api.postJson(
      '/auth/activation/request',
      data: {'identifier': identifier.trim()},
    );
    return data['message'].toString();
  }

  Future<void> activate(String identifier, String code, String password) async {
    await api.postJson(
      '/auth/activation/confirm',
      data: {
        'identifier': identifier.trim(),
        'code': code.trim(),
        'new_password': password,
      },
    );
  }

  Future<List<Map<String, dynamic>>> inventory() async {
    final data = await api.get('/first-access/members', token: await token());
    return (data as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> contact(String id, String email, String phone) async {
    await api.patchJson(
      '/first-access/members/$id/contact',
      token: await token(),
      data: {'email': email.trim(), 'phone': phone.trim()},
    );
  }

  Future<String> invite(String id) async {
    final data = await api.postJson(
      '/first-access/members/$id/invite',
      token: await token(),
      data: {},
    );
    return data['message'].toString();
  }

  Future<String> recoverContact(
    String id,
    String email,
    String phone,
    String note,
    String expectedEmail,
  ) async {
    final data = await api.postJson(
      '/first-access/members/$id/recover-contact',
      token: await token(),
      data: {
        'email': email.trim(),
        'phone': phone.trim(),
        'verification_note': note.trim(),
        'expected_email': expectedEmail,
        'identity_verified': true,
        'sessions_revocation_acknowledged': true,
      },
    );
    return data['message'].toString();
  }

  Future<void> logout() => auth.logout();
}
