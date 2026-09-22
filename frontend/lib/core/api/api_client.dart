import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_storage.dart';

class ApiClient {
  static const String _configuredServerUrl = String.fromEnvironment(
    'ENACTSPACE_API_URL',
    defaultValue: '',
  );

  static String get serverUrl {
    return resolveServerUrl(
      configuredUrl: _configuredServerUrl,
      releaseMode: kReleaseMode,
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
  }

  static String get baseUrl => '$serverUrl/api';

  @visibleForTesting
  static String resolveServerUrl({
    required String configuredUrl,
    required bool releaseMode,
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    if (configuredUrl.trim().isEmpty) {
      if (releaseMode) {
        throw StateError(
          'ENACTSPACE_API_URL est obligatoire pour une version release.',
        );
      }
      if (!isWeb && platform == TargetPlatform.android) {
        return 'http://10.0.2.2:8000';
      }
      return 'http://127.0.0.1:8000';
    }

    final normalized = _normalizeServerUrl(configuredUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('ENACTSPACE_API_URL doit être une URL absolue valide.');
    }
    if (releaseMode && uri.scheme.toLowerCase() != 'https') {
      throw StateError('ENACTSPACE_API_URL doit utiliser HTTPS en release.');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw StateError('ENACTSPACE_API_URL doit utiliser HTTP ou HTTPS.');
    }
    return normalized;
  }

  static String _normalizeServerUrl(String value) {
    final withoutTrailingSlash = value.trim().replaceFirst(RegExp(r'/+$'), '');
    return withoutTrailingSlash.replaceFirst(RegExp(r'/api$'), '');
  }

  final http.Client _client;
  final AuthStorage authStorage;
  final Duration requestTimeout;
  static final Expando<_RefreshOperation> _refreshes = Expando();

  ApiClient({
    http.Client? client,
    AuthStorage? authStorage,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       authStorage = authStorage ?? AuthStorage.instance;

  static bool _canRefresh(String path) {
    final route = Uri.parse(path).path.replaceFirst(RegExp(r'/+$'), '');
    return !{
      '/auth/login',
      '/auth/token',
      '/auth/refresh',
      '/auth/logout',
      '/auth/logout-all',
      '/auth/join-requests',
      '/auth/password-reset/request',
      '/auth/password-reset/confirm',
    }.contains(route);
  }

  Future<http.Response> sendAuthenticated(
    String path, {
    required String? token,
    required Future<http.Response> Function(String? token) send,
  }) async {
    final generation = authStorage.generation;
    final pair = token == null ? null : await authStorage.readTokenPair();
    final ownsToken =
        token != null && pair != null && authStorage.ownsAccessToken(token);
    if (generation != authStorage.generation) throw _sessionExpired();
    final response = await send(token).timeout(requestTimeout);
    if (token != null && generation != authStorage.generation) {
      throw _sessionExpired();
    }
    if (response.statusCode != 401 || !ownsToken || !_canRefresh(path)) {
      return response;
    }
    final access = await refreshSession(
      failedAccessToken: token,
      expectedGeneration: generation,
    );
    if (generation != authStorage.generation) throw _sessionExpired();
    // Rebuild buffered requests once. Never recurse through the auth mechanism.
    final retried = await send(access).timeout(requestTimeout);
    if (generation != authStorage.generation) throw _sessionExpired();
    if (retried.statusCode == 401) {
      final current = await authStorage.readTokenPair();
      if (current?.accessToken == access) {
        await authStorage.clearAuthSecrets(expectedGeneration: generation);
      }
      throw _sessionExpired();
    }
    return retried;
  }

  Future<String> refreshSession({
    String? failedAccessToken,
    int? expectedGeneration,
  }) async {
    final generation = expectedGeneration ?? authStorage.generation;
    final pair = await authStorage.readTokenPair();
    if (generation != authStorage.generation) throw _sessionExpired();
    final running = _refreshes[authStorage];
    if (running != null && running.generation == generation) {
      return running.future;
    }
    // A delayed 401 may arrive after the shared refresh already completed.
    if (failedAccessToken != null &&
        pair != null &&
        pair.accessToken != failedAccessToken &&
        pair.accessToken.isNotEmpty) {
      return pair.accessToken;
    }
    if (pair?.refreshToken == null || pair!.refreshToken!.isEmpty) {
      await authStorage.clearAuthSecrets(expectedGeneration: generation);
      throw _sessionExpired();
    }
    final operation = _RefreshOperation(generation, _rotate(pair, generation));
    _refreshes[authStorage] = operation;
    try {
      return await operation.future;
    } finally {
      if (identical(_refreshes[authStorage], operation)) {
        _refreshes[authStorage] = null;
      }
    }
  }

  Future<String> _rotate(AuthTokens previous, int generation) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/refresh'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'refresh_token': previous.refreshToken}),
        )
        .timeout(requestTimeout);
    if (response.statusCode == 401 || response.statusCode == 403) {
      await authStorage.clearAuthSecrets(expectedGeneration: generation);
      throw _sessionExpired();
    }
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Renouvellement temporairement indisponible. Réessayez.',
      );
    }
    final data = decodeResponse(response);
    if (data is! Map<String, dynamic> ||
        data['access_token'] is! String ||
        (data['access_token'] as String).isEmpty ||
        data['refresh_token'] is! String ||
        (data['refresh_token'] as String).isEmpty) {
      throw ApiException(
        statusCode: 502,
        message: 'Réponse de session invalide.',
      );
    }
    final next = AuthTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    if (!await authStorage.rotateTokenPair(next, generation)) {
      // A logout/new login won the race. Do not resurrect its old session.
      try {
        await _revokePair(next);
      } catch (_) {
        /* Best effort, as for offline logout. */
      }
      throw _sessionExpired();
    }
    return next.accessToken;
  }

