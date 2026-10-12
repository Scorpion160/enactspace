import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/features/chat/services/chat_giphy_service.dart';

Map<String, dynamic> item(String id) => {'id': id, 'title': 'Merci !', 'images': {
  'fixed_width': {'url': 'https://media.giphy.com/$id/preview.gif?keep=yes'},
  'downsized': {'url': 'https://media.giphy.com/$id/full.gif?keep=yes'},
}};
void main() {
  test('web, Android and iOS use separate keys without cross-platform fallback', () {
    String key(bool web, TargetPlatform platform, {String ios = 'ios-key'}) => selectGiphyPlatformKey(
      isWeb: web, platform: platform, webKey: 'web-key', androidKey: 'android-key', iosKey: ios);
    expect(key(true, TargetPlatform.iOS), 'web-key');
    expect(key(false, TargetPlatform.android), 'android-key');
    expect(key(false, TargetPlatform.iOS), 'ios-key');
    expect(key(false, TargetPlatform.iOS, ios: ''), isEmpty);
    expect(key(false, TargetPlatform.macOS), isEmpty);
  });
  test('search preserves query and URL parameters with pagination', () async {
    final service = ChatGiphyService(apiKey: 'test', client: MockClient((request) async {
      expect(request.url.host, 'api.giphy.com');
      expect(request.url.path, '/v1/gifs/search');
      expect(request.url.queryParameters['q'], 'Merci équipe !');
      expect(request.url.queryParameters['offset'], '24');
      return http.Response(jsonEncode({'data': [item('abc')]}), 200);
    }));
    addTearDown(service.dispose);
    final gifs = await service.search(query: 'Merci équipe !', offset: 24);
    expect(gifs.single.previewUrl, endsWith('?keep=yes'));
    expect(gifs.single.id, 'abc');
  });
  test('trending is used without a query and API errors remain retryable', () async {
    var calls = 0;
    final service = ChatGiphyService(apiKey: 'test', client: MockClient((request) async {
      expect(request.url.path, '/v1/gifs/trending');
      calls++;
      return calls == 1 ? http.Response('', 429) : http.Response(jsonEncode({'data': [item('abc')]}), 200);
    }));
    addTearDown(service.dispose);
    await expectLater(service.search(), throwsStateError);
    expect((await service.search()).length, 1);
  });
  test('a shared GIF is resolved by ID rather than a stored media URL', () async {
    final service = ChatGiphyService(apiKey: 'test', client: MockClient((request) async {
      expect(request.url.path, '/v1/gifs/abc');
      return http.Response(jsonEncode({'data': item('abc')}), 200);
    }));
    addTearDown(service.dispose);
    expect((await service.byId('abc')).displayUrl, endsWith('?keep=yes'));
    await expectLater(service.byId('../invalid'), throwsStateError);
  });
}
