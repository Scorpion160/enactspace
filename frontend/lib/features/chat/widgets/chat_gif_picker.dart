import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatGif {
  final String id;
  final String label;
  final String category;
  final String data;
  const ChatGif({required this.id, required this.label, required this.category, required this.data});
  Uint8List get bytes => base64Decode(data);
}

Future<List<ChatGif>>? _catalog;
Future<List<ChatGif>> loadChatGifs() => _catalog ??= _readCatalog();

Future<List<ChatGif>> _readCatalog() async {
  try {
    final content = await rootBundle.loadString('assets/chat/gifs/catalog.json');
    return (jsonDecode(content) as List).map((item) => ChatGif(
      id: item['id'] as String, label: item['label'] as String,
      category: item['category'] as String, data: item['data'] as String,
    )).toList();
  } catch (_) {
    _catalog = null;
    rethrow;
  }
}

class ChatGifPicker extends StatefulWidget {
  final ValueChanged<ChatGif> onSelected;
  final VoidCallback onImport;
  const ChatGifPicker({super.key, required this.onSelected, required this.onImport});
  @override
  State<ChatGifPicker> createState() => _ChatGifPickerState();
}

class _ChatGifPickerState extends State<ChatGifPicker> {
  late Future<List<ChatGif>> _future = loadChatGifs();
  String _query = '';
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        Expanded(child: TextField(
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Rechercher : bravo, merci, équipe…',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        )),
        IconButton(tooltip: 'Importer un GIF', onPressed: widget.onImport,
          icon: const Icon(Icons.folder_open_rounded)),
      ]),
    ),
    Expanded(child: FutureBuilder<List<ChatGif>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: TextButton(
            onPressed: () => setState(() => _future = loadChatGifs()),
            child: const Text('Catalogue indisponible. Réessayer'),
          ));
        }
        if (!snapshot.hasData) { return const Center(child: CircularProgressIndicator()); }
        final items = snapshot.data!.where((gif) =>
          '${gif.label} ${gif.category}'.toLowerCase().contains(_query)).toList();
        if (items.isEmpty) { return const Center(child: Text('Aucun GIF. Essayez un autre mot.')); }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190, childAspectRatio: 1.25,
            mainAxisSpacing: 10, crossAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final gif = items[index];
            return InkWell(
              key: ValueKey(gif.id), onTap: () => widget.onSelected(gif),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(
                gif.bytes, fit: BoxFit.cover, semanticLabel: gif.label,
                errorBuilder: (_, error, stack) => Center(child: Text(gif.label)),
              )),
            );
          },
        );
      },
    )),
  ]);
}
