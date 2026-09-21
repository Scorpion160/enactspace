import 'package:shared_preferences/shared_preferences.dart';

const legacyChatAttachmentDraftsKey = '_chat_attachment_drafts_v1';

const _privateSessionKeyPrefixes = <String>[
  '_chat_messages_cache_',
  'enactspace_chat_',
];

final sessionPrivateMemoryCache = SessionPrivateMemoryCache();

class SessionPrivateMemoryCache {
  final Map<String, Object> _values = {};

  T? read<T extends Object>(String key) => _values[key] as T?;

  void write(String key, Object value) => _values[key] = value;

  Iterable<String> get keys => _values.keys;

  bool remove(String key) => _values.remove(key) != null;

  void clear() => _values.clear();
}

Future<int> purgePrivateSessionPreferences(SharedPreferences preferences) {
  return _removeMatchingKeys(
    preferences,
    exactKeys: const {legacyChatAttachmentDraftsKey},
    prefixes: _privateSessionKeyPrefixes,
  );
}

void purgePrivateSessionMemory() => sessionPrivateMemoryCache.clear();

Future<int> purgeLegacyChatContentPreferences(SharedPreferences preferences) {
  return _removeMatchingKeys(
    preferences,
    prefixes: const [
      '_chat_messages_cache_',
      'enactspace_chat_messages_',
      'enactspace_chat_threads_',
    ],
  );
}

Future<int> _removeMatchingKeys(
  SharedPreferences preferences, {
  Set<String> exactKeys = const {},
  List<String> prefixes = const [],
}) async {
  final keys = preferences.getKeys().where(
    (key) => exactKeys.contains(key) || prefixes.any(key.startsWith),
  );
  var removed = 0;
  for (final key in keys.toList()) {
    if (await preferences.remove(key)) removed++;
  }
  return removed;
}
