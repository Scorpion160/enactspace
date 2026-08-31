import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/document_center_models.dart';
import '../models/document_model.dart';
import '../services/documents_gateway.dart';
import '../widgets/document_form_dialog.dart';
import '../widgets/document_widgets.dart';

class DocumentsScreen extends StatefulWidget {
  final DocumentsGateway? gateway;
  const DocumentsScreen({super.key, this.gateway});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late final DocumentsGateway _gateway =
      widget.gateway ?? ApiDocumentsGateway();
  final _search = TextEditingController();
  List<DocumentModel> _documents = const [];
  DocumentReferenceData _references = const DocumentReferenceData();
  String _category = 'all', _status = 'all', _visibility = 'all';
  String _pole = 'all', _project = 'all', _event = 'all';
  bool _templates = false, _officials = false, _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _gateway.loadDocuments(),
        _gateway.loadReferences(),
      ]);
      if (!mounted) return;
      setState(() {
        _documents = values[0] as List<DocumentModel>;
        _references = values[1] as DocumentReferenceData;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _msg(error);
        });
      }
    }
  }

  Future<void> _applyFilters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await _gateway.loadDocuments(
        DocumentFilters(
          search: _search.text,
          category: _category,
          status: _status,
          visibility: _visibility,
          poleId: _pole,
          projectId: _project,
          eventId: _event,
          isTemplate: _templates ? true : null,
          isOfficial: _officials ? true : null,
        ),
      );
      if (mounted) {
        setState(() {
          _documents = values;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _msg(error);
        });
      }
    }
  }

  Future<void> _create() async {
    final result = await showDocumentFormDialog(
      context,
      gateway: _gateway,
      references: _references,
    );
    if (result == null || !mounted) return;
    try {
      final created = await _gateway.createDocument(result.draft);
      if (!mounted) return;
      setState(() => _documents = [created, ..._documents]);
      _notice('Document créé.');
    } catch (error) {
      if (mounted) _notice(_msg(error), true);
    }
  }

  void _open(DocumentModel document) =>
      context.push('/documents/${document.id}', extra: _gateway);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final filters = _Filters(
      category: _category,
      status: _status,
      visibility: _visibility,
      pole: _pole,
      project: _project,
      event: _event,
      templates: _templates,
      officials: _officials,
      references: _references,
      onCategory: (v) {
        setState(() => _category = v);
        _applyFilters();
      },
      onStatus: (v) {
        setState(() => _status = v);
        _applyFilters();
      },
      onVisibility: (v) {
        setState(() => _visibility = v);
        _applyFilters();
      },
      onPole: (v) {
        setState(() => _pole = v);
        _applyFilters();
      },
      onProject: (v) {
        setState(() => _project = v);
        _applyFilters();
      },
      onEvent: (v) {
        setState(() => _event = v);
        _applyFilters();
      },
      onTemplates: (v) {
        setState(() => _templates = v);
        _applyFilters();
      },
      onOfficials: (v) {
        setState(() => _officials = v);
        _applyFilters();
      },
    );
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _applyFilters,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 28,
                  24,
                  compact ? 16 : 28,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Documents',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const Text(
                                'Centralisez les fichiers, leurs périmètres et leur validation.',
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          key: const Key('new-document'),
                          onPressed: _create,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(compact ? 'Nouveau' : 'Nouveau document'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _search,
                      onSubmitted: (_) => _applyFilters(),
                      decoration: InputDecoration(
                        labelText: 'Rechercher un document',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Rechercher',
                          onPressed: _applyFilters,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (compact)
                      Card(
                        child: ExpansionTile(
                          title: const Text('Filtres'),
                          leading: const Icon(Icons.filter_list_rounded),
                          childrenPadding: const EdgeInsets.all(14),
                          children: [filters],
                        ),
                      )
                    else
                      filters,
                    if (_references.unavailableSources.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Certaines références sont temporairement indisponibles. La liste des documents reste accessible.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _applyFilters,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_documents.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('Aucun document ne correspond aux filtres.'),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 28,
                  4,
                  compact ? 16 : 28,
                  32,
                ),
                sliver: compact
                    ? SliverList.builder(
                        itemCount: _documents.length,
                        itemBuilder: (context, index) => SizedBox(
                          height: 330,
                          child: DocumentCard(
                            document: _documents[index],
                            references: _references,
                            onOpen: () => _open(_documents[index]),
                          ),
                        ),
                      )
                    : SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 410,
                              mainAxisExtent: 315,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                        itemCount: _documents.length,
                        itemBuilder: (context, index) => DocumentCard(
                          document: _documents[index],
                          references: _references,
                          onOpen: () => _open(_documents[index]),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  void _notice(String message, [bool error = false]) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
}

class _Filters extends StatelessWidget {
  final String category, status, visibility, pole, project, event;
  final bool templates, officials;
  final DocumentReferenceData references;
  final ValueChanged<String> onCategory,
      onStatus,
      onVisibility,
      onPole,
      onProject,
      onEvent;
  final ValueChanged<bool> onTemplates, onOfficials;
  const _Filters({
    required this.category,
    required this.status,
    required this.visibility,
    required this.pole,
    required this.project,
    required this.event,
    required this.templates,
    required this.officials,
    required this.references,
    required this.onCategory,
    required this.onStatus,
    required this.onVisibility,
    required this.onPole,
    required this.onProject,
    required this.onEvent,
    required this.onTemplates,
    required this.onOfficials,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _Select(
        label: 'Catégorie',
        value: category,
        items: [
          const MapEntry('all', 'Toutes les catégories'),
          ...DocumentModel.categoryOptions.map(
            (item) => MapEntry(item.value, item.label),
          ),
        ],
        onChanged: onCategory,
      ),
      _Select(
        label: 'Statut',
        value: status,
        items: const [
          MapEntry('all', 'Tous les statuts'),
          MapEntry('draft', 'Brouillon'),
          MapEntry('submitted', 'Soumis'),
          MapEntry('pending_validation', 'En attente de validation'),
          MapEntry('validated', 'Validé'),
          MapEntry('rejected', 'Rejeté'),
          MapEntry('archived', 'Archivé'),
          MapEntry('expired', 'Expiré'),
        ],
        onChanged: onStatus,
      ),
      _Select(
        label: 'Visibilité',
        value: visibility,
        items: const [
          MapEntry('all', 'Toutes les visibilités'),
          MapEntry('public_club', 'Tout le club'),
          MapEntry('internal', 'Membres'),
          MapEntry('pole_only', 'Pôle sélectionné'),
          MapEntry('project_only', 'Projet sélectionné'),
          MapEntry('enacchef_only', 'Responsables'),
          MapEntry('private', 'Privé'),
        ],
        onChanged: onVisibility,
      ),
      _Select(
        label: 'Pôle',
        value: pole,
        items: [
          const MapEntry('all', 'Tous les pôles'),
          ...references.poles.map((item) => MapEntry(item.id, item.name)),
        ],
        onChanged: onPole,
      ),
      _Select(
        label: 'Projet',
        value: project,
        items: [
          const MapEntry('all', 'Tous les projets'),
          ...references.projects.map((item) => MapEntry(item.id, item.name)),
        ],
        onChanged: onProject,
      ),
      _Select(
        label: 'Événement',
        value: event,
        items: [
          const MapEntry('all', 'Tous les événements'),
          ...references.events.map((item) => MapEntry(item.id, item.title)),
        ],
        onChanged: onEvent,
      ),
      FilterChip(
        label: const Text('Modèles'),
        selected: templates,
        onSelected: onTemplates,
      ),
      FilterChip(
        label: const Text('Officiels'),
        selected: officials,
        onSelected: onOfficials,
      ),
    ],
  );
}

class _Select extends StatelessWidget {
  final String label, value;
  final List<MapEntry<String, String>> items;
  final ValueChanged<String> onChanged;
  const _Select({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item.key,
              child: Text(item.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) => onChanged(value!),
    ),
  );
}

String _msg(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();
