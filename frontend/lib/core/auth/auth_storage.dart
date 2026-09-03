import 'dart:convert';

import 'package:flutter/foundation.dart';
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

class AuthTokens {
  final String accessToken;
  final String? refreshToken;

  const AuthTokens({required this.accessToken, this.refreshToken});

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
  };
}

class AuthStorage {
  static final AuthStorage instance = AuthStorage();
  static const legacyAccessTokenKey = 'enactspace_token';
  static const legacyCurrentUserKey = 'enactspace_current_user';
  static const _accessTokenKey = 'enactspace.auth.access_token';
  static const _currentUserKey = 'enactspace.auth.current_user';
  static const _tokenPairKey = 'enactspace.auth.token_pair';

  final SecureKeyValueStore _secureStore;
  final SharedPreferencesFactory _preferencesFactory;
  final ValueNotifier<int> sessionChanges = ValueNotifier(0);
  Future<void> _pending = Future<void>.value();
  int _generation = 0;
  final Set<String> _sessionAccessTokens = {};

  int get generation => _generation;
  bool ownsAccessToken(String token) => _sessionAccessTokens.contains(token);

  AuthStorage({
    SecureKeyValueStore? secureStore,
    SharedPreferencesFactory? preferencesFactory,
  }) : _secureStore = secureStore ?? const FlutterSecureKeyValueStore(),
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<AuthTokens?> readTokenPair() => _serial(() async {
    final value = await _secureStore.read(_tokenPairKey);
    if (value != null) {
      AuthTokens? tokens;
      try {
        final data = jsonDecode(value) as Map<String, dynamic>;
        tokens = AuthTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String?,
        );
      } on FormatException {
        tokens = null;
      } on TypeError {
        tokens = null;
      }
      if (tokens == null) {
        _generation++;
        _sessionAccessTokens.clear();
        await _clearValues();
        sessionChanges.value++;
        return null;
      }
      // Finish cleanup if the process stopped after the atomic pair write.
      await _secureStore.delete(_accessTokenKey);
      await _removeLegacyValue(legacyAccessTokenKey);
      _sessionAccessTokens.add(tokens.accessToken);
      return tokens;
    }
    final access = await _readAndMigrate(
      secureKey: _accessTokenKey,
      legacyKey: legacyAccessTokenKey,
    );
    if (access == null) return null;
    _sessionAccessTokens.add(access);
    return AuthTokens(accessToken: access);
  });

  Future<String?> readAccessToken() async {
    final access = (await readTokenPair())?.accessToken;
    return access == null || access.isEmpty ? null : access;
  }

  Future<void> writeAccessToken(String token) =>
      writeTokenPair(AuthTokens(accessToken: token));

  Future<void> writeTokenPair(AuthTokens tokens, {int? expectedGeneration}) {
    if (expectedGeneration != null && expectedGeneration != _generation) {
      return Future<void>.error(StateError('Tentative de connexion obsolète.'));
    }
    _generation++;
    final generation = _generation;
    _sessionAccessTokens.clear();
    return _serial(() async {
      if (generation != _generation) return;
      _sessionAccessTokens.clear();
      await Future.wait([
        _secureStore.delete(_currentUserKey),
        _removeLegacyValue(legacyCurrentUserKey),
      ]);
      await _writePair(tokens);
      sessionChanges.value++;
    });
  }

  Future<bool> rotateTokenPair(AuthTokens tokens, int expectedGeneration) =>
      _serial(() async {
        if (_generation != expectedGeneration) return false;
        await _writePair(tokens);
        return _generation == expectedGeneration;
      });

  Future<void> _writePair(AuthTokens tokens) async {
    // One secure value prevents a process interruption from mixing generations.
    await _secureStore.write(_tokenPairKey, jsonEncode(tokens.toJson()));
    _sessionAccessTokens.add(tokens.accessToken);
    if (_sessionAccessTokens.length > 8) {
      _sessionAccessTokens.remove(_sessionAccessTokens.first);
    }
    await _secureStore.delete(_accessTokenKey);
    await _removeLegacyValue(legacyAccessTokenKey);
  }

  Future<String?> readCurrentUser() => _serial(
    () => _readAndMigrate(
      secureKey: _currentUserKey,
      legacyKey: legacyCurrentUserKey,
    ),
  );

  Future<void> writeCurrentUser(String userJson, {int? expectedGeneration}) =>
      _serial(() async {
        if (expectedGeneration != null && expectedGeneration != _generation) {
          return;
        }
        await _writeSecureValue(
          secureKey: _currentUserKey,
          legacyKey: legacyCurrentUserKey,
          value: userJson,
        );
      });

  Future<void> deleteCurrentUser() => _serial(
    () => Future.wait([
      _secureStore.delete(_currentUserKey),
      _removeLegacyValue(legacyCurrentUserKey),
    ]),
  );

  Future<void> clearAuthSecrets({int? expectedGeneration}) {
    if (expectedGeneration != null && expectedGeneration != _generation) {
      return Future<void>.value();
    }
    // Invalidate in-flight refresh/profile writes before waiting for storage IO.
    _generation++;
    _sessionAccessTokens.clear();
    return _serial(() async {
      _sessionAccessTokens.clear();
      try {
        await _clearValues();
      } finally {
        sessionChanges.value++;
      }
    });
  }

  Future<void> _clearValues() => Future.wait([
    _secureStore.delete(_tokenPairKey),
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
