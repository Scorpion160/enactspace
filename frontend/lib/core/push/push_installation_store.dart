import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../storage/secure_storage_options.dart';

abstract interface class PushInstallationStore {
  Future<String> installationKey(String userId);
  Future<String?> serverInstallationId(String userId);
  Future<void> writeServerInstallationId(String userId, String installationId);
}

class SecurePushInstallationStore implements PushInstallationStore {
  final FlutterSecureStorage storage;
  final Uuid uuid;

  const SecurePushInstallationStore({
    this.storage = enactSpaceSecureStorage,
    this.uuid = const Uuid(),
  });

  String _key(String userId) => 'enactspace.push.installation.$userId';
  String _serverKey(String userId) =>
      'enactspace.push.server_installation.$userId';

  @override
  Future<String> installationKey(String userId) async {
    final existing = await storage.read(key: _key(userId));
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = uuid.v4();
    await storage.write(key: _key(userId), value: generated);
    return generated;
  }

  @override
  Future<String?> serverInstallationId(String userId) =>
      storage.read(key: _serverKey(userId));

  @override
  Future<void> writeServerInstallationId(
    String userId,
    String installationId,
  ) => storage.write(key: _serverKey(userId), value: installationId);
}
