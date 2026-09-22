import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';
import '../auth/auth_service.dart';
import 'push_installation_store.dart';

abstract interface class PushGateway {
  Future<bool> loadPushPreference();
  Future<void> updatePushPreference(bool enabled);
  Future<String> ensureInstallation(String userId);
  Future<void> registerToken(
    String installationId,
    String token, {
    bool enableAccountPush = false,
  });
  Future<void> unregisterToken(String installationId);
  Future<void> revokeInstallation(String installationId);
  Future<void> markNotificationRead(String notificationId);
}

class ApiPushGateway implements PushGateway {
  final ApiClient api;
  final AuthService auth;
  final PushInstallationStore store;

  ApiPushGateway({
    ApiClient? apiClient,
    AuthService? authService,
    PushInstallationStore? installationStore,
  }) : api = apiClient ?? ApiClient(),
       auth = authService ?? AuthService(),
       store = installationStore ?? const SecurePushInstallationStore();

  Future<String> _token() async {
    final value = await auth.getToken();
    if (value == null || value.isEmpty) throw StateError('Session absente');
    return value;
  }

  @override
  Future<bool> loadPushPreference() async {
    final value = await api.get('/users/me/preferences', token: await _token());
    return value is Map && value['notification_push_enabled'] == true;
  }

  @override
  Future<void> updatePushPreference(bool enabled) async {
    await api.patchJson(
      '/users/me/preferences',
      data: {'notification_push_enabled': enabled},
      token: await _token(),
    );
  }

  @override
  Future<String> ensureInstallation(String userId) async {
    final key = await store.installationKey(userId);
    final info = await PackageInfo.fromPlatform();
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    final value = await api.postJson(
      '/users/me/installations',
      token: await _token(),
      data: {
        'installation_key': key,
        'platform': platform,
        'app_version': info.version,
        'build_number': int.tryParse(info.buildNumber),
        'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
        'os_version': null,
        'device_model': null,
      },
    );
    final id = (value as Map<String, dynamic>)['id'].toString();
    await store.writeServerInstallationId(userId, id);
    return id;
  }

  @override
  Future<void> registerToken(
    String installationId,
    String token, {
    bool enableAccountPush = false,
  }) async {
    await api.putJson(
      '/users/me/installations/$installationId/push-token',
      token: await _token(),
      data: {
        'provider': 'fcm',
        'token': token,
        'enable_account_push': enableAccountPush,
      },
    );
  }

  @override
  Future<void> unregisterToken(String installationId) async {
    await api.delete(
      '/users/me/installations/$installationId/push-token',
      token: await _token(),
    );
  }

  @override
  Future<void> revokeInstallation(String installationId) async {
    await api.postJson(
      '/users/me/installations/$installationId/revoke',
      token: await _token(),
      data: const {},
    );
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await api.postJson(
      '/notifications/$notificationId/read',
      token: await _token(),
      data: const {},
    );
  }
}
