import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAppearance { system, light, dark }

abstract interface class AppearancePreferenceStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesAppearanceStore implements AppearancePreferenceStore {
  static const key = 'enactspace.appearance.theme';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, value);
  }
}

class AppearanceController extends ChangeNotifier {
  static final AppearanceController instance = AppearanceController();

  final AppearancePreferenceStore _store;
  AppAppearance _appearance = AppAppearance.system;

  AppearanceController({AppearancePreferenceStore? store})
    : _store = store ?? SharedPreferencesAppearanceStore();

  AppAppearance get appearance => _appearance;

  ThemeMode get themeMode => switch (_appearance) {
    AppAppearance.system => ThemeMode.system,
    AppAppearance.light => ThemeMode.light,
    AppAppearance.dark => ThemeMode.dark,
  };

  Future<void> loadCached() async {
    try {
      _set(_parse(await _store.read()));
    } catch (_) {
      _set(AppAppearance.system);
    }
  }

  Future<void> select(AppAppearance appearance) async {
    _set(appearance);
    try {
      await _store.write(appearance.name);
    } catch (_) {
      // The non-sensitive cache is best-effort; in-memory appearance wins.
    }
  }

  Future<void> synchronizeServer(String value) => select(_parse(value));

  void _set(AppAppearance appearance) {
    if (_appearance == appearance) return;
    _appearance = appearance;
    notifyListeners();
  }

  static AppAppearance _parse(String? value) => switch (value) {
    'light' => AppAppearance.light,
    'dark' => AppAppearance.dark,
    _ => AppAppearance.system,
  };
}
