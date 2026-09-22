import 'package:flutter/foundation.dart';

import '../../../core/theme/appearance_controller.dart';
import '../../../core/push/push_lifecycle_controller.dart';
import '../models/settings_models.dart';
import '../services/settings_gateway.dart';

class SettingsController extends ChangeNotifier {
  final SettingsGateway gateway;
  final AppearanceController appearance;
  final PushLifecycleController push;

  UserPreferences? preferences;
  AccountDeletionRequest? deletionRequest;
  bool loading = false;
  bool saving = false;
  String? error;

  SettingsController({
    required this.gateway,
    required this.appearance,
    PushLifecycleController? pushController,
  }) : push = pushController ?? PushLifecycleController.instance;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        gateway.loadPreferences(),
        gateway.loadDeletionRequest(),
      ]);
      preferences = results[0] as UserPreferences;
      deletionRequest = results[1] as AccountDeletionRequest?;
      await appearance.synchronizeServer(preferences!.theme);
      push.synchronizeServerPreference(preferences!.pushNotifications);
    } catch (_) {
      error = 'Impossible de charger vos réglages. Réessayez dans un instant.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> setTheme(AppAppearance value) async {
    await appearance.select(value);
    return _patch({'theme': value.name}, appliedLocally: true);
  }

  Future<bool> setInAppNotifications(bool value) =>
      _patch({'notification_in_app_enabled': value}, appliedLocally: false);

  Future<bool> setEmailNotifications(bool value) =>
      _patch({'notification_email_enabled': value}, appliedLocally: false);

  Future<bool> setPushNotifications(bool value) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      final success = value
          ? await push.enableFromUserAction()
          : await push.disableFromUserAction();
      if (success && preferences != null) {
        preferences = preferences!.copyWith(pushNotifications: value);
      } else if (!success) {
        error = push.error;
      }
      return success;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> _patch(
    Map<String, dynamic> changes, {
    required bool appliedLocally,
  }) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      preferences = await gateway.updatePreferences(changes);
      return true;
    } catch (_) {
      error = appliedLocally
          ? 'Le thème est appliqué sur cet appareil, mais sa synchronisation a échoué.'
          : 'La modification n’a pas pu être enregistrée. Réessayez dans un instant.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<AccountDataExport> exportData() => gateway.requestDataExport();

  Future<bool> requestDeletion(String? reason) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      deletionRequest = await gateway.requestDeletion(reason);
      return true;
    } catch (_) {
      error = 'La demande de suppression n’a pas pu être envoyée.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> cancelDeletion() async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      deletionRequest = await gateway.cancelDeletionRequest();
      return true;
    } catch (_) {
      error = 'La demande n’a pas pu être annulée.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
