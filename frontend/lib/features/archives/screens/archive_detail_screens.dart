import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/archive_models.dart';
import '../services/archives_gateway.dart';
import 'archive_forms.dart';
import 'archives_center_sections.dart';

class ArchiveItemDetailScreen extends StatefulWidget {
  final String archiveId;
  final ArchivesGateway? gateway;
  const ArchiveItemDetailScreen({
    super.key,
    required this.archiveId,
    this.gateway,
  });

  @override
  State<ArchiveItemDetailScreen> createState() =>
      _ArchiveItemDetailScreenState();
}

class _ArchiveItemDetailScreenState extends State<ArchiveItemDetailScreen> {
  late final ArchivesGateway _gateway;
  ArchiveItemModel? _item;
  ArchivePermissions _permissions = const ArchivePermissions();
  Object? _error;
  bool _loading = true;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiArchivesGateway();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<Object>([
        _gateway.getItem(widget.archiveId),
        _gateway.getPermissions(),
      ]);
      if (mounted) {
        setState(() {
          _item = values[0] as ArchiveItemModel;
          _permissions = values[1] as ArchivePermissions;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return DetailErrorState(error: _error!, onRetry: _load);
    final item = _item!;
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
      children: [
        Text(
          '${item.year ?? 'Année non renseignée'} · ${item.category}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(item.statusLabel)),
            Chip(label: Text(item.visibilityLabel)),
            if (item.isFeatured) const Chip(label: Text('Mis en avant')),
            Chip(label: Text(item.isPublic ? 'Public' : 'Non public')),
            if (!item.isPersisted)
              const Chip(label: Text('Mémoire historique Enactus ESP')),
          ],
        ),
        const SizedBox(height: 24),
        if (item.description != null)
          DetailSection(title: 'Description', child: Text(item.description!)),
        if (item.humanMetadataNote != null)
          DetailSection(
            title: 'Contexte',
            child: Text(item.humanMetadataNote!),
          ),
        DetailSection(
          title: 'Liens et périmètre',
          child: Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              if (item.poleId != null) Text('Pôle · ${item.poleId}'),
              if (item.projectId != null) Text('Projet · ${item.projectId}'),
              if (item.documentId != null)
                Text('Document · ${item.documentId}'),
              if (item.seasonId != null) Text('Saison · ${item.seasonId}'),
            ],
          ),
        ),
        if (item.tags.isNotEmpty)
          DetailSection(
            title: 'Tags',
            child: Wrap(
              spacing: 8,
              children: item.tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          ),
        if (item.sourceUrl != null)
          DetailSection(
            title: 'Source',
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _open(item.sourceUrl),
                icon: const Icon(Icons.open_in_new),
                label: Text(item.sourceLabel ?? 'Ouvrir la source'),
              ),
            ),
          ),
        if (item.file != null)
          DetailSection(
            title: 'Fichier',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.file!.previewUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => _open(item.file!.previewUrl),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Prévisualiser'),
                  ),
                if (item.file!.downloadUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => _open(item.file!.downloadUrl),
                    icon: const Icon(Icons.download_outlined),
                    label: Text('Télécharger ${item.file!.name}'),
                  ),
              ],
            ),
          ),
        DetailSection(
          title: 'Dates',
          child: Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              if (item.createdAt != null)
                Text('Créée le ${archiveDateLabel(item.createdAt!)}'),
              if (item.updatedAt != null)
                Text('Mise à jour le ${archiveDateLabel(item.updatedAt!)}'),
              if (item.validatedAt != null)
                Text('Validée le ${archiveDateLabel(item.validatedAt!)}'),
              if (item.rejectedAt != null)
                Text('Rejetée le ${archiveDateLabel(item.rejectedAt!)}'),
            ],
          ),
        ),
        if (item.rejectionReason != null)
          DetailSection(
            title: 'Motif du rejet',
            child: Text(item.rejectionReason!),
          ),
        if (item.isPersisted) _workflowActions(item),
      ],
    );
  }

  Widget _workflowActions(ArchiveItemModel item) => DetailSection(
    title: 'Actions autorisées',
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (_permissions.canCreate)
          OutlinedButton.icon(
            onPressed: _acting
                ? null
                : () async {
                    if (await showArchiveItemDialog(
                      context,
                      _gateway,
                      item: item,
                    )) {
                      await _load();
                    }
                  },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier'),
          ),
        if (_permissions.canCreate && item.status == 'draft')
          FilledButton(
            onPressed: _acting
                ? null
                : () => _act(() => _gateway.submitItem(item.id)),
            child: const Text('Soumettre'),
          ),
        if (_permissions.canValidate && item.status == 'submitted') ...[
          FilledButton(
            onPressed: _acting
                ? null
                : () => _act(() => _gateway.validateItem(item.id)),
            child: const Text('Valider'),
          ),
          OutlinedButton(
            onPressed: _acting ? null : () => _reject(item),
            child: const Text('Rejeter'),
          ),
        ],
        if (_permissions.canValidate &&
            {'validated', 'rejected'}.contains(item.status))
          OutlinedButton(
            onPressed: _acting
                ? null
                : () => _act(() => _gateway.archiveItem(item.id)),
            child: const Text('Archiver'),
          ),
      ],
    ),
  );

  Future<void> _act(Future<ArchiveItemModel> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      _item = await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject(ArchiveItemModel item) async {
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RejectionDialog(),
    );
    if (reason != null) await _act(() => _gateway.rejectItem(item.id, reason));
  }

  Future<void> _open(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || !await launchUrl(uri, webOnlyWindowName: '_blank')) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lien indisponible.')));
      }
    }
  }
}

