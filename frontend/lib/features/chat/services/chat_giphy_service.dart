import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GiphyItem {
  final String id;
  final String title;
  final String previewUrl;
  final String displayUrl;
  const GiphyItem({required this.id, required this.title, required this.previewUrl, required this.displayUrl});
  factory GiphyItem.fromJson(Map<String, dynamic> value) {
    final images = value['images'] as Map<String, dynamic>;
    final preview = images['fixed_width'] as Map<String, dynamic>;
    final display = (images['downsized'] ?? images['original']) as Map<String, dynamic>;
    return GiphyItem(id: value['id'] as String, title: value['title'] as String? ?? 'GIF',
      previewUrl: preview['url'] as String, displayUrl: display['url'] as String);
  }
}

class ChatGiphyService {
  static String get configuredKey => selectGiphyPlatformKey(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    webKey: const String.fromEnvironment('ENACTSPACE_GIPHY_API_KEY_WEB'),
    androidKey: const String.fromEnvironment('ENACTSPACE_GIPHY_API_KEY_ANDROID'),
    iosKey: const String.fromEnvironment('ENACTSPACE_GIPHY_API_KEY_IOS'),
  );
  static bool get configured => configuredKey.isNotEmpty;
  final http.Client client;
  final String apiKey;
  ChatGiphyService({http.Client? client, String? apiKey})
      : client = client ?? http.Client(), apiKey = apiKey ?? configuredKey;

  Future<List<GiphyItem>> search({String query = '', int offset = 0}) async {
    if (apiKey.isEmpty) { throw StateError('Catalogue non configuré.'); }
    final uri = Uri.https('api.giphy.com', '/v1/gifs/${query.isEmpty ? 'trending' : 'search'}', {
      'api_key': apiKey, 'limit': '24', 'offset': '$offset', 'rating': 'pg',
      if (query.isNotEmpty) 'q': query,
      if (query.isNotEmpty) 'lang': 'fr',
    });
    final response = await client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) { throw StateError('Catalogue indisponible.'); }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['data'] as List).map((value) => GiphyItem.fromJson(value as Map<String, dynamic>)).toList();
  }

  Future<GiphyItem> byId(String id) async {
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(id) || apiKey.isEmpty) { throw StateError('GIF indisponible.'); }
    final response = await client.get(Uri.https('api.giphy.com', '/v1/gifs/$id', {'api_key': apiKey})).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) { throw StateError('GIF indisponible.'); }
    return GiphyItem.fromJson((jsonDecode(response.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }
  void dispose() => client.close();
}

String selectGiphyPlatformKey({
  required bool isWeb,
  required TargetPlatform platform,
  required String webKey,
  required String androidKey,
  required String iosKey,
}) {
  if (isWeb) { return webKey; }
  return switch (platform) {
    TargetPlatform.android => androidKey,
    TargetPlatform.iOS => iosKey,
    _ => '',
  };
}