  Future<void> logoutSession({bool all = false}) async {
    final generation = authStorage.generation;
    final running = _refreshes[authStorage];
    if (running != null && running.generation == authStorage.generation) {
      try {
        await running.future;
      } catch (_) {
        /* Local logout must still finish. */
      }
    }
    AuthTokens? pair;
    try {
      pair = await authStorage.readTokenPair();
    } catch (_) {
      await authStorage.clearAuthSecrets(expectedGeneration: generation);
      rethrow;
    }
    if (generation != authStorage.generation) {
      if (all) throw _sessionExpired();
      return;
    }
    if (all) {
      try {
        if (pair == null) throw _sessionExpired();
        await _logoutAll(pair, generation);
      } finally {
        // A remote failure must never leave credentials on this device.
        await authStorage.clearAuthSecrets(expectedGeneration: generation);
      }
      return;
    }
    await authStorage.clearAuthSecrets(expectedGeneration: generation);
    if (pair == null) return;
    try {
      await _revokePair(pair);
    } catch (_) {
      /* Offline logout clears local secrets. */
    }
  }

  Future<void> _logoutAll(AuthTokens pair, int generation) async {
    var response = await _postLogoutAll(pair.accessToken);
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (pair.refreshToken == null || pair.refreshToken!.isEmpty) {
        throw _sessionExpired();
      }
      // Explicitly rotate once; /auth/logout-all remains excluded from the
      // generic 401 interceptor so this path cannot recurse.
      final access = await refreshSession(
        failedAccessToken: pair.accessToken,
        expectedGeneration: generation,
      );
      if (generation != authStorage.generation) throw _sessionExpired();
      response = await _postLogoutAll(access);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw _sessionExpired();
      }
    }
    decodeResponse(response);
  }

  Future<http.Response> _postLogoutAll(String accessToken) => _client
      .post(
        Uri.parse('$baseUrl/auth/logout-all'),
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(requestTimeout);

  Future<void> _revokePair(AuthTokens pair) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            if (pair.accessToken.isNotEmpty)
              'Authorization': 'Bearer ${pair.accessToken}',
          },
          body: jsonEncode({'refresh_token': pair.refreshToken ?? ''}),
        )
        .timeout(requestTimeout);
    decodeResponse(response);
  }

  static ApiException _sessionExpired() => ApiException(
    statusCode: 401,
    message: 'Session expirée. Reconnectez-vous.',
  );

  Future<dynamic> postMultipart(
    String path, {
    required String token,
    required List<int> bytes,
    required String fileName,
    Map<String, String> fields = const {},
  }) async {
    final bufferedBytes = List<int>.of(bytes);
    final bufferedFields = Map<String, String>.of(fields);
    final response = await sendAuthenticated(
      path,
      token: token,
      send: (access) async {
        // MultipartRequest streams are single-use; rebuild from the original bytes.
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl$path'),
        );
        request.headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $access',
        });
        request.fields.addAll(bufferedFields);
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bufferedBytes,
            filename: fileName,
          ),
        );
        return http.Response.fromStream(await _client.send(request));
      },
    );
    return decodeResponse(response);
  }

  Future<List<int>> getBytes(String url, {required String token}) async {
    final uri = Uri.parse(url);
    // Public external media must never receive our API bearer credential.
    final local = uri.origin == Uri.parse(serverUrl).origin;
    final response = await sendAuthenticated(
      uri.path,
      token: local ? token : null,
      send: (access) => _client.get(
        uri,
        headers: {if (access != null) 'Authorization': 'Bearer $access'},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Média indisponible.',
      );
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> postForm(
    String path, {
    required Map<String, String> data,
    String? token,
  }) async {
    final body = Map<String, String>.of(data);
    final response = await sendAuthenticated(
      path,
      token: token,
      send: (token) => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: body,
      ),
    );

    return decodeResponse(response);
  }

  Future<dynamic> postJson(
    String path, {
    required Map<String, dynamic> data,
    String? token,
  }) async {
    final body = jsonEncode(data);
    final response = await sendAuthenticated(
      path,
      token: token,
      send: (token) => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: body,
      ),
    );

    return decodeResponse(response);
  }

  Future<dynamic> patchJson(
    String path, {
    required Map<String, dynamic> data,
    String? token,
  }) async {
    final body = jsonEncode(data);
    final response = await sendAuthenticated(
      path,
      token: token,
      send: (token) => _client.patch(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: body,
      ),
    );

    return decodeResponse(response);
  }

  Future<dynamic> putJson(
    String path, {
    required Map<String, dynamic> data,
    String? token,
  }) async {
    final body = jsonEncode(data);
    final response = await sendAuthenticated(
      path,
      token: token,
      send: (token) => _client.put(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: body,
      ),
    );
    return decodeResponse(response);
  }

  Future<dynamic> get(String path, {String? token}) async {
    final response = await sendAuthenticated(
      path,
      token: token,
      send: (token) => _client.get(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    return decodeResponse(response);
  }

  Future<String> getText(String path, {String? token}) async {
    final response = await sendAuthenticated(
      path,
      token: token,
      send: (token) => _client.get(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Accept': 'text/csv,text/plain,*/*',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return utf8.decode(response.bodyBytes);
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: 'Erreur serveur ${response.statusCode}',
    );
  }

  Future<dynamic> delete(String path, {String? token}) async {
    final response = await sendAuthenticated(
      path,
      token: token,
      send: (token) => _client.delete(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    return decodeResponse(response);
  }

  dynamic decodeResponse(http.Response response) {
    dynamic body = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          statusCode: response.statusCode >= 400 ? response.statusCode : 502,
          message: 'Réponse serveur indisponible ou invalide.',
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String message = 'Erreur serveur ${response.statusCode}';

    if (body is Map<String, dynamic>) {
      if (body['detail'] is String) {
        message = body['detail'];
      } else if (body['detail'] != null) {
        message = body['detail'].toString();
      }
    }

    throw ApiException(statusCode: response.statusCode, message: message);
  }
}

class _RefreshOperation {
  final int generation;
  final Future<String> future;
  _RefreshOperation(this.generation, this.future);
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
