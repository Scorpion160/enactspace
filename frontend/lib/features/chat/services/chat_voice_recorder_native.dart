import 'package:flutter/services.dart';

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
  static const MethodChannel _channel = MethodChannel(
    'sn.enactusesp.enactspace/chat_voice',
  );

  Future<bool> start() async =>
      await _channel.invokeMethod<bool>('startVoiceRecording') ?? false;

  Future<ChatVoiceRecording> stop({required int fallbackDuration}) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'stopVoiceRecording',
    );
    if (result == null) throw Exception('Vocal introuvable.');
    final rawBytes = result['bytes'];
    if (rawBytes is! List || rawBytes.isEmpty) {
      throw Exception('Le vocal enregistré est vide.');
    }
    final bytes = rawBytes.map((value) => (value as num).toInt()).toList();
    return ChatVoiceRecording(
      bytes: bytes,
      fileName: result['name']?.toString() ?? 'vocal_enactspace.m4a',
      mimeType: result['mime_type']?.toString() ?? 'audio/mp4',
      durationSeconds:
          int.tryParse(result['duration_seconds']?.toString() ?? '') ??
          fallbackDuration.clamp(1, 3600),
    );
  }

  Future<void> cancel() => _channel.invokeMethod<void>('cancelVoiceRecording');
}
