import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class ChatVideoSource {
  final VideoPlayerController controller;
  final Directory directory;
  ChatVideoSource(this.controller, this.directory);

  static Future<ChatVideoSource> create(Uint8List bytes, String mime) async {
    final root = await getTemporaryDirectory();
    final directory = await Directory('${root.path}/chat-video-').createTemp();
    try {
      final extension = mime == 'video/webm'
          ? 'webm'
          : mime == 'video/quicktime'
          ? 'mov'
          : 'mp4';
      final file = File('${directory.path}/video.$extension');
      await file.writeAsBytes(bytes, flush: true);
      return ChatVideoSource(VideoPlayerController.file(file), directory);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> dispose() async {
    await controller.dispose();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
