import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/push/push_platform.dart';
import '../../../core/theme/appearance_controller.dart';
import '../chat/models/chat_models.dart';
import '../chat/services/chat_gateway.dart';
import '../chat/services/chat_service.dart';
import '../documents/models/document_model.dart';
import '../documents/services/documents_service.dart';
import '../posts/services/posts_gateway.dart';
import 'demo_heritage_data.dart';
import 'demo_native_data.dart';

/// No overridden operation can delegate to the live HTTP client or auth store.
class DemoNativeApi extends ApiClient {
  DemoNativeApi(this.data) : super(client: _LocalOnlyHttpClient());
  final DemoNativeData data;
  final media = <String, Uint8List>{};

  @override
  Future<dynamic> get(String path, {String? token}) async =>
      data.handle('GET', path);
  @override
  Future<dynamic> postJson(
    String path, {
    required Map<String, dynamic> data,
    String? token,
  }) async {
    if (path == '/chat/uploads' || path == '/posts/uploads') {
      final raw = data['data_base64'] ?? data['data'];
      if (raw is! String || raw.length > 14000000) throw _blocked();
      final bytes = base64Decode(raw.split(',').last);
      final url = 'https://demo.invalid/media/${media.length}';
      media[url] = bytes;
      return {
        'id': 'demo-upload-${media.length}',
        'file_id': 'demo-upload-${media.length}',
        'url': url,
        'file_url': url,
        'file_name': data['file_name'],
        'message_type': data['message_type'],
        'content_type': data['content_type'],
        'size_bytes': bytes.length,
      };
    }
    return this.data.handle('POST', path, data);
  }

  @override
  Future<dynamic> patchJson(
    String path, {
    required Map<String, dynamic> data,
    String? token,
  }) async => this.data.handle('PATCH', path, data);
  @override
  Future<dynamic> putJson(
    String path, {
    required Map<String, dynamic> data,
    String? token,
  }) async => this.data.handle('PUT', path, data);
  @override
  Future<dynamic> delete(String path, {String? token}) async =>
      data.handle('DELETE', path);
  @override
  Future<Map<String, dynamic>> postForm(
    String path, {
    required Map<String, String> data,
    String? token,
  }) async => throw _blocked();
  @override
  Future<dynamic> postMultipart(
    String path, {
    required String token,
    required List<int> bytes,
    required String fileName,
    Map<String, String> fields = const {},
  }) async => throw _blocked();
  @override
  Future<dynamic> postMultipartFiles(
    String path, {
    String? token,
    Map<String, String> fields = const {},
    required Map<String, ({String name, List<int> bytes})> files,
  }) async => throw _blocked();
  @override
  Future<List<int>> getBytes(String url, {required String token}) async =>
      loadAsset(url);
  @override
  Future<String> getText(String path, {String? token}) async =>
      throw _blocked();
  @override
  Future<http.Response> sendAuthenticated(
    String path, {
    required String? token,
    required Future<http.Response> Function(String? token) send,
  }) async => throw _blocked();
  @override
  Future<String> refreshSession({
    String? failedAccessToken,
    int? expectedGeneration,
  }) async => throw _blocked();
  @override
  Future<void> logoutSession({bool all = false}) async {}

  Future<Uint8List> loadAsset(String url) async {
    if (media.containsKey(url)) return media[url]!;
    var path = url;
    if (Uri.tryParse(url)?.hasScheme == true) {
      path = Uri.parse(url).path.replaceFirst(RegExp(r'^/'), '');
    }
    const docs = {
      'assets/documents/terrasen-world-cup.pdf',
      'assets/documents/aquatus-synthese.pdf',
      'assets/documents/shery-presentation.pdf',
      'assets/documents/men-nan-presentation.pdf',
    };
    final allowed = {
      ...docs,
      for (final m in demoHeritage) m['image_asset'] as String,
    };
    if (!allowed.contains(path)) throw _blocked();
    return (await rootBundle.load(path)).buffer.asUint8List();
  }

  ApiException _blocked() => ApiException(
    statusCode: 400,
    message:
        'Cette action est désactivée dans la démo. Aucun service réel n’est contacté.',
  );
}

class DemoNativeAuth extends AuthService {
  DemoNativeAuth(this.data, {this.cacheProfile = true})
    : super(apiClient: DemoNativeApi(data));
  final DemoNativeData data;
  final bool cacheProfile;
  @override
  Future<String?> getToken() async => 'demo-local-never-a-real-token';
  @override
  Future<bool> isLoggedIn() async => true;
  @override
  Future<Map<String, dynamic>> getCurrentUser() async => Map.of(data.user);
  @override
  Future<Map<String, dynamic>?> getCachedCurrentUser() async =>
      cacheProfile ? Map.of(data.user) : null;
  @override
  Future<void> logout() async {}
  @override
  Future<void> logoutAll() async {}
  @override
  Future<String> login({
    String? identifier,
    String? email,
    required String password,
  }) async =>
      throw StateError('La visite ne crée pas de session authentifiée.');
}

class DemoNativeRealtime extends RealtimeService {
  DemoNativeRealtime(DemoNativeData data)
    : super(authService: DemoNativeAuth(data));
  @override
  Stream<Map<String, dynamic>> get events => const Stream.empty();
  @override
  Future<void> start() async {}
  @override
  void send(Map<String, dynamic> event) {}
  @override
  Future<void> dispose() async {
    await super.dispose();
  }
}

