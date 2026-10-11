import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';
import '../models/chat_models.dart';
import '../services/chat_gateway.dart';
import '../services/chat_video_source.dart';

class ChatAttachmentCard extends StatefulWidget {
  final ChatGateway gateway;
  final ChatMessageModel message;
  const ChatAttachmentCard({super.key, required this.gateway, required this.message});

  @override
  State<ChatAttachmentCard> createState() => _ChatAttachmentCardState();
}

class _ChatAttachmentCardState extends State<ChatAttachmentCard> {
  Uint8List? _bytes;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _image => widget.message.messageType == 'image' ||
      widget.message.messageType == 'sticker';
  bool get _video => widget.message.messageType == 'video';
  bool get _pdf => widget.message.attachmentMimeType == 'application/pdf' ||
      widget.message.attachmentLabel.toLowerCase().endsWith('.pdf');

  Future<void> _load() async {
    if (_loading) { return; }
    setState(() { _loading = true; _error = null; });
    try {
      final url = widget.message.absoluteAttachmentUrl;
      if (url == null || url.isEmpty) { throw Exception('Média indisponible.'); }
      final bytes = await widget.gateway.loadMediaBytes(url);
      if (bytes.isEmpty) { throw Exception('Le fichier reçu est vide.'); }
      if (!mounted) { return; }
      setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Téléchargement impossible. Réessayez.');
      }
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null || _saving) { return; }
    setState(() => _saving = true);
    try {
      final name = widget.message.attachmentLabel.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la pièce jointe',
        fileName: name,
        bytes: bytes,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enregistrement impossible. Réessayez.')),
        );
      }
    } finally {
      if (mounted) { setState(() => _saving = false); }
    }
  }

  Future<void> _open() async {
    final bytes = _bytes;
    if (bytes == null) { await _load(); return; }
    if (!_image && !_video && !_pdf) { await _save(); return; }
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.message.attachmentLabel),
          actions: [
            IconButton(
              tooltip: 'Enregistrer',
              onPressed: _save,
              icon: const Icon(Icons.download_rounded),
            ),
          ],
        ),
        body: _image
            ? Center(child: InteractiveViewer(
                minScale: 0.5, maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain,
                  errorBuilder: (_, error, stack) => const Text('Image non prise en charge.')),
              ))
            : _pdf
                ? PdfViewer.data(bytes, sourceName: 'chat-${widget.message.id}')
                : _ChatVideoViewer(bytes: bytes,
                    mime: widget.message.attachmentMimeType ?? 'video/mp4'),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final loaded = _bytes != null;
    final size = message.attachmentSizeBytes;
    final details = size == null ? '' : size >= 1048576
        ? '${(size / 1048576).toStringAsFixed(1)} Mo'
        : '${(size / 1024).ceil()} Ko';

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_image && loaded)
          InkWell(
            onTap: _open,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_bytes!, width: 280, height: 190, fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => const SizedBox(
                  height: 120, child: Center(child: Text('Image non prise en charge.')))),
            ),
          )
        else if (_image || _video)
          InkWell(
            onTap: _loading ? null : loaded ? _open : _load,
            child: Container(
              height: 150, width: 280,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _loading
                  ? const CircularProgressIndicator()
                  : Icon(_video ? Icons.play_circle_rounded : Icons.image_outlined, size: 52),
            ),
          ),
        const SizedBox(height: 8),
        Row(children: [
          if (!_image && !_video) ...[
            const Icon(Icons.description_outlined), const SizedBox(width: 8),
          ],
          Expanded(child: Text(message.attachmentLabel,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700))),
          if (loaded)
            IconButton(
              tooltip: 'Enregistrer',
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.download_rounded),
            ),
        ]),
        if (details.isNotEmpty) Text(details),
        if (_error != null)
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        TextButton.icon(
          onPressed: _loading ? null : loaded ? _open : _load,
          icon: Icon(loaded ? Icons.open_in_new_rounded : Icons.download_rounded),
          label: Text(_loading ? 'Téléchargement…' : loaded
              ? (_video ? 'Lire la vidéo' : _image || _pdf ? 'Ouvrir' : 'Enregistrer le document')
              : _error != null ? 'Réessayer' : 'Télécharger'),
        ),
        if (message.content.trim().isNotEmpty &&
            message.content != message.attachmentLabel)
          Text(message.content, style: const TextStyle(height: 1.35)),
        if (message.isEphemeralMedia)
          const Text('Média éphémère', style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}

class _ChatVideoViewer extends StatefulWidget {
  final Uint8List bytes;
  final String mime;
  const _ChatVideoViewer({required this.bytes, required this.mime});
  @override
  State<_ChatVideoViewer> createState() => _ChatVideoViewerState();
}

class _ChatVideoViewerState extends State<_ChatVideoViewer> {
  ChatVideoSource? _source;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    ChatVideoSource? source;
    try {
      source = await ChatVideoSource.create(widget.bytes, widget.mime);
      await source.controller.initialize();
      if (!mounted) { await source.dispose(); return; }
      setState(() => _source = source);
    } catch (_) {
      if (source != null) { await source.dispose(); }
      if (mounted) {
        setState(() => _error = 'Format vidéo non pris en charge. Vous pouvez enregistrer le fichier.');
      }
    }
  }

  @override
  void dispose() {
    final source = _source;
    if (source != null) { unawaited(source.dispose()); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) { return Center(child: Padding(
      padding: const EdgeInsets.all(24), child: Text(_error!))); }
    final controller = _source?.controller;
    if (controller == null) { return const Center(child: CircularProgressIndicator()); }
    return Center(child: SingleChildScrollView(child: Column(children: [
      AspectRatio(aspectRatio: controller.value.aspectRatio > 0
          ? controller.value.aspectRatio : 16 / 9,
        child: VideoPlayer(controller)),
      VideoProgressIndicator(controller, allowScrubbing: true),
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, child) => IconButton(
          tooltip: value.isPlaying ? 'Pause' : 'Lire',
          icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          onPressed: () async {
            if (value.isPlaying) { await controller.pause(); }
            else { await controller.play(); }
          },
        ),
      ),
    ])));
  }
}

