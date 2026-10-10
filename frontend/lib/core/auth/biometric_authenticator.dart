import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthenticator {
  final LocalAuthentication _localAuth;
  BiometricAuthenticator({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> isAvailable() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return false;
    }
    try {
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics &&
          (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() => _localAuth.authenticate(
    localizedReason: 'Déverrouiller votre session EnactSpace',
    biometricOnly: true,
    persistAcrossBackgrounding: true,
  );
}
