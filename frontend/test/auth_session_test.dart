import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_storage.dart';

const oldPair = AuthTokens(
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
);
const newPair = AuthTokens(
  accessToken: 'new-access',
  refreshToken: 'new-refresh',
);

http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemorySecureStore secure;
  late AuthStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    secure = MemorySecureStore();
    storage = AuthStorage(secureStore: secure);
    await storage.writeTokenPair(oldPair);
  });

  ApiClient api(FutureOr<http.Response> Function(http.Request) handler) =>
      ApiClient(
        client: MockClient((request) async => handler(request)),
        authStorage: storage,
      );

  test(
    'login persists the returned pair and profile using the shared secure store',
    () async {
      final password = Random.secure().nextInt(1 << 32).toString();
      final service = AuthService(
        apiClient: api((request) {
          if (request.url.path == '/api/auth/token') {
            expect(request.bodyFields['username'], 'session@example.test');
            expect(request.bodyFields['password'], password);
            return jsonResponse(newPair.toJson());
          }
          expect(request.headers['authorization'], 'Bearer new-access');
          return jsonResponse({'id': 'new-member'});
        }),
      );
      await service.login(email: 'session@example.test', password: password);
      expect((await storage.readTokenPair())!.toJson(), newPair.toJson());
      expect(await service.getCachedCurrentUser(), {'id': 'new-member'});
    },
  );

  test('logout invalidates a pending login response', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final service = AuthService(
      apiClient: api((_) async {
        started.complete();
        await release.future;
        return jsonResponse(newPair.toJson());
      }),
    );
    final outcome = expectLater(
      service.login(
        email: 'session@example.test',
        password: Random.secure().nextInt(1 << 32).toString(),
      ),
      throwsStateError,
    );
    await started.future;
    await storage.clearAuthSecrets();
    release.complete();
    await outcome;
    expect(await storage.readTokenPair(), isNull);
  });

  test(
    'buffered multipart retries rebuild a consumed stream with the same bytes',
    () async {
      var uploads = 0;
      var refreshes = 0;
      final client = api((request) {
        if (request.url.path == '/api/auth/refresh') {
          refreshes++;
          return jsonResponse(newPair.toJson());
        }
        uploads++;
        expect(request.body, contains('filename="sample.txt"'));
        expect(request.body, contains('test-content'));
        expect(request.body, contains('document'));
        expect(
          request.headers['authorization'],
          uploads == 1 ? 'Bearer old-access' : 'Bearer new-access',
        );
        return jsonResponse({}, uploads == 1 ? 401 : 200);
      });
      await client.postMultipart(
        '/files/upload',
        token: 'old-access',
        bytes: utf8.encode('test-content'),
        fileName: 'sample.txt',
        fields: {'storage_scope': 'document'},
      );
      expect(uploads, 2);
      expect(refreshes, 1);
    },
  );

  test('media sends credentials only to the configured API origin', () async {
    final client = api((request) {
      if (request.url.host == 'public-media.example.test') {
        expect(request.headers.containsKey('authorization'), isFalse);
      } else {
        expect(request.headers['authorization'], 'Bearer old-access');
      }
      return http.Response('bytes', 200);
    });
    expect(
      await client.getBytes(
        '${ApiClient.serverUrl}/api/files/sample',
        token: 'old-access',
      ),
      utf8.encode('bytes'),
    );
    expect(
      await client.getBytes(
        'https://public-media.example.test/sample',
        token: 'old-access',
      ),
      utf8.encode('bytes'),
    );
  });

  test('CSV requests participate in automatic refresh', () async {
    var refreshes = 0;
    final client = api((request) {
      if (request.url.path == '/api/auth/refresh') {
        refreshes++;
        return jsonResponse(newPair.toJson());
      }
      return request.headers['authorization'] == 'Bearer old-access'
          ? jsonResponse({}, 401)
          : http.Response.bytes(utf8.encode('nom\nécole'), 200);
    });
    expect(await client.getText('/export', token: 'old-access'), 'nom\nécole');
    expect(refreshes, 1);
  });

  test(
    'token pair is one secure value; rotation and deletion clear legacy data',
    () async {
      SharedPreferences.setMockInitialValues({
        AuthStorage.legacyAccessTokenKey: 'legacy',
      });
      await storage.rotateTokenPair(newPair, storage.generation);
      expect(secure.values.length, 1);
      expect((await storage.readTokenPair())!.refreshToken, 'new-refresh');
      expect(await storage.readAccessToken(), 'new-access');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await storage.clearAuthSecrets();
      expect(await storage.readTokenPair(), isNull);
      expect(secure.values, isEmpty);
    },
  );

  test('failed secure rotation cannot leave a mixed token pair', () async {
    secure.failWrites = true;
    await expectLater(
      storage.rotateTokenPair(newPair, storage.generation),
      throwsStateError,
    );
    expect((await storage.readTokenPair())!.toJson(), oldPair.toJson());
  });

  test('pair reads finish interrupted legacy cleanup', () async {
    SharedPreferences.setMockInitialValues({
      AuthStorage.legacyAccessTokenKey: 'legacy',
    });
    expect((await storage.readTokenPair())!.toJson(), oldPair.toJson());
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('corrupt pair never resurrects a stale legacy credential', () async {
    secure.values[secure.values.keys.single] = 'invalid-json';
    SharedPreferences.setMockInitialValues({
      AuthStorage.legacyAccessTokenKey: 'legacy',
    });
    expect(await storage.readTokenPair(), isNull);
    expect(await storage.readAccessToken(), isNull);
    expect(secure.values, isEmpty);
  });

  test(
    'eligible 401 rotates and retries the same mutation exactly once',
    () async {
      var refreshes = 0;
      final authorization = <String?>[];
      final bodies = <String>[];
      final client = api((request) {
        if (request.url.path == '/api/auth/refresh') {
          refreshes++;
          expect(jsonDecode(request.body), {'refresh_token': 'old-refresh'});
          expect(request.url.query, isEmpty);
          return jsonResponse(newPair.toJson());
        }
        authorization.add(request.headers['authorization']);
        bodies.add(request.body);
        expect(request.method, 'POST');
        return authorization.length == 1
            ? jsonResponse({}, 401)
            : jsonResponse({'ok': true});
      });
      expect(
        await client.postJson(
          '/tasks',
          token: 'old-access',
          data: {'title': 'test'},
        ),
        {'ok': true},
      );
      expect(refreshes, 1);
      expect(authorization, ['Bearer old-access', 'Bearer new-access']);
      expect(bodies[0], bodies[1]);
      expect((await storage.readTokenPair())!.toJson(), newPair.toJson());
    },
  );

  test(
    'simultaneous 401s across clients share one refresh and the rotated token',
    () async {
      final allInitial = Completer<void>();
      final refreshStarted = Completer<void>();
      final release = Completer<void>();
      var initial = 0;
      var refreshes = 0;
      var retries = 0;
      Future<http.Response> handler(http.Request request) async {
        if (request.url.path == '/api/auth/refresh') {
          refreshes++;
          refreshStarted.complete();
          await release.future;
          return jsonResponse(newPair.toJson());
        }
        if (request.headers['authorization'] == 'Bearer old-access') {
          initial++;
          if (initial == 3) allInitial.complete();
          return jsonResponse({}, 401);
        }
        expect(request.headers['authorization'], 'Bearer new-access');
        retries++;
        return jsonResponse({'ok': true});
      }

      final requests = List.generate(
        3,
        (i) => api(handler).get('/tasks/$i', token: 'old-access'),
      );
      await Future.wait([allInitial.future, refreshStarted.future]);
      expect(refreshes, 1);
      release.complete();
      await Future.wait(requests);
      expect(refreshes, 1);
      expect(retries, 3);
    },
  );

  test(
    'a delayed old-token 401 uses the completed rotation without another refresh',
    () async {
      final lateStarted = Completer<void>();
      final releaseLate = Completer<void>();
      var refreshes = 0;
      final client = api((request) async {
        if (request.url.path == '/api/auth/refresh') {
          refreshes++;
          return jsonResponse(newPair.toJson());
        }
        if (request.headers['authorization'] == 'Bearer new-access') {
          return jsonResponse({});
        }
        if (request.url.path.endsWith('/late')) {
          lateStarted.complete();
          await releaseLate.future;
        }
        return jsonResponse({}, 401);
      });
      final late = client.get('/late', token: 'old-access');
      await lateStarted.future;
      await client.get('/first', token: 'old-access');
      releaseLate.complete();
      await late;
      expect(refreshes, 1);
    },
  );

  test('retry 401 clears credentials with no refresh loop', () async {
    var refreshes = 0;
    var requests = 0;
    final client = api((request) {
      if (request.url.path == '/api/auth/refresh') {
        refreshes++;
        return jsonResponse(newPair.toJson());
      }
      requests++;
      return jsonResponse({}, 401);
    });
    await expectLater(
      client.get('/tasks', token: 'old-access'),
      throwsA(isA<ApiException>()),
    );
    expect(refreshes, 1);
    expect(requests, 2);
    expect(await storage.readTokenPair(), isNull);
  });

  for (final path in [
    '/auth/login',
    '/auth/token',
    '/auth/refresh',
    '/auth/logout',
    '/auth/logout-all',
  ]) {
    test('$path never recursively refreshes', () async {
      var calls = 0;
      final client = api((_) {
        calls++;
        return jsonResponse({}, 401);
      });
      await expectLater(
        client.postJson(path, token: 'old-access', data: {}),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 1);
      expect(await storage.readTokenPair(), isNotNull);
    });
  }

  test(
    'public 401 and protected 403 do not refresh or erase credentials',
    () async {
      var calls = 0;
      final client = api((request) {
        calls++;
        return jsonResponse(
          {},
          request.headers.containsKey('authorization') ? 403 : 401,
        );
      });
      await expectLater(client.get('/public'), throwsA(isA<ApiException>()));
      await expectLater(
        client.get('/admin', token: 'old-access'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 2);
      expect(await storage.readTokenPair(), isNotNull);
    },
  );

  for (final code in [401, 403]) {
    test(
      'definitive refresh $code clears both tokens and signals session expiration',
      () async {
        final before = storage.sessionChanges.value;
        final client = api(
          (_) => jsonResponse({'detail': 'internal reason'}, code),
        );
        await expectLater(
          client.refreshSession(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'safe message',
              isNot(contains('internal reason')),
            ),
          ),
        );
        expect(await storage.readTokenPair(), isNull);
        expect(storage.sessionChanges.value, greaterThan(before));
      },
    );
  }

  for (final failure in ['503', 'network', 'timeout']) {
    test(
      'transient refresh $failure preserves the potentially valid credential',
      () async {
        final client = api((request) {
          if (request.url.path != '/api/auth/refresh') {
            return jsonResponse({}, 401);
          }
          if (failure == 'network') throw http.ClientException('offline');
          if (failure == 'timeout') throw TimeoutException('offline');
          return http.Response('unavailable', 503);
        });
        await expectLater(
          client.get('/tasks', token: 'old-access'),
          throwsA(isA<Exception>()),
        );
        expect((await storage.readTokenPair())!.toJson(), oldPair.toJson());
      },
    );
  }

  test(
    'logout calls server revocation and clears both tokens even offline',
    () async {
      var calls = 0;
      final service = AuthService(
        apiClient: api((request) {
          calls++;
          expect(request.url.path, '/api/auth/logout');
          expect(jsonDecode(request.body)['refresh_token'], 'old-refresh');
          throw http.ClientException('offline');
        }),
      );
      await service.logout();
      expect(calls, 1);
      expect(await storage.readTokenPair(), isNull);
    },
  );

  for (final code in [200, 503]) {
    test(
      'logout-all $code clears local secrets and reports remote failures',
      () async {
        var calls = 0;
        final service = AuthService(
          apiClient: api((request) {
            calls++;
            expect(request.url.path, '/api/auth/logout-all');
            expect(request.headers['authorization'], 'Bearer old-access');
            return jsonResponse({}, code);
          }),
        );
        if (code == 200) {
          await service.logoutAll();
        } else {
          await expectLater(service.logoutAll(), throwsA(isA<ApiException>()));
        }
        expect(calls, 1);
        expect(await storage.readTokenPair(), isNull);
      },
    );
  }

  test(
    'logout-all refreshes one expired access credential before revocation',
    () async {
      var logoutCalls = 0;
      var refreshCalls = 0;
      final service = AuthService(
        apiClient: api((request) {
          if (request.url.path == '/api/auth/refresh') {
            refreshCalls++;
            expect(jsonDecode(request.body)['refresh_token'], 'old-refresh');
            return jsonResponse(newPair.toJson());
          }
          expect(request.url.path, '/api/auth/logout-all');
          logoutCalls++;
          final access = request.headers['authorization'];
          if (access == 'Bearer old-access') return jsonResponse({}, 401);
          expect(access, 'Bearer new-access');
          return jsonResponse({'ok': true});
        }),
      );

      await service.logoutAll();

      expect(refreshCalls, 1);
      expect(logoutCalls, 2);
      expect(await storage.readTokenPair(), isNull);
    },
  );

  test('logout-all refresh/retry is bounded after a second 401', () async {
    var logoutCalls = 0;
    var refreshCalls = 0;
    final service = AuthService(
      apiClient: api((request) {
        if (request.url.path == '/api/auth/refresh') {
          refreshCalls++;
          return jsonResponse(newPair.toJson());
        }
        logoutCalls++;
        return jsonResponse({}, 401);
      }),
    );

    await expectLater(service.logoutAll(), throwsA(isA<ApiException>()));

    expect(refreshCalls, 1);
    expect(logoutCalls, 2);
    expect(await storage.readTokenPair(), isNull);
  });

  test('transient logout-all refresh failure clears and surfaces', () async {
    var logoutCalls = 0;
    var refreshCalls = 0;
    final service = AuthService(
      apiClient: api((request) {
        if (request.url.path == '/api/auth/refresh') {
          refreshCalls++;
          return http.Response('temporarily unavailable', 503);
        }
        logoutCalls++;
        return jsonResponse({}, 401);
      }),
    );

    await expectLater(
      service.logoutAll(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
    );

    expect(refreshCalls, 1);
    expect(logoutCalls, 1);
    expect(await storage.readTokenPair(), isNull);
  });

  test('unreachable logout-all server clears locally and surfaces', () async {
    final service = AuthService(
      apiClient: api((request) {
        expect(request.url.path, '/api/auth/logout-all');
        throw http.ClientException('offline');
      }),
    );

    await expectLater(
      service.logoutAll(),
      throwsA(isA<http.ClientException>()),
    );

    expect(await storage.readTokenPair(), isNull);
  });

  test(
    'bootstrap refreshes an expired access token and restores the profile',
    () async {
      var refreshes = 0;
      final service = AuthService(
        apiClient: api((request) {
          if (request.url.path == '/api/auth/refresh') {
            refreshes++;
            return jsonResponse(newPair.toJson());
          }
          return request.headers['authorization'] == 'Bearer new-access'
              ? jsonResponse({'id': 'test-member'})
              : jsonResponse({}, 401);
        }),
      );
      expect(await service.restoreSession(), isTrue);
      expect(refreshes, 1);
      expect(await service.getCachedCurrentUser(), {'id': 'test-member'});
    },
  );

  test('bootstrap with only a refresh token restores authentication', () async {
    await storage.writeTokenPair(
      const AuthTokens(accessToken: '', refreshToken: 'old-refresh'),
    );
    final service = AuthService(
      apiClient: api(
        (request) => jsonResponse(
          request.url.path == '/api/auth/refresh'
              ? newPair.toJson()
              : {'id': 'test-member'},
        ),
      ),
    );
    expect(await service.restoreSession(), isTrue);
  });

  test('bootstrap without credentials makes no network call', () async {
    await storage.clearAuthSecrets();
    final service = AuthService(
      apiClient: api((_) => throw StateError('unexpected request')),
    );
    expect(await service.restoreSession(), isFalse);
  });

  test('bootstrap with invalid refresh is unauthenticated', () async {
    final service = AuthService(apiClient: api((_) => jsonResponse({}, 401)));
    expect(await service.restoreSession(), isFalse);
    expect(await storage.readTokenPair(), isNull);
  });

  test('bootstrap transient failure is not a session rejection', () async {
    final service = AuthService(
      apiClient: api(
        (request) => jsonResponse(
          {},
          request.url.path == '/api/auth/refresh' ? 503 : 401,
        ),
      ),
    );
    await expectLater(service.restoreSession(), throwsA(isA<ApiException>()));
    expect(await service.isLoggedIn(), isTrue);
  });

  test('a late refresh cannot resurrect a cleared session', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var revocations = 0;
    final client = api((request) async {
      if (request.url.path == '/api/auth/logout') {
        revocations++;
        return http.Response('', 204);
      }
      started.complete();
      await release.future;
      return jsonResponse(newPair.toJson());
    });
    final outcome = expectLater(
      client.refreshSession(),
      throwsA(isA<ApiException>()),
    );
    await started.future;
    await storage.clearAuthSecrets();
    release.complete();
    await outcome;
    expect(await storage.readTokenPair(), isNull);
    expect(revocations, 1);
  });

  test('a previous account failure cannot clear the next login', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final service = AuthService(
      apiClient: api((_) async {
        started.complete();
        await release.future;
        return jsonResponse({}, 403);
      }),
    );
    final outcome = expectLater(
      service.getCurrentUser(),
      throwsA(isA<ApiException>()),
    );
    await started.future;
    await storage.writeTokenPair(newPair);
    release.complete();
    await outcome;
    expect((await storage.readTokenPair())!.toJson(), newPair.toJson());
  });

  test(
    'a retried response is discarded if logout wins while it is pending',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final client = api((request) async {
        if (request.url.path == '/api/auth/refresh') {
          return jsonResponse(newPair.toJson());
        }
        if (request.headers['authorization'] == 'Bearer old-access') {
          return jsonResponse({}, 401);
        }
        started.complete();
        await release.future;
        return jsonResponse({'private': 'previous session response'});
      });
      final outcome = expectLater(
        client.get('/tasks', token: 'old-access'),
        throwsA(isA<ApiException>()),
      );
      await started.future;
      await storage.clearAuthSecrets();
      release.complete();
      await outcome;
      expect(await storage.readTokenPair(), isNull);
    },
  );
}

class MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  bool failWrites = false;
  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('secure write failed');
    values[key] = value;
  }
}
