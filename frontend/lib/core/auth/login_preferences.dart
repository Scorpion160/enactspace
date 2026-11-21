import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/secure_storage_options.dart';

class LoginPreferences {
  static const _identifierKey = 'enactspace.auth.login_identifier';
  static const FlutterSecureStorage _storage = enactSpaceSecureStorage;

  const LoginPreferences._();

  static Future<String?> readIdentifier() async {
    final value = (await _storage.read(key: _identifierKey))?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> rememberIdentifier(String identifier) async {
    final value = identifier.trim();
    if (value.isEmpty) return;
    await _storage.write(key: _identifierKey, value: value);
  }

  static Future<void> forgetIdentifier() =>
      _storage.delete(key: _identifierKey);
}
