import 'dart:convert';
import 'dart:js_interop';

@JS('enactChatVoiceStart')
external JSPromise<JSString> _enactChatVoiceStart();

@JS('enactChatVoiceStop')
external JSPromise<JSString> _enactChatVoiceStop();

@JS('enactChatVoiceCancel')
external JSPromise<JSString> _enactChatVoiceCancel();

class ChatVoiceRecording {
  final List<int> bytes;
  final String fileName;
  final String mimeType;
  final int durationSeconds;

  const ChatVoiceRecording({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.durationSeconds,
  });
}

class ChatVoiceRecorder {
  Future<bool> start() async {
    final result = (await _enactChatVoiceStart().toDart).toDart;
    return result == 'true';
  }

  Future<ChatVoiceRecording> stop({required int fallbackDuration}) async {
    final raw = (await _enactChatVoiceStop().toDart).toDart;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('Réponse audio navigateur invalide.');
    final data = Map<String, dynamic>.from(decoded);
    final encoded = data['base64']?.toString() ?? '';
    if (encoded.isEmpty) throw Exception('Le vocal enregistré est vide.');
    final bytes = base64Decode(encoded);
    if (bytes.isEmpty) throw Exception('Le vocal enregistré est vide.');
    return ChatVoiceRecording(
      bytes: bytes,
      fileName: data['name']?.toString() ?? 'vocal_enactspace.webm',
      mimeType: data['mimeType']?.toString() ?? 'audio/webm',
      durationSeconds:
          int.tryParse(data['durationSeconds']?.toString() ?? '') ??
          fallbackDuration.clamp(1, 3600),
    );
  }

  Future<void> cancel() async {
    await _enactChatVoiceCancel().toDart;
  }
}
