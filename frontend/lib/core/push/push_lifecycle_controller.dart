import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../auth/auth_storage.dart';
import 'firebase_push_platform.dart';
import 'push_gateway.dart';
import 'push_installation_store.dart';
import 'push_platform.dart';

class PushLifecycleController extends ChangeNotifier {
  static final PushLifecycleController instance = PushLifecycleController();

  final PushPlatform platform;
  final PushGateway gateway;
  final PushInstallationStore store;
  final AuthService auth;
  bool initialized = false;
  bool preferenceEnabled = false;
  bool deviceSynchronized = false;
  PushAuthorization authorization = PushAuthorization.notDetermined;
  String? activeUserId;
  String? error;
  StreamSubscription<String>? _tokenSubscription;
  VoidCallback? _authListener;

  PushLifecycleController({
    PushPlatform? pushPlatform,
    PushGateway? pushGateway,
    PushInstallationStore? installationStore,
    AuthService? authService,
  }) : platform = pushPlatform ?? FirebasePushPlatform(),
       gateway = pushGateway ?? ApiPushGateway(),
       store = installationStore ?? const SecurePushInstallationStore(),
       auth = authService ?? AuthService();

  bool get available =>
      platform.supported && platform.configured && initialized;
  bool get deviceAuthorized => _isAuthorized(authorization);
  Stream<PushIncomingMessage> get foregroundMessages =>
      platform.foregroundMessages;
  Stream<PushIncomingMessage> get openedMessages => platform.openedMessages;

  Future<void> initialize() async {
    try {
      initialized = await platform.initialize();
    } catch (_) {
      initialized = false;
    }
    _authListener ??= () => unawaited(_handleAuthChange());
    AuthStorage.instance.sessionChanges.addListener(_authListener!);
  }

  Future<void> activateForAuthenticatedUser() async {
    if (!available) return;
    final cached = await auth.getCachedCurrentUser();
    final userId = cached?['id']?.toString();
    if (userId == null || userId.isEmpty) return;
    try {
      await synchronizeAuthenticatedUser(
        userId,
        await gateway.loadPushPreference(),
      );
    } catch (_) {
      // Push lifecycle never blocks authenticated application startup.
    }
  }

  Future<void> synchronizeAuthenticatedUser(String userId, bool enabled) async {
    activeUserId = userId;
    preferenceEnabled = enabled;
    deviceSynchronized = false;
    authorization = await platform.permissionStatus();
    await _tokenSubscription?.cancel();
    _tokenSubscription = platform.tokenRefresh.listen((token) {
      if (preferenceEnabled &&
          _isAuthorized(authorization) &&
          activeUserId != null) {
        unawaited(_register(token));
      }
    });
    if (preferenceEnabled && _isAuthorized(authorization)) {
      await _synchronizeToken();
    }
    notifyListeners();
  }

