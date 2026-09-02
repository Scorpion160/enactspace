import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('migrates a legacy token once and deletes the plaintext copy', () async {
    SharedPreferences.setMockInitialValues({
      AuthStorage.legacyAccessTokenKey: 'legacy-token',
    });
    final secureStore = _MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);

    expect(await storage.readAccessToken(), 'legacy-token');
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        AuthStorage.legacyAccessTokenKey,
      ),
      isFalse,
    );
    expect(secureStore.writeCount, 1);

    expect(await storage.readAccessToken(), 'legacy-token');
    expect(secureStore.writeCount, 1);
  });

  test('keeps a legacy token when the secure migration write fails', () async {
    SharedPreferences.setMockInitialValues({
      AuthStorage.legacyAccessTokenKey: 'recoverable-token',
    });
    final storage = AuthStorage(
      secureStore: _MemorySecureStore(failWrites: true),
    );

    await expectLater(storage.readAccessToken(), throwsStateError);
    expect(
      (await SharedPreferences.getInstance()).getString(
        AuthStorage.legacyAccessTokenKey,
      ),
      'recoverable-token',
    );
  });

  test('new auth values never remain in SharedPreferences', () async {
    final secureStore = _MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);

    await storage.writeAccessToken('secure-token');
    await storage.writeCurrentUser('{"id":"member-1"}');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(AuthStorage.legacyAccessTokenKey), isNull);
    expect(preferences.getString(AuthStorage.legacyCurrentUserKey), isNull);
    expect(await storage.readAccessToken(), 'secure-token');
    expect(await storage.readCurrentUser(), '{"id":"member-1"}');
  });

  test('logout storage clears secure and legacy auth values', () async {
    SharedPreferences.setMockInitialValues({
      AuthStorage.legacyAccessTokenKey: 'legacy-token',
      AuthStorage.legacyCurrentUserKey: '{"id":"legacy"}',
    });
    final secureStore = _MemorySecureStore();
    final storage = AuthStorage(secureStore: secureStore);
    await storage.writeAccessToken('secure-token');
    await storage.writeCurrentUser('{"id":"secure"}');

    await storage.clearAuthSecrets();

    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readCurrentUser(), isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(AuthStorage.legacyAccessTokenKey), isNull);
    expect(preferences.getString(AuthStorage.legacyCurrentUserKey), isNull);
  });

  test('release API configuration requires an absolute HTTPS URL', () {
    expect(
      () => ApiClient.resolveServerUrl(
        configuredUrl: '',
        releaseMode: true,
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      throwsStateError,
    );
    expect(
      () => ApiClient.resolveServerUrl(
        configuredUrl: 'http://api.example.test',
        releaseMode: true,
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      throwsStateError,
    );
    expect(
      ApiClient.resolveServerUrl(
        configuredUrl: 'https://api.enactspace.example.com/api/',
        releaseMode: true,
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      'https://api.enactspace.example.com',
    );
  });
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _values = {};
  final bool failWrites;
  int writeCount = 0;

  _MemorySecureStore({this.failWrites = false});

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount += 1;
    if (failWrites) throw StateError('secure write failed');
    _values[key] = value;
  }
}