/// The real chat interface, with visit-local pinning, outbox and cache settings.
class DemoNativeChatGateway extends ApiChatGateway {
  DemoNativeChatGateway({
    required super.chatService,
    required super.authService,
    required super.polesService,
    required super.projectsService,
    required super.realtimeService,
  });
  final pins = <String>{}, hidden = <String>{};
  final messagePins = <String, Set<String>>{};
  final pending = <String, List<Map<String, dynamic>>>{};
  ChatMediaCacheSettings settings = const ChatMediaCacheSettings();
  @override
  Future<List<ChatThreadModel>> getCachedThreads({
    required String userId,
  }) async => [];
  @override
  Future<void> cacheThreads({
    required String userId,
    required List<ChatThreadModel> threads,
  }) async {}
  @override
  Future<List<ChatMessageModel>> getCachedMessages({
    required String userId,
    required String threadId,
  }) async => [];
  @override
  Future<void> cacheMessages({
    required String userId,
    required String threadId,
    required List<ChatMessageModel> messages,
  }) async {}
  @override
  Future<Set<String>> getPinnedThreadIds({required String userId}) async =>
      Set.of(pins);
  @override
  Future<Set<String>> getHiddenThreadIds({required String userId}) async =>
      Set.of(hidden);
  @override
  Future<void> setThreadHidden({
    required String userId,
    required String threadId,
    required bool hidden,
  }) async {
    hidden ? this.hidden.add(threadId) : this.hidden.remove(threadId);
  }

  @override
  Future<void> setThreadPinned({
    required String userId,
    required String threadId,
    required bool pinned,
  }) async {
    pinned ? pins.add(threadId) : pins.remove(threadId);
  }

  @override
  Future<Set<String>> getPinnedMessageIds({
    required String userId,
    required String threadId,
  }) async => Set.of(messagePins[threadId] ?? {});
  @override
  Future<void> setMessagePinned({
    required String userId,
    required String threadId,
    required String messageId,
    required bool pinned,
  }) async {
    final ids = messagePins.putIfAbsent(threadId, () => {});
    pinned ? ids.add(messageId) : ids.remove(messageId);
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingMessages({
    required String userId,
    required String threadId,
  }) async => List.of(pending[threadId] ?? []);
  @override
  Future<void> cachePendingMessage({
    required String userId,
    required String threadId,
    required Map<String, dynamic> message,
  }) async {
    pending.putIfAbsent(threadId, () => []).add(message);
  }

  @override
  Future<void> removePendingMessage({
    required String userId,
    required String threadId,
    required String clientMessageId,
  }) async {
    pending[threadId]?.removeWhere(
      (m) => m['client_message_id'] == clientMessageId,
    );
  }

  @override
  Future<ChatMediaCacheSettings> getMediaCacheSettings({
    required String userId,
  }) async => settings;
  @override
  Future<void> setMediaCacheSettings({
    required String userId,
    required ChatMediaCacheSettings settings,
  }) async {
    this.settings = settings;
  }

  @override
  Future<int> estimateLocalMediaCacheBytes({required String userId}) async => 0;
  @override
  Future<int> clearLocalMediaCache({required String userId}) async => 0;
}

class DemoNativeDocumentsService extends DocumentsService {
  DemoNativeDocumentsService(this.api, this.auth)
    : super(apiClient: api, authService: auth);
  final DemoNativeApi api;
  final DemoNativeAuth auth;
  @override
  Future<DocumentModel> getDocument(String documentId) async =>
      DocumentModel.fromJson(
        Map<String, dynamic>.from(await api.get('/documents/$documentId')),
      );
  @override
  Future<List<DocumentModel>> getDocuments({
    String? search,
    String? eventId,
    String? category,
    String? status,
    String? visibility,
    String? poleId,
    String? projectId,
    bool? isTemplate,
    bool? isOfficial,
  }) async => api.data
      .rows('/documents')
      .where(
        (d) =>
            (poleId == null || d['pole_id'] == poleId) &&
            (projectId == null || d['project_id'] == projectId) &&
            (search?.isNotEmpty != true ||
                '${d['title']}'.toLowerCase().contains(search!.toLowerCase())),
      )
      .map((d) => DocumentModel.fromJson(Map.of(d)))
      .toList();
}

class DemoNativePostsGateway extends ApiPostsGateway {
  DemoNativePostsGateway(
    this.api, {
    required super.postsService,
    required super.membersService,
    required super.authService,
    required super.polesService,
    required super.projectsService,
  }) : super(httpClient: _LocalOnlyHttpClient());
  final DemoNativeApi api;
  @override
  Future<Uint8List> loadMediaBytes(String url) => api.loadAsset(url);
}

class DemoAppearanceStore implements AppearancePreferenceStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class DemoNativePushPlatform implements PushPlatform {
  @override
  bool get supported => true;
  @override
  bool get configured => false;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<PushIncomingMessage> get foregroundMessages => const Stream.empty();
  @override
  Stream<PushIncomingMessage> get openedMessages => const Stream.empty();
  @override
  Future<bool> initialize() async => false;
  @override
  Future<PushAuthorization> permissionStatus() async =>
      PushAuthorization.denied;
  @override
  Future<PushAuthorization> requestPermission() async =>
      PushAuthorization.denied;
  @override
  Future<String?> currentToken() async => null;
  @override
  Future<void> deleteToken() async {}
  @override
  Future<PushIncomingMessage?> initialMessage() async => null;
}

class _LocalOnlyHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw StateError('No network transport exists inside the demo.');
}
