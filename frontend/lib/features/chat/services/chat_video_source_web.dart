import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:video_player/video_player.dart';

class ChatVideoSource {
  final VideoPlayerController controller;
  final String url;
  ChatVideoSource(this.controller, this.url);

  static Future<ChatVideoSource> create(Uint8List bytes, String mime) async {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    return ChatVideoSource(VideoPlayerController.networkUrl(Uri.parse(url)), url);
  }

  Future<void> dispose() async {
    await controller.dispose();
    web.URL.revokeObjectURL(url);
  }
}

