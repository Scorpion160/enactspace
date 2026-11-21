import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_models.dart';
import '../services/chat_gateway.dart';
import 'chat_attachment_card.dart';
import 'chat_giphy_panel.dart';

class ChatSharedContent extends StatefulWidget {
  final ChatGateway gateway;
  final String threadId;
  const ChatSharedContent({
    super.key,
    required this.gateway,
    required this.threadId,
  });
  @override
  State<ChatSharedContent> createState() => _ChatSharedContentState();
}

class _ChatSharedContentState extends State<ChatSharedContent> {
  final List<ChatMessageModel> _items = [];
  bool _loading = false;
  bool _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.gateway.getSharedMessages(
        widget.threadId,
        offset: _items.length,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(page);
        _more = page.length == 100;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Impossible de charger les éléments partagés. Réessayez.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openLink(String link) async {
    try {
      final uri = Uri.parse(link);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return;
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce lien ne peut pas être ouvert.')),
        );
      }
    }
  }

  Widget _page(int tab) {
    final files = _items
        .where(
          (m) =>
              (m.absoluteAttachmentUrl != null ||
                  m.stickerPack?.startsWith('giphy:') == true) &&
              (tab == 0
                  ? const ['image', 'video', 'sticker'].contains(m.messageType)
                  : !const [
                      'image',
                      'video',
                      'sticker',
                    ].contains(m.messageType)),
        )
        .toList();
    final links = _items
        .expand(
          (m) => RegExp(r'https?://[^\s<>]+')
              .allMatches(m.content)
              .map(
                (match) =>
                    match.group(0)!.replaceAll(RegExp(r'[).,;!?]+$'), ''),
              ),
        )
        .toSet()
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (tab == 2)
          for (final link in links)
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(link),
              onTap: () => _openLink(link),
            )
        else
          for (final message in files)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: message.stickerPack?.startsWith('giphy:') == true
                    ? ChatGiphyMessage(gifId: message.stickerPack!.substring(6))
                    : ChatAttachmentCard(
                        key: ValueKey(message.id),
                        gateway: widget.gateway,
                        message: message,
                        autoDownloadImages: false,
                      ),
              ),
            ),
        if (!_loading &&
            _error == null &&
            (tab == 2 ? links.isEmpty : files.isEmpty))
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Aucun élément à afficher.'),
          ),
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Réessayer')),
        ] else if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_more)
          TextButton(
            onPressed: _load,
            child: const Text('Afficher les éléments plus anciens'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Éléments partagés'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Médias'),
            Tab(text: 'Documents'),
            Tab(text: 'Liens'),
          ],
        ),
      ),
      body: TabBarView(children: [_page(0), _page(1), _page(2)]),
    ),
  );
}
