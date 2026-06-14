import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/document_model.dart';
import '../services/documents_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final DocumentsService _documentsService = DocumentsService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;

  List<DocumentModel> _documents = [];
  String _category = 'all';
  String _visibility = 'all';
  bool? _officialFilter;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final documents = await _documentsService.getDocuments(
        search: _searchController.text,
        category: _category,
        visibility: _visibility,
        isOfficial: _officialFilter,
      );

      if (!mounted) return;

      setState(() {
        _documents = documents;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCreateDocumentDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CreateDocumentDialog(documentsService: _documentsService);
      },
    );

    if (created == true) {
      await _loadDocuments();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document créé avec succès.')),
      );
    }
  }

  Future<void> _validateDocument(DocumentModel document) async {
    try {
      await _documentsService.validateDocument(document.id);
      await _loadDocuments();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document marqué comme officiel.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _unvalidateDocument(DocumentModel document) async {
    try {
      await _documentsService.unvalidateDocument(document.id);
      await _loadDocuments();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Validation retirée.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _deleteDocument(DocumentModel document) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le document'),
          content: Text('Voulez-vous vraiment supprimer "${document.title}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _documentsService.deleteDocument(document.id);
      await _loadDocuments();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document supprimé.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  int get _officialCount {
    return _documents.where((document) => document.isOfficial).length;
  }

  int get _templateCount {
    return _documents.where((document) => document.isTemplate).length;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _DocumentsHeader(
            total: _documents.length,
            official: _officialCount,
            templates: _templateCount,
            onRefresh: _loadDocuments,
            onCreate: _openCreateDocumentDialog,
          ),
          const SizedBox(height: 18),
          _DocumentsFilters(
            searchController: _searchController,
            category: _category,
            visibility: _visibility,
            officialFilter: _officialFilter,
            onCategoryChanged: (value) async {
              setState(() => _category = value);
              await _loadDocuments();
            },
            onVisibilityChanged: (value) async {
              setState(() => _visibility = value);
              await _loadDocuments();
            },
            onOfficialChanged: (value) async {
              setState(() => _officialFilter = value);
              await _loadDocuments();
            },
            onSearch: _loadDocuments,
          ),
          const SizedBox(height: 22),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _loadDocuments)
          else if (_documents.isEmpty)
            const _EmptyDocumentsCard()
          else
            _DocumentsGrid(
              documents: _documents,
              onValidate: _validateDocument,
              onUnvalidate: _unvalidateDocument,
              onDelete: _deleteDocument,
            ),
        ],
      ),
    );
  }
}

