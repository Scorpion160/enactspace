import 'dart:async';
import 'package:flutter/material.dart';
import '../services/chat_giphy_service.dart';

class ChatGiphyPanel extends StatefulWidget {
  final ValueChanged<GiphyItem> onSelected;
  final VoidCallback onImport;
  const ChatGiphyPanel({
    super.key,
    required this.onSelected,
    required this.onImport,
  });
  @override
  State<ChatGiphyPanel> createState() => _ChatGiphyPanelState();
}

class _ChatGiphyPanelState extends State<ChatGiphyPanel> {
  final _service = ChatGiphyService();
  final List<GiphyItem> _items = [];
  Timer? _timer;
  String _query = '';
  bool _busy = false, _more = true;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _service.dispose();
    super.dispose();
  }

  void _search(String query) {
    _timer?.cancel();
    _query = query;
    _request++;
    setState(() {
      _items.clear();
      _busy = true;
      _error = null;
    });
    _timer = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
      if (reset) {
        _items.clear();
      }
    });
    try {
      final page = await _service.search(query: _query, offset: _items.length);
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _items.addAll(page);
        _more =
            page.length == 24 && _items.length < (_query.isEmpty ? 480 : 4992);
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = 'Les GIF ne sont pas disponibles. Réessayez.');
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                maxLength: 50,
                onChanged: _search,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un GIF…',
                  counterText: '',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Importer un GIF',
              onPressed: widget.onImport,
              icon: const Icon(Icons.folder_open_rounded),
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'Powered by GIPHY',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final gif = _items[index];
            return InkWell(
              onTap: () => widget.onSelected(gif),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  gif.previewUrl,
                  fit: BoxFit.cover,
                  semanticLabel: gif.title,
                  errorBuilder: (_, error, stack) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            );
          },
        ),
      ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.all(8),
          child: LinearProgressIndicator(),
        )
      else if (_error != null)
        TextButton(
          onPressed: () => _load(reset: _items.isEmpty),
          child: Text(_error!),
        )
      else if (_items.isEmpty)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Aucun GIF. Essayez un autre mot.'),
        )
      else if (_more)
        TextButton(onPressed: _load, child: const Text('Voir plus de GIF')),
    ],
  );
}

class ChatGiphyMessage extends StatefulWidget {
  final String gifId;
  const ChatGiphyMessage({super.key, required this.gifId});
  @override
  State<ChatGiphyMessage> createState() => _ChatGiphyMessageState();
}

class _ChatGiphyMessageState extends State<ChatGiphyMessage> {
  final _service = ChatGiphyService();
  late Future<GiphyItem> _future = _service.byId(widget.gifId);
  @override
  void didUpdateWidget(covariant ChatGiphyMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gifId != widget.gifId) {
      _future = _service.byId(widget.gifId);
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FutureBuilder<GiphyItem>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return TextButton(
                onPressed: () =>
                    setState(() => _future = _service.byId(widget.gifId)),
                child: const Text('GIF indisponible. Réessayer'),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Image.network(
              snapshot.data!.displayUrl,
              fit: BoxFit.contain,
              semanticLabel: snapshot.data!.title,
              errorBuilder: (_, error, stack) =>
                  const Text('GIF indisponible.'),
            );
          },
        ),
        const Text('Powered by GIPHY', style: TextStyle(fontSize: 11)),
      ],
    ),
  );
}
