import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  final FlutterSecureStorage _storage;

  const FlutterSecureKeyValueStore({
    this._storage = const FlutterSecureStorage(),
  });

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

typedef SharedPreferencesFactory = Future<SharedPreferences> Function();

class AuthStorage {
  static const legacyAccessTokenKey = 'enactspace_token';
  static const legacyCurrentUserKey = 'enactspace_current_user';
  static const _accessTokenKey = 'enactspace.auth.access_token';
  static const _currentUserKey = 'enactspace.auth.current_user';

  final SecureKeyValueStore _secureStore;
  final SharedPreferencesFactory _preferencesFactory;

  AuthStorage({
    SecureKeyValueStore? secureStore,
    SharedPreferencesFactory? preferencesFactory,
  }) : _secureStore = secureStore ?? const FlutterSecureKeyValueStore(),
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  Future<String?> readAccessToken() => _readAndMigrate(
    secureKey: _accessTokenKey,
    legacyKey: legacyAccessTokenKey,
  );

  Future<void> writeAccessToken(String token) => _writeSecureValue(
    secureKey: _accessTokenKey,
    legacyKey: legacyAccessTokenKey,
    value: token,
  );

  Future<String?> readCurrentUser() => _readAndMigrate(
    secureKey: _currentUserKey,
    legacyKey: legacyCurrentUserKey,
  );

  Future<void> writeCurrentUser(String userJson) => _writeSecureValue(
    secureKey: _currentUserKey,
    legacyKey: legacyCurrentUserKey,
    value: userJson,
  );

  Future<void> deleteCurrentUser() => Future.wait([
    _secureStore.delete(_currentUserKey),
    _removeLegacyValue(legacyCurrentUserKey),
  ]);

  Future<void> clearAuthSecrets() => Future.wait([
    _secureStore.delete(_accessTokenKey),
    _secureStore.delete(_currentUserKey),
    _removeLegacyValue(legacyAccessTokenKey),
    _removeLegacyValue(legacyCurrentUserKey),
  ]);

  Future<String?> _readAndMigrate({
    required String secureKey,
    required String legacyKey,
  }) async {
    final secureValue = await _secureStore.read(secureKey);
    if (secureValue != null && secureValue.isNotEmpty) {
      await _removeLegacyValue(legacyKey);
      return secureValue;
    }

    final preferences = await _preferencesFactory();
    final legacyValue = preferences.getString(legacyKey);
    if (legacyValue == null || legacyValue.isEmpty) return null;

    // Delete the legacy copy only after the secure write succeeds.
    await _secureStore.write(secureKey, legacyValue);
    await preferences.remove(legacyKey);
    return legacyValue;
  }

  Future<void> _writeSecureValue({
    required String secureKey,
    required String legacyKey,
    required String value,
  }) async {
    await _secureStore.write(secureKey, value);
    await _removeLegacyValue(legacyKey);
  }

  Future<void> _removeLegacyValue(String key) async {
    final preferences = await _preferencesFactory();
    await preferences.remove(key);
  }
}