class RejectionDialog extends StatefulWidget {
  const RejectionDialog({super.key});
  @override
  State<RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<RejectionDialog> {
  final _controller = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rejeter l’archive'),
    content: TextField(
      controller: _controller,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Motif obligatoire',
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          if (value.isEmpty) {
            setState(() => _error = 'Indiquez un motif.');
          } else {
            Navigator.pop(context, value);
          }
        },
        child: const Text('Rejeter'),
      ),
    ],
  );
}

class HistoricalProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final ArchivesGateway? gateway;
  const HistoricalProjectDetailScreen({
    super.key,
    required this.projectId,
    this.gateway,
  });

  @override
  State<HistoricalProjectDetailScreen> createState() =>
      _HistoricalProjectDetailScreenState();
}

class _HistoricalProjectDetailScreenState
    extends State<HistoricalProjectDetailScreen> {
  late final ArchivesGateway _gateway;
  HistoricalProjectModel? _project;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiArchivesGateway();
    _load();
  }

  Future<void> _load() async {
    try {
      final project = await _gateway.getHistoricalProject(widget.projectId);
      if (mounted) setState(() => _project = project);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return DetailErrorState(error: _error!, onRetry: _load);
    final project = _project;
    if (project == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 30),
      children: [
        Text(
          '${project.periodLabel} · ${project.statusLabel}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          project.name,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (!project.isPersisted) ...[
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text('Mémoire historique Enactus ESP')),
          ),
        ],
        const SizedBox(height: 28),
        if (project.description != null)
          DetailSection(title: 'Contexte', child: Text(project.description!)),
        if (project.problem != null)
          DetailSection(title: 'Le problème', child: Text(project.problem!)),
        if (project.solution != null)
          DetailSection(title: 'La réponse', child: Text(project.solution!)),
        if (project.impactSummary != null)
          DetailSection(
            title: 'Impact et héritage',
            child: Text(project.impactSummary!),
          ),
        if (project.keyMembers.isNotEmpty)
          DetailSection(
            title: 'Équipe',
            child: BulletList(values: project.keyMembers),
          ),
        if (project.awards.isNotEmpty)
          DetailSection(
            title: 'Récompenses',
            child: BulletList(values: project.awards),
          ),
        if (project.documentIds.isNotEmpty || project.mediaFileIds.isNotEmpty)
          DetailSection(
            title: 'Documents & médias',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (project.documentIds.isNotEmpty)
                  Text('${project.documentIds.length} document(s) associé(s)'),
                if (project.mediaFileIds.isNotEmpty)
                  Text('${project.mediaFileIds.length} média(s) associé(s)'),
              ],
            ),
          ),
        if (project.linkedProjectId != null)
          DetailSection(
            title: 'Projet moderne lié',
            child: Text(project.linkedProjectId!),
          ),
      ],
    );
  }
}

class HallOfFameDetailScreen extends StatefulWidget {
  final String entryId;
  final ArchivesGateway? gateway;
  const HallOfFameDetailScreen({
    super.key,
    required this.entryId,
    this.gateway,
  });

  @override
  State<HallOfFameDetailScreen> createState() => _HallOfFameDetailScreenState();
}

class _HallOfFameDetailScreenState extends State<HallOfFameDetailScreen> {
  late final ArchivesGateway _gateway;
  HallOfFameEntryModel? _entry;
  Object? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiArchivesGateway();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _done = false;
      _error = null;
    });
    try {
      final entry = await _gateway.getHallOfFameEntry(widget.entryId);
      if (mounted) setState(() => _entry = entry);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_done) return const Center(child: CircularProgressIndicator());
    if (_error != null) return DetailErrorState(error: _error!, onRetry: _load);
    final entry = _entry;
    if (entry == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Cette entrée du Hall of Fame est introuvable.'),
        ),
      );
    }
    final hasTrace =
        entry.file?.previewUrl != null ||
        entry.file?.downloadUrl != null ||
        entry.externalUrl != null;
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 30),
      children: [
        Text(
          '${entry.year ?? 'Année non renseignée'} · ${entry.entryType}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          entry.title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (entry.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(entry.subtitle!, style: Theme.of(context).textTheme.titleLarge),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (entry.isFeatured) const Chip(label: Text('Mis en avant')),
            if (!entry.isPersisted)
              const Chip(label: Text('Mémoire historique Enactus ESP')),
            if (entry.scoreValue != null)
              Chip(
                label: Text(
                  '${entry.scoreValue} ${entry.scoreLabel ?? ''}'.trim(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        if (entry.description != null)
          DetailSection(title: 'Le moment', child: Text(entry.description!)),
        if (entry.subtitle != null && entry.description != null)
          DetailSection(
            title: 'Pourquoi il compte',
            child: Text(entry.subtitle!),
          ),
        if (hasTrace)
          DetailSection(
            title: 'Trace / média',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (entry.file?.previewUrl != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        openArchiveUrl(context, entry.file!.previewUrl),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Prévisualiser'),
                  ),
                if (entry.file?.downloadUrl != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        openArchiveUrl(context, entry.file!.downloadUrl),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Télécharger'),
                  ),
                if (entry.externalUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => openArchiveUrl(context, entry.externalUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ouvrir le lien externe'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class DetailSection extends StatelessWidget {
  final String title;
  final Widget child;
  const DetailSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class BulletList extends StatelessWidget {
  final List<String> values;
  const BulletList({super.key, required this.values});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: values
        .map(
          (value) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• $value'),
          ),
        )
        .toList(),
  );
}

class DetailErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const DetailErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(error.toString().replaceFirst('Exception: ', '')),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}