  Future<bool> enableFromUserAction() async {
    error = null;
    if (!available) {
      error = 'Les notifications push sont indisponibles sur cette version.';
      notifyListeners();
      return false;
    }
    try {
      if (await _resolveAuthenticatedUserId() == null) {
        error = 'Reconnectez-vous pour activer les notifications push.';
        notifyListeners();
        return false;
      }
      authorization = await platform.permissionStatus();
      if (authorization == PushAuthorization.notDetermined) {
        authorization = await platform.requestPermission();
      }
      if (!_isAuthorized(authorization)) {
        error =
            'Les notifications sont bloquées dans les réglages de l’appareil.';
        notifyListeners();
        return false;
      }
      final token = await platform.currentToken();
      if (token == null || token.isEmpty) {
        throw StateError('Jeton indisponible');
      }
      await _register(token, enableAccountPush: true);
      try {
        await gateway.updatePushPreference(true);
      } catch (_) {
        await _unregisterCurrentBestEffort();
        rethrow;
      }
      preferenceEnabled = true;
      deviceSynchronized = true;
      notifyListeners();
      return true;
    } catch (_) {
      error = 'L’activation des notifications push a échoué. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> disableFromUserAction() async {
    error = null;
    try {
      await gateway.updatePushPreference(false);
      preferenceEnabled = false;
      deviceSynchronized = false;
      try {
        await platform.deleteToken();
      } catch (_) {}
      notifyListeners();
      return true;
    } catch (_) {
      error = 'La désactivation des notifications push a échoué.';
      notifyListeners();
      return false;
    }
  }

  void synchronizeServerPreference(bool enabled) {
    preferenceEnabled = enabled;
    notifyListeners();
  }

  Future<void> reconcileOnResume() async {
    if (!available || activeUserId == null) return;
    try {
      authorization = await platform.permissionStatus();
      if (preferenceEnabled && _isAuthorized(authorization)) {
        await _synchronizeToken();
      } else if (preferenceEnabled &&
          authorization == PushAuthorization.denied) {
        deviceSynchronized = false;
        await _unregisterCurrentBestEffort();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> cleanupForLogout({required bool allDevices}) async {
    try {
      final userId = activeUserId;
      if (userId != null) {
        final installationId = await store.serverInstallationId(userId);
        if (installationId != null) {
          try {
            await gateway.unregisterToken(installationId);
          } catch (_) {}
          if (!allDevices) {
            try {
              await gateway.revokeInstallation(installationId);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    try {
      await platform.deleteToken();
    } catch (_) {}
    try {
      await _clearRuntime();
    } catch (_) {
      activeUserId = null;
      preferenceEnabled = false;
    }
  }

  Future<void> markReadBestEffort(String? notificationId) async {
    if (notificationId == null ||
        notificationId.isEmpty ||
        activeUserId == null) {
      return;
    }
    try {
      await gateway.markNotificationRead(notificationId);
    } catch (_) {}
  }

  Future<void> _register(String token, {bool enableAccountPush = false}) async {
    final userId = activeUserId;
    if (userId == null || userId.isEmpty) {
      throw StateError('Contexte utilisateur authentifié absent');
    }
    final installationId = await gateway.ensureInstallation(userId);
    await gateway.registerToken(
      installationId,
      token,
      enableAccountPush: enableAccountPush,
    );
    deviceSynchronized = true;
  }

  Future<void> _synchronizeToken() async {
    final token = await platform.currentToken();
    if (token != null && token.isNotEmpty) await _register(token);
  }

  Future<void> _unregisterCurrentBestEffort() async {
    final userId = activeUserId;
    if (userId == null) return;
    final installationId = await store.serverInstallationId(userId);
    if (installationId != null) {
      try {
        await gateway.unregisterToken(installationId);
      } catch (_) {}
    }
  }

  Future<void> _handleAuthChange() async {
    if (!await auth.isLoggedIn()) await _clearRuntime(deleteToken: true);
  }

  Future<void> _clearRuntime({bool deleteToken = false}) async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    activeUserId = null;
    preferenceEnabled = false;
    deviceSynchronized = false;
    if (deleteToken) {
      try {
        await platform.deleteToken();
      } catch (_) {}
    }
    notifyListeners();
  }

  bool _isAuthorized(PushAuthorization value) =>
      value == PushAuthorization.authorized ||
      value == PushAuthorization.provisional;

  Future<String?> _resolveAuthenticatedUserId() async {
    final existing = activeUserId;
    if (existing != null && existing.isNotEmpty) return existing;
    if (!await auth.isLoggedIn()) return null;
    Map<String, dynamic>? user = await auth.getCachedCurrentUser();
    user ??= await auth.getCurrentUser();
    final userId = user['id']?.toString();
    if (userId == null || userId.isEmpty) return null;
    activeUserId = userId;
    return userId;
  }
}

Future<void> runLogoutWithPushCleanup({
  required Future<void> Function() cleanup,
  required Future<void> Function() logout,
}) async {
  try {
    await cleanup();
  } catch (_) {
    // Authentication logout must still run even if optional push cleanup fails.
  }
  await logout();
}
