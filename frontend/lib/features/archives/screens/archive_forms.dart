import 'package:flutter/material.dart';

import '../models/archive_models.dart';
import '../services/archives_gateway.dart';

Future<bool> showArchiveItemDialog(
  BuildContext context,
  ArchivesGateway gateway, {
  ArchiveItemModel? item,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ArchiveItemFormDialog(gateway: gateway, item: item),
    ) ??
    false;

class ArchiveItemFormDialog extends StatefulWidget {
  final ArchivesGateway gateway;
  final ArchiveItemModel? item;
  const ArchiveItemFormDialog({super.key, required this.gateway, this.item});

  @override
  State<ArchiveItemFormDialog> createState() => _ArchiveItemFormDialogState();
}

class _ArchiveItemFormDialogState extends State<ArchiveItemFormDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late String _category;
  late String _visibility;
  late bool _featured;
  late bool _public;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _fields = {
      'title': TextEditingController(text: item?.title),
      'description': TextEditingController(text: item?.description),
      'year': TextEditingController(text: item?.year?.toString()),
      'season_id': TextEditingController(text: item?.seasonId),
      'pole_id': TextEditingController(text: item?.poleId),
      'project_id': TextEditingController(text: item?.projectId),
      'document_id': TextEditingController(text: item?.documentId),
      'file_id': TextEditingController(text: item?.fileId),
      'source_label': TextEditingController(text: item?.sourceLabel),
      'source_url': TextEditingController(text: item?.sourceUrl),
      'tags': TextEditingController(text: item?.tags.join(', ')),
    };
    _category = item?.category ?? archiveCategories.first;
    _visibility = item?.visibility ?? 'interne';
    _featured = item?.isFeatured ?? false;
    _public = item?.isPublic ?? false;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.item == null ? 'Nouvelle archive' : 'Modifier l’archive',
    ),
    content: SizedBox(
      width: 680,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('title', 'Titre', required: true),
              _field('description', 'Description', lines: 4),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: archiveCategories
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => _category = value!,
              ),
              _field('year', 'Année', numeric: true),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'Visibilité'),
                items: archiveVisibilities
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(archiveVisibilityLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _visibility = value!),
              ),
              _field('season_id', 'Saison (identifiant fiable)'),
              _field('pole_id', 'Pôle'),
              _field('project_id', 'Projet'),
              _field('document_id', 'Document'),
              _field('file_id', 'Fichier existant'),
              _field('source_label', 'Libellé de la source'),
              _field('source_url', 'URL de la source'),
              _field('tags', 'Tags (séparés par des virgules)'),
              CheckboxListTile(
                value: _featured,
                onChanged: (value) =>
                    setState(() => _featured = value ?? false),
                title: const Text('Mettre en avant'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _public,
                onChanged: (value) => setState(() {
                  _public = value ?? false;
                  if (_public && !{'public', 'alumni'}.contains(_visibility)) {
                    _visibility = 'public';
                  }
                }),
                title: const Text('Contenu public'),
                subtitle: const Text(
                  'Un contenu public doit être visible par le public ou les alumni.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context, false),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const Key('save_archive_button'),
        onPressed: _submitting ? null : _save,
        child: _submitting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Enregistrer'),
      ),
    ],
  );

  Widget _field(
    String key,
    String label, {
    bool required = false,
    int lines = 1,
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[key],
      decoration: InputDecoration(labelText: label),
      maxLines: lines,
      keyboardType: numeric ? TextInputType.number : null,
      validator: required
          ? (value) =>
                value == null || value.trim().isEmpty ? 'Champ requis' : null
          : null,
    ),
  );

  Future<void> _save() async {
    if (_submitting || !_form.currentState!.validate()) return;
    if (_public && !{'public', 'alumni'}.contains(_visibility)) {
      setState(
        () => _error = 'Choisissez Public ou Alumni pour un contenu public.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final payload = archivePayload({
      'title': _fields['title']!.text.trim(),
      'description': archiveNullableString(_fields['description']!.text),
      'category': _category,
      'year': int.tryParse(_fields['year']!.text),
      'visibility': _visibility,
      'season_id': archiveNullableString(_fields['season_id']!.text),
      'pole_id': archiveNullableString(_fields['pole_id']!.text),
      'project_id': archiveNullableString(_fields['project_id']!.text),
      'document_id': archiveNullableString(_fields['document_id']!.text),
      'file_id': archiveNullableString(_fields['file_id']!.text),
      'source_label': archiveNullableString(_fields['source_label']!.text),
      'source_url': archiveNullableString(_fields['source_url']!.text),
      'tags': _fields['tags']!.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      'is_featured': _featured,
      'is_public': _public,
    });
    try {
      if (widget.item == null) {
        await widget.gateway.createItem(payload);
      } else {
        await widget.gateway.updateItem(widget.item!.id, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }
}

Future<bool> showHallOfFameDialog(
  BuildContext context,
  ArchivesGateway gateway, {
  HallOfFameEntryModel? item,
}) => _showContractDialog(
  context,
  title: item == null ? 'Nouvelle entrée Hall of Fame' : 'Modifier l’entrée',
  initial: {
    'title': item?.title,
    'subtitle': item?.subtitle,
    'entry_type': item?.entryType,
    'year': item?.year,
    'description': item?.description,
    'score_value': item?.scoreValue,
    'score_label': item?.scoreLabel,
    'file_id': item?.fileId,
    'external_url': item?.externalUrl,
    'order_index': item?.orderIndex,
    'is_featured': item?.isFeatured ?? false,
  },
  fields: const {
    'title': 'Titre',
    'subtitle': 'Sous-titre',
    'entry_type': 'Type',
    'year': 'Année',
    'description': 'Description',
    'score_value': 'Score',
    'score_label': 'Libellé du score',
    'file_id': 'Fichier',
    'external_url': 'Lien externe',
    'order_index': 'Ordre',
  },
  requiredFields: const {'title', 'entry_type'},
  numericFields: const {'year', 'score_value', 'order_index'},
  boolFields: const {'is_featured': 'Mettre en avant'},
  save: (payload) => item == null
      ? gateway.createHallOfFameEntry(payload)
      : gateway.updateHallOfFameEntry(item.id, payload),
);

Future<bool> showHistoricalProjectDialog(
  BuildContext context,
  ArchivesGateway gateway, {
  HistoricalProjectModel? item,
}) => _showContractDialog(
  context,
  title: item == null
      ? 'Nouveau projet historique'
      : 'Modifier le projet historique',
  initial: {
    'archive_item_id': item?.archiveItemId,
    'name': item?.name,
    'year': item?.year,
    'season_label': item?.seasonLabel,
    'description': item?.description,
    'problem': item?.problem,
    'solution': item?.solution,
    'impact_summary': item?.impactSummary,
    'status': item?.status,
    'linked_project_id': item?.linkedProjectId,
    'key_members': item?.keyMembers.join(', '),
    'awards': item?.awards.join(', '),
    'document_ids': item?.documentIds.join(', '),
    'media_file_ids': item?.mediaFileIds.join(', '),
  },
  fields: const {
    'name': 'Nom',
    'year': 'Année',
    'season_label': 'Saison / période',
    'description': 'Description',
    'problem': 'Problème',
    'solution': 'Solution',
    'impact_summary': 'Résumé d’impact',
    'status': 'Statut',
    'linked_project_id': 'Projet moderne lié',
    'key_members': 'Membres clés',
    'awards': 'Récompenses',
    'document_ids': 'Documents associés',
    'media_file_ids': 'Médias associés',
  },
  requiredFields: const {'name'},
  numericFields: const {'year'},
  listFields: const {'key_members', 'awards', 'document_ids', 'media_file_ids'},
  save: (payload) => item == null
      ? gateway.createHistoricalProject(payload)
      : gateway.updateHistoricalProject(item.id, payload),
);

Future<bool> showAwardDialog(
  BuildContext context,
  ArchivesGateway gateway, {
  ArchiveAwardModel? item,
}) => _showContractDialog(
  context,
  title: item == null ? 'Nouvelle distinction' : 'Modifier la distinction',
  initial: {
    'title': item?.title,
    'year': item?.year,
    'competition': item?.competition,
    'rank': item?.rank,
    'result': item?.result,
    'description': item?.description,
    'archived_project_id': item?.archivedProjectId,
    'file_id': item?.fileId,
    'media_url': item?.mediaUrl,
    'is_featured': item?.isFeatured ?? false,
  },
  fields: const {
    'title': 'Titre',
    'year': 'Année',
    'competition': 'Compétition',
    'rank': 'Rang',
    'result': 'Résultat',
    'description': 'Description',
    'archived_project_id': 'Projet historique',
    'file_id': 'Fichier',
    'media_url': 'Lien média',
  },
  requiredFields: const {'title'},
  numericFields: const {'year'},
  boolFields: const {'is_featured': 'Mettre en avant'},
  save: (payload) => item == null
      ? gateway.createAward(payload)
      : gateway.updateAward(item.id, payload),
);

Future<bool> showCompetitionDialog(
  BuildContext context,
  ArchivesGateway gateway, {
  ArchiveCompetitionModel? item,
}) => _showContractDialog(
  context,
  title: item == null ? 'Nouvelle compétition' : 'Modifier la compétition',
  initial: {
    'name': item?.name,
    'year': item?.year,
    'stage': item?.stage,
    'result': item?.result,
    'location': item?.location,
    'description': item?.description,
    'project_ids': item?.projectIds.join(', '),
    'award_ids': item?.awardIds.join(', '),
    'file_id': item?.fileId,
    'is_featured': item?.isFeatured ?? false,
  },
  fields: const {
    'name': 'Nom',
    'year': 'Année',
    'stage': 'Étape',
    'result': 'Résultat',
    'location': 'Lieu',
    'description': 'Description',
    'project_ids': 'Projets',
    'award_ids': 'Distinctions',
    'file_id': 'Fichier',
  },
  requiredFields: const {'name'},
  numericFields: const {'year'},
  listFields: const {'project_ids', 'award_ids'},
  boolFields: const {'is_featured': 'Mettre en avant'},
  save: (payload) => item == null
      ? gateway.createCompetition(payload)
      : gateway.updateCompetition(item.id, payload),
);

Future<bool> showMediaDialog(
  BuildContext context,
  ArchivesGateway gateway, {
  ArchiveMediaModel? item,
}) => _showContractDialog(
  context,
  title: item == null ? 'Nouveau média historique' : 'Modifier le média',
  initial: {
    'title': item?.title,
    'media_type': item?.mediaType,
    'year': item?.year,
    'description': item?.description,
    'project_id': item?.projectId,
    'file_id': item?.fileId,
    'external_url': item?.externalUrl,
    'is_featured': item?.isFeatured ?? false,
  },
  fields: const {
    'title': 'Titre',
    'media_type': 'Type de média',
    'year': 'Année',
    'description': 'Description',
    'project_id': 'Projet historique',
    'file_id': 'Fichier existant',
    'external_url': 'Lien externe',
  },
  requiredFields: const {'title', 'media_type'},
  numericFields: const {'year'},
  boolFields: const {'is_featured': 'Mettre en avant'},
  save: (payload) => item == null
      ? gateway.createMedia(payload)
      : gateway.updateMedia(item.id, payload),
);

Future<bool> showArchiveDocumentDialog(
  BuildContext context,
  ArchivesGateway gateway, {
  ArchiveDocumentModel? item,
}) => _showContractDialog(
  context,
  title: item == null
      ? 'Nouveau document historique'
      : 'Modifier le document historique',
  initial: {
    'title': item?.title,
    'document_type': item?.documentType,
    'year': item?.year,
    'description': item?.description,
    'document_id': item?.documentId,
    'file_id': item?.fileId,
    'source_label': item?.sourceLabel,
    'visibility': item?.visibility,
    'is_featured': item?.isFeatured ?? false,
  },
  fields: const {
    'title': 'Titre',
    'document_type': 'Type de document',
    'year': 'Année',
    'description': 'Description',
    'document_id': 'Document lié',
    'file_id': 'Fichier existant',
    'source_label': 'Source',
    'visibility': 'Visibilité',
  },
  requiredFields: const {'title', 'document_type'},
  numericFields: const {'year'},
  boolFields: const {'is_featured': 'Mettre en avant'},
  save: (payload) => item == null
      ? gateway.createDocument(payload)
      : gateway.updateDocument(item.id, payload),
);

Future<bool> showHistoricalStatisticDialog(
  BuildContext context,
  ArchivesGateway gateway,
  HistoricalStatisticModel item,
) => _showContractDialog(
  context,
  title: item.isPersisted
      ? 'Modifier la statistique historique'
      : 'Vérifier la valeur historique',
  initial: {
    'label': item.label,
    'value': item.value,
    'unit': item.unit,
    'description': item.description,
    'source_label': item.sourceLabel,
    'status': item.status,
  },
  fields: const {
    'label': 'Libellé',
    'value': 'Valeur',
    'unit': 'Unité',
    'description': 'Description',
    'source_label': 'Source',
    'status': 'Statut',
  },
  requiredFields: const {'label', 'value'},
  numericFields: const {'value'},
  save: (payload) => gateway.saveHistoricalStatistic(item, payload),
);

Future<bool> _showContractDialog(
  BuildContext context, {
  required String title,
  required Map<String, Object?> initial,
  required Map<String, String> fields,
  required Future<Object> Function(Map<String, dynamic>) save,
  Set<String> requiredFields = const {},
  Set<String> numericFields = const {},
  Set<String> listFields = const {},
  Map<String, String> boolFields = const {},
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ContractFormDialog(
        title: title,
        initial: initial,
        fields: fields,
        requiredFields: requiredFields,
        numericFields: numericFields,
        listFields: listFields,
        boolFields: boolFields,
        save: save,
      ),
    ) ??
    false;

class _ContractFormDialog extends StatefulWidget {
  final String title;
  final Map<String, Object?> initial;
  final Map<String, String> fields;
  final Set<String> requiredFields;
  final Set<String> numericFields;
  final Set<String> listFields;
  final Map<String, String> boolFields;
  final Future<Object> Function(Map<String, dynamic>) save;
  const _ContractFormDialog({
    required this.title,
    required this.initial,
    required this.fields,
    required this.requiredFields,
    required this.numericFields,
    required this.listFields,
    required this.boolFields,
    required this.save,
  });

  @override
  State<_ContractFormDialog> createState() => _ContractFormDialogState();
}

class _ContractFormDialogState extends State<_ContractFormDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _booleans;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final key in widget.fields.keys)
        key: TextEditingController(text: widget.initial[key]?.toString()),
    };
    _booleans = {
      for (final key in widget.boolFields.keys)
        key: widget.initial[key] == true,
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 640,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in widget.fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _controllers[entry.key],
                    decoration: InputDecoration(labelText: entry.value),
                    maxLines:
                        {
                          'description',
                          'problem',
                          'solution',
                          'impact_summary',
                        }.contains(entry.key)
                        ? 4
                        : 1,
                    keyboardType: widget.numericFields.contains(entry.key)
                        ? TextInputType.number
                        : null,
                    validator: widget.requiredFields.contains(entry.key)
                        ? (value) => value == null || value.trim().isEmpty
                              ? 'Champ requis'
                              : null
                        : null,
                  ),
                ),
              for (final entry in widget.boolFields.entries)
                CheckboxListTile(
                  value: _booleans[entry.key] ?? false,
                  onChanged: (value) =>
                      setState(() => _booleans[entry.key] = value ?? false),
                  title: Text(entry.value),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context, false),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Enregistrer'),
      ),
    ],
  );

  Future<void> _submit() async {
    if (_submitting || !_form.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final payload = <String, dynamic>{};
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) continue;
      if (widget.numericFields.contains(entry.key)) {
        payload[entry.key] = num.tryParse(value);
      } else if (widget.listFields.contains(entry.key)) {
        payload[entry.key] = value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } else {
        payload[entry.key] = value;
      }
    }
    payload.addAll(_booleans);
    try {
      await widget.save(archivePayload(payload));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }
}
