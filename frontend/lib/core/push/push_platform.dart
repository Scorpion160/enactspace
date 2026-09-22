import 'dart:async';

enum PushAuthorization { notDetermined, denied, authorized, provisional }

class PushIncomingMessage {
  final String? title;
  final String? body;
  final Map<String, String> data;

  const PushIncomingMessage({this.title, this.body, required this.data});
}

/// Buffers one authenticated push open while the shell establishes whether a
/// session exists. Resolving an invalid session deliberately discards it.
class PushOpenReadinessGate {
  bool _ready = false;
  bool _authenticated = false;
  PushIncomingMessage? _pending;

  PushIncomingMessage? receive(PushIncomingMessage message) {
    if (!_ready) {
      _pending = message;
      return null;
    }
    return _authenticated ? message : null;
  }

  PushIncomingMessage? resolve({required bool authenticated}) {
    _ready = true;
    _authenticated = authenticated;
    final pending = authenticated ? _pending : null;
    _pending = null;
    return pending;
  }

  void discard() {
    _ready = true;
    _authenticated = false;
    _pending = null;
  }
}

abstract interface class PushPlatform {
  bool get supported;
  bool get configured;
  Stream<String> get tokenRefresh;
  Stream<PushIncomingMessage> get foregroundMessages;
  Stream<PushIncomingMessage> get openedMessages;

  Future<bool> initialize();
  Future<PushAuthorization> permissionStatus();
  Future<PushAuthorization> requestPermission();
  Future<String?> currentToken();
  Future<void> deleteToken();
  Future<PushIncomingMessage?> initialMessage();
}
