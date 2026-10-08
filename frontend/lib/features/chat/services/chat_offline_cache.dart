import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage_options.dart';
import '../../../core/storage/session_private_data.dart';

abstract interface class ChatOfflineCacheStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureChatOfflineCacheStore implements ChatOfflineCacheStore {
  final FlutterSecureStorage _storage;

  const SecureChatOfflineCacheStore({this._storage = enactSpaceSecureStorage});

  @override
  Future<String?> read() => _storage.read(key: chatOfflineCacheSecureKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: chatOfflineCacheSecureKey, value: value);

  @override
  Future<void> delete() => _storage.delete(key: chatOfflineCacheSecureKey);
}