class _DocumentsHeader extends StatelessWidget {
  final int total;
  final int official;
  final int templates;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  const _DocumentsHeader({
    required this.total,
    required this.official,
    required this.templates,
    required this.onRefresh,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
        ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.note_add_rounded),
          label: const Text('Nouveau document'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: isWide
          ? Row(
              children: [
                _HeaderIcon(),
                const SizedBox(width: 18),
                Expanded(
                  child: _HeaderText(
                    total: total,
                    official: official,
                    templates: templates,
                  ),
                ),
                actions,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderIcon(),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _HeaderText(
                        total: total,
                        official: official,
                        templates: templates,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                actions,
              ],
            ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.folder_copy_rounded,
        color: AppTheme.softBlack,
        size: 34,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final int total;
  final int official;
  final int templates;

  const _HeaderText({
    required this.total,
    required this.official,
    required this.templates,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documents',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$total document(s) • $official officiel(s) • $templates modèle(s)',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }
}

class _DocumentsFilters extends StatelessWidget {
  final TextEditingController searchController;
  final String category;
  final String visibility;
  final bool? officialFilter;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<bool?> onOfficialChanged;
  final VoidCallback onSearch;

  const _DocumentsFilters({
    required this.searchController,
    required this.category,
    required this.visibility,
    required this.officialFilter,
    required this.onCategoryChanged,
    required this.onVisibilityChanged,
    required this.onOfficialChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final searchWidth = wide ? 280.0 : constraints.maxWidth;
            final filterWidth = constraints.maxWidth >= 560
                ? 260.0
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: searchWidth,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Rechercher',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: onSearch,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                    onSubmitted: (_) => onSearch(),
                  ),
                ),
                SizedBox(
                  width: filterWidth,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Toutes')),
                      DropdownMenuItem(
                        value: 'general',
                        child: Text('Général'),
                      ),
                      DropdownMenuItem(value: 'pv', child: Text('PV')),
                      DropdownMenuItem(
                        value: 'rapport',
                        child: Text('Rapport'),
                      ),
                      DropdownMenuItem(value: 'budget', child: Text('Budget')),
                      DropdownMenuItem(
                        value: 'fiche_projet',
                        child: Text('Fiche projet'),
                      ),
                      DropdownMenuItem(
                        value: 'pitch_deck',
                        child: Text('Pitch deck'),
                      ),
                      DropdownMenuItem(
                        value: 'support_formation',
                        child: Text('Support formation'),
                      ),
                      DropdownMenuItem(value: 'photo', child: Text('Photo')),
                      DropdownMenuItem(value: 'video', child: Text('Vidéo')),
                      DropdownMenuItem(
                        value: 'code_source',
                        child: Text('Code source'),
                      ),
                      DropdownMenuItem(
                        value: 'administratif',
                        child: Text('Administratif'),
                      ),
                      DropdownMenuItem(
                        value: 'partenariat',
                        child: Text('Partenariat'),
                      ),
                      DropdownMenuItem(value: 'autre', child: Text('Autre')),
                    ],
                    onChanged: (value) {
                      if (value != null) onCategoryChanged(value);
                    },
                  ),
                ),
                SizedBox(
                  width: filterWidth,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: visibility,
                    decoration: const InputDecoration(labelText: 'Visibilité'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Toutes')),
                      DropdownMenuItem(
                        value: 'public_club',
                        child: Text('Club'),
                      ),
                      DropdownMenuItem(
                        value: 'internal',
                        child: Text('Interne'),
                      ),
                      DropdownMenuItem(
                        value: 'pole_only',
                        child: Text('Pôle uniquement'),
                      ),
                      DropdownMenuItem(
                        value: 'project_only',
                        child: Text('Projet uniquement'),
                      ),
                      DropdownMenuItem(
                        value: 'enacchef_only',
                        child: Text('Bureau uniquement'),
                      ),
                      DropdownMenuItem(value: 'private', child: Text('Privé')),
                    ],
                    onChanged: (value) {
                      if (value != null) onVisibilityChanged(value);
                    },
                  ),
                ),
                ChoiceChip(
                  selected: officialFilter == null,
                  label: const Text('Tous'),
                  onSelected: (_) => onOfficialChanged(null),
                ),
                ChoiceChip(
                  selected: officialFilter == true,
                  label: const Text('Officiels'),
                  onSelected: (_) => onOfficialChanged(true),
                ),
                ChoiceChip(
                  selected: officialFilter == false,
                  label: const Text('Non officiels'),
                  onSelected: (_) => onOfficialChanged(false),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DocumentsGrid extends StatelessWidget {
  final List<DocumentModel> documents;
  final ValueChanged<DocumentModel> onValidate;
  final ValueChanged<DocumentModel> onUnvalidate;
  final ValueChanged<DocumentModel> onDelete;

  const _DocumentsGrid({
    required this.documents,
    required this.onValidate,
    required this.onUnvalidate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            final document = documents[index];

            return _DocumentCard(
              document: document,
              onValidate: onValidate,
              onUnvalidate: onUnvalidate,
              onDelete: onDelete,
            );
          },
        );
      },
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final ValueChanged<DocumentModel> onValidate;
  final ValueChanged<DocumentModel> onUnvalidate;
  final ValueChanged<DocumentModel> onDelete;

  const _DocumentCard({
    required this.document,
    required this.onValidate,
    required this.onUnvalidate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: document.isOfficial
                      ? Colors.green.shade100
                      : AppTheme.enactusYellow,
                  foregroundColor: AppTheme.softBlack,
                  child: Icon(
                    document.isOfficial
                        ? Icons.verified_rounded
                        : Icons.description_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    document.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              document.description ?? 'Aucune description',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(document.categoryLabel)),
                Chip(label: Text(document.visibilityLabel)),
                Chip(label: Text(document.fileTypeLabel)),
                if (document.isTemplate) const Chip(label: Text('Modèle')),
                if (document.isOfficial) const Chip(label: Text('Officiel')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ajouté le ${document.createdAtLabel}',
              style: const TextStyle(color: Colors.black45),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      document.fileUrl == null || document.fileUrl!.isEmpty
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lien : ${document.fileUrl}'),
                            ),
                          );
                        },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Lien'),
                ),
                if (!document.isOfficial)
                  ElevatedButton.icon(
                    onPressed: () => onValidate(document),
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Valider'),
                  ),
                if (document.isOfficial)
                  OutlinedButton.icon(
                    onPressed: () => onUnvalidate(document),
                    icon: const Icon(Icons.remove_done_rounded),
                    label: const Text('Retirer'),
                  ),
                IconButton(
                  onPressed: () => onDelete(document),
                  icon: const Icon(Icons.delete_rounded),
                  tooltip: 'Supprimer',
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CreateDocumentDialog extends StatefulWidget {
  final DocumentsService documentsService;

  const CreateDocumentDialog({super.key, required this.documentsService});

  @override
  State<CreateDocumentDialog> createState() => _CreateDocumentDialogState();
}

class _CreateDocumentDialogState extends State<CreateDocumentDialog> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _fileUrlController = TextEditingController();
  final _fileTypeController = TextEditingController(text: 'pdf');

  String _category = 'general';
  String _visibility = 'internal';
  bool _isTemplate = false;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _fileUrlController.dispose();
    _fileTypeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.documentsService.createDocument(
        title: _titleController.text,
        description: _descriptionController.text,
        fileUrl: _fileUrlController.text,
        fileType: _fileTypeController.text,
        category: _category,
        visibility: _visibility,
        isTemplate: _isTemplate,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau document'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le titre est obligatoire.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fileUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Lien du fichier',
                    hintText: 'https://drive.google.com/...',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le lien du fichier est obligatoire.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fileTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Type de fichier',
                    hintText: 'pdf, docx, xlsx...',
                    prefixIcon: Icon(Icons.file_present_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le type de fichier est obligatoire.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('Général')),
                    DropdownMenuItem(value: 'pv', child: Text('PV')),
                    DropdownMenuItem(value: 'rapport', child: Text('Rapport')),
                    DropdownMenuItem(value: 'budget', child: Text('Budget')),
                    DropdownMenuItem(
                      value: 'fiche_projet',
                      child: Text('Fiche projet'),
                    ),
                    DropdownMenuItem(
                      value: 'pitch_deck',
                      child: Text('Pitch deck'),
                    ),
                    DropdownMenuItem(
                      value: 'support_formation',
                      child: Text('Support formation'),
                    ),
                    DropdownMenuItem(value: 'photo', child: Text('Photo')),
                    DropdownMenuItem(value: 'video', child: Text('Vidéo')),
                    DropdownMenuItem(
                      value: 'code_source',
                      child: Text('Code source'),
                    ),
                    DropdownMenuItem(
                      value: 'administratif',
                      child: Text('Administratif'),
                    ),
                    DropdownMenuItem(
                      value: 'partenariat',
                      child: Text('Partenariat'),
                    ),
                    DropdownMenuItem(value: 'autre', child: Text('Autre')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _category = value);
                        },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _visibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibilité',
                    prefixIcon: Icon(Icons.visibility_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Toutes')),
                    DropdownMenuItem(value: 'public_club', child: Text('Club')),
                    DropdownMenuItem(value: 'internal', child: Text('Interne')),
                    DropdownMenuItem(
                      value: 'pole_only',
                      child: Text('Pôle uniquement'),
                    ),
                    DropdownMenuItem(
                      value: 'project_only',
                      child: Text('Projet uniquement'),
                    ),
                    DropdownMenuItem(
                      value: 'enacchef_only',
                      child: Text('Bureau uniquement'),
                    ),
                    DropdownMenuItem(value: 'private', child: Text('Privé')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _visibility = value);
                        },
                ),
                SwitchListTile(
                  value: _isTemplate,
                  title: const Text('Modèle de document'),
                  subtitle: const Text(
                    'Exemple : modèle PV, modèle rapport, canevas roadmap.',
                  ),
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _isTemplate = value);
                        },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_loading ? 'Création...' : 'Créer'),
        ),
      ],
    );
  }
}

class _EmptyDocumentsCard extends StatelessWidget {
  const _EmptyDocumentsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(26),
        child: Center(
          child: Text(
            'Aucun document trouvé.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
