import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_client.dart';
import '../auth/auth_service.dart';

class RealtimeService {
  final AuthService _authService;
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _started = false;
  bool _disposed = false;

  RealtimeService({AuthService? authService})
    : _authService = authService ?? AuthService();

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;

    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    final httpUri = Uri.parse(ApiClient.serverUrl);
    final socketUri = httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
      path: '${httpUri.path}/api/realtime/ws',
    );

    try {
      final channel = WebSocketChannel.connect(socketUri);
      await channel.ready;
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      if (_disposed) {
        await channel.sink.close();
        return;
      }

      _channel = channel;
      await _subscription?.cancel();
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage.toString());
      if (decoded is Map<String, dynamic> && !_eventsController.isClosed) {
        _eventsController.add(decoded);
      }
    } catch (_) {
      // Ignore malformed server events and keep the socket alive.
    }
  }

  void _handleDisconnect() {
    _channel = null;
    _subscription = null;
    _scheduleReconnect();
  }

  void send(Map<String, dynamic> event) {
    final channel = _channel;
    if (channel == null || _disposed) return;
    channel.sink.add(jsonEncode(event));
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _eventsController.close();
  }
}
