import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/document_center_models.dart';
import '../models/document_model.dart';
import '../services/documents_gateway.dart';

Future<DocumentFormResult?> showDocumentFormDialog(
  BuildContext context, {
  required DocumentsGateway gateway,
  required DocumentReferenceData references,
  DocumentModel? document,
}) => showDialog<DocumentFormResult>(
  context: context,
  barrierDismissible: false,
  builder: (_) => DocumentFormDialog(
    gateway: gateway,
    references: references,
    document: document,
  ),
);

class DocumentFormDialog extends StatefulWidget {
  final DocumentsGateway gateway;
  final DocumentReferenceData references;
  final DocumentModel? document;
  const DocumentFormDialog({
    super.key,
    required this.gateway,
    required this.references,
    this.document,
  });
  @override
  State<DocumentFormDialog> createState() => _DocumentFormDialogState();
}

class _DocumentFormDialogState extends State<DocumentFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.document?.title ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.document?.description ?? '',
  );
  late final TextEditingController _link = TextEditingController(
    text: widget.document?.fileUrl ?? '',
  );
  late String _category = widget.document?.category ?? 'general';
  late String _visibility = widget.document?.visibility ?? 'internal';
  String? _poleId;
  String? _projectId;
  String? _eventId;
  String? _seasonId;
  late bool _template = widget.document?.isTemplate ?? false;
  Uint8List? _bytes;
  String? _fileName;
  String? _fileType;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poleId = widget.document?.poleId;
    _projectId = widget.document?.projectId;
    _eventId = widget.document?.eventId;
    _seasonId = widget.document?.seasonId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) {
      setState(() => _error = 'Le fichier n’a pas pu être lu.');
      return;
    }
    setState(() {
      _bytes = file.bytes;
      _fileName = file.name;
      _fileType = file.extension;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting || !_form.currentState!.validate()) return;
    final existing = widget.document;
    final hasLink = _link.text.trim().isNotEmpty;
    if (_bytes == null &&
        !hasLink &&
        existing?.fileId == null &&
        existing?.fileUrl == null) {
      setState(() => _error = 'Ajoutez un fichier ou un lien.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      String? fileId;
      String? fileUrl = hasLink ? _link.text.trim() : existing?.fileUrl;
      String? fileType = _fileType ?? existing?.fileType;
      var replaceFile =
          hasLink && _link.text.trim() != (existing?.fileUrl ?? '');
      if (_bytes != null) {
        final uploaded = await widget.gateway.uploadFile(
          fileName: _fileName!,
          bytes: _bytes!,
          visibility: _visibility,
        );
        fileId = uploaded.fileId;
        fileUrl = null;
        fileType = uploaded.fileType;
        replaceFile = true;
      } else if (!replaceFile) {
        fileId = existing?.fileId;
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        DocumentFormResult(
          replaceFile: replaceFile,
          draft: DocumentMutationDraft(
            title: _title.text.trim(),
            description: _description.text.trim(),
            fileUrl: fileUrl,
            fileId: fileId,
            fileType: fileType,
            category: _category,
            visibility: _visibility,
            poleId: _poleId,
            projectId: _projectId,
            eventId: _eventId,
            seasonId: _seasonId,
            isTemplate: _template,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.document != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        child: Form(
          key: _form,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        editing ? 'Modifier le document' : 'Nouveau document',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Annuler',
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextFormField(
                        key: const Key('document-title'),
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Titre *'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Titre obligatoire'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (editing &&
                                  _bytes == null &&
                                  _link.text.trim() ==
                                      (widget.document?.fileUrl ?? ''))
                                const Text(
                                  'Le fichier actuel sera conservé tant qu’il n’est pas remplacé.',
                                ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                key: const Key('pick-document-file'),
                                onPressed: _submitting ? null : _pickFile,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: Text(_fileName ?? 'Choisir un fichier'),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('ou'),
                              ),
                              TextFormField(
                                key: const Key('document-link'),
                                controller: _link,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Lien du fichier',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie',
                        ),
                        items: DocumentModel.categoryOptions
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.value,
                                child: Text(option.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _category = value!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: const Key('document-visibility'),
                        initialValue: _visibility,
                        decoration: const InputDecoration(
                          labelText: 'Visibilité',
                        ),
                        items:
                            const {
                                  'public_club': 'Tout le club',
                                  'internal': 'Membres',
                                  'pole_only': 'Pôle sélectionné',
                                  'project_only': 'Projet sélectionné',
                                  'enacchef_only': 'Responsables',
                                  'private': 'Privé',
                                }.entries
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) =>
                            setState(() => _visibility = value!),
                      ),
                      const SizedBox(height: 12),
                      _RefSelect(
                        label: 'Pôle',
                        value: _poleId,
                        none: 'Aucun pôle',
                        items: widget.references.poles.map(
                          (item) => MapEntry(item.id, item.name),
                        ),
                        onChanged: (value) => setState(() => _poleId = value),
                      ),
                      const SizedBox(height: 12),
                      _RefSelect(
                        label: 'Projet',
                        value: _projectId,
                        none: 'Aucun projet',
                        items: widget.references.projects.map(
                          (item) => MapEntry(item.id, item.name),
                        ),
                        onChanged: (value) =>
                            setState(() => _projectId = value),
                      ),
                      const SizedBox(height: 12),
                      _RefSelect(
                        label: 'Événement',
                        value: _eventId,
                        none: 'Aucun événement',
                        items: widget.references.events.map(
                          (item) => MapEntry(item.id, item.title),
                        ),
                        onChanged: (value) => setState(() => _eventId = value),
                      ),
                      if (widget.references.seasons.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _RefSelect(
                          label: 'Saison',
                          value: _seasonId,
                          none: 'Aucune saison',
                          items: widget.references.seasons.map(
                            (item) => MapEntry(item.id, item.name),
                          ),
                          onChanged: (value) =>
                              setState(() => _seasonId = value),
                        ),
                      ],
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Utiliser comme modèle'),
                        value: _template,
                        onChanged: (value) => setState(() => _template = value),
                      ),
                      if (_error != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const Key('document-submit'),
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        editing ? 'Enregistrer' : 'Créer le document',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefSelect extends StatelessWidget {
  final String label;
  final String none;
  final String? value;
  final Iterable<MapEntry<String, String>> items;
  final ValueChanged<String?> onChanged;
  const _RefSelect({
    required this.label,
    required this.none,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String?>(
    isExpanded: true,
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      DropdownMenuItem(value: null, child: Text(none)),
      ...items.map(
        (item) => DropdownMenuItem(value: item.key, child: Text(item.value)),
      ),
    ],
    onChanged: onChanged,
  );
}
