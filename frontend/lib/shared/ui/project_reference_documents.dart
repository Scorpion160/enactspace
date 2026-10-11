import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/project_presentation.dart';

class ProjectReferenceDocuments extends StatelessWidget {
  final List<ProjectReferenceDocument> documents;
  const ProjectReferenceDocuments({super.key, required this.documents});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final document in documents)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(document.description, style: const TextStyle(height: 1.6)),
                const SizedBox(height: 8),
                Text('PDF · ${document.pages} pages'),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: ValueKey('reference-${document.asset}'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        ProjectReferencePdfViewer(document: document),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Lire le dossier'),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class ProjectReferencePdfViewer extends StatefulWidget {
  final ProjectReferenceDocument document;
  const ProjectReferencePdfViewer({super.key, required this.document});
  @override
  State<ProjectReferencePdfViewer> createState() =>
      _ProjectReferencePdfViewerState();
}

class _ProjectReferencePdfViewerState extends State<ProjectReferencePdfViewer> {
  late Future<Uint8List> _bytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  Future<Uint8List> _load() async {
    if (!ProjectReferenceDocument.isAllowedAsset(widget.document.asset)) {
      throw const FormatException('Dossier indisponible');
    }
    final data = await rootBundle.load(widget.document.asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _bytes;
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le dossier du projet',
        fileName: widget.document.filename,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      if (mounted && path != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dossier enregistré.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'L’enregistrement a échoué. Réessaie dans un instant.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(
          context,
        ).scale(56).clamp(56, 112),
        title: Text(
          widget.document.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: 'Fermer le dossier',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Le dossier n’a pas pu être ouvert.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _bytes = _load()),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: const Text('Télécharger le PDF'),
                ),
              ),
              Expanded(
                child: PdfViewer.data(
                  snapshot.data!,
                  sourceName: widget.document.filename,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
