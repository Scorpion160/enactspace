import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/archive_models.dart';
import '../services/archives_gateway.dart';
import 'archive_forms.dart';

class ArchivesOverview extends StatelessWidget {
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  const ArchivesOverview({
    super.key,
    required this.home,
    required this.gateway,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionIntro(
        eyebrow: 'MÉMOIRE VIVANTE',
        title: 'Ce que les sources disponibles racontent',
        description:
            'Les chiffres non validés restent explicitement présentés comme historiques à confirmer.',
      ),
      const SizedBox(height: 16),
      HistoricalImpactSummaryWrap(summary: home.summary),
      if (home.summary.values.isNotEmpty) const SizedBox(height: 16),
      HistoricalStatisticsWrap(statistics: home.statistics.take(6).toList()),
      const SizedBox(height: 28),
      EditorialList(
        title: 'Projets historiques',
        children: home.projects
            .take(3)
            .map(
              (item) => HistoricalProjectCard(
                item: item,
                gateway: gateway,
                canEdit: home.permissions.canCreate,
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 28),
      EditorialList(
        title: 'Hall of Fame',
        children: home.hallOfFame
            .take(3)
            .map(
              (item) => HallOfFameCard(
                item: item,
                gateway: gateway,
                canEdit: home.permissions.canCreate,
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 28),
      EditorialList(
        title: 'Traces documentaires',
        children: home.documents
            .take(3)
            .map(
              (item) => ArchiveDocumentCard(
                item: item,
                gateway: gateway,
                canEdit: home.permissions.canCreate,
              ),
            )
            .toList(),
      ),
    ],
  );
}

class ArchiveItemsCenter extends StatefulWidget {
  final List<ArchiveItemModel> items;
  final ArchivesGateway gateway;
  final ArchivePermissions permissions;
  const ArchiveItemsCenter({
    super.key,
    required this.items,
    required this.gateway,
    required this.permissions,
  });

  @override
  State<ArchiveItemsCenter> createState() => _ArchiveItemsCenterState();
}

class _ArchiveItemsCenterState extends State<ArchiveItemsCenter> {
  final _search = TextEditingController();
  String? _category;
  String? _status;
  String? _visibility;
  int? _year;

  @override
  void initState() {
    super.initState();
    _search.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final values = widget.items.where((item) {
      final matchesSearch =
          query.isEmpty ||
          '${item.title} ${item.description ?? ''} ${item.tags.join(' ')}'
              .toLowerCase()
              .contains(query);
      return matchesSearch &&
          (_category == null || item.category == _category) &&
          (_status == null || item.status == _status) &&
          (_visibility == null || item.visibility == _visibility) &&
          (_year == null || item.year == _year);
    }).toList();
    final years =
        widget.items.map((item) => item.year).whereType<int>().toSet().toList()
          ..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionIntro(
          eyebrow: 'COLLECTION',
          title: 'Archives',
          description:
              'Contenus documentés, sources et fichiers conservés par le club.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SearchField(controller: _search),
            FilterDropdown<int>(
              label: 'Année',
              value: _year,
              values: years,
              onChanged: (value) => setState(() => _year = value),
            ),
            FilterDropdown<String>(
              label: 'Catégorie',
              value: _category,
              values: archiveCategories,
              onChanged: (value) => setState(() => _category = value),
            ),
            FilterDropdown<String>(
              label: 'Statut',
              value: _status,
              values: const [
                'draft',
                'submitted',
                'validated',
                'rejected',
                'archived',
                'hidden',
              ],
              itemLabel: archiveStatusLabel,
              onChanged: (value) => setState(() => _status = value),
            ),
            FilterDropdown<String>(
              label: 'Visibilité',
              value: _visibility,
              values: archiveVisibilities,
              itemLabel: archiveVisibilityLabel,
              onChanged: (value) => setState(() => _visibility = value),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (values.isEmpty)
          const EmptyArchivesState(
            label: 'Aucune archive ne correspond à ces filtres.',
          )
        else
          for (final item in values)
            RecordCard(
              title: item.title,
              eyebrow:
                  '${item.year ?? 'Année non renseignée'} · ${item.category}',
              description: item.description,
              badges: [item.statusLabel, item.visibilityLabel],
              featured: item.isFeatured,
              memoryOnly: !item.isPersisted,
              onOpen: () => context.go(
                '/archives/items/${item.id}',
                extra: widget.gateway,
              ),
              openLabel: 'Ouvrir archive',
              onEdit: widget.permissions.canCreate && item.isPersisted
                  ? () => showArchiveItemDialog(
                      context,
                      widget.gateway,
                      item: item,
                    )
                  : null,
            ),
      ],
    );
  }
}

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  const SearchField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: TextField(
      key: const Key('archives_search'),
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Rechercher',
        prefixIcon: Icon(Icons.search),
      ),
    ),
  );
}

class FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> values;
  final String Function(T)? itemLabel;
  final ValueChanged<T?> onChanged;
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.itemLabel,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T>(value: null, child: const Text('Tous')),
        for (final item in values)
          DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabel?.call(item) ?? '$item'),
          ),
      ],
      onChanged: onChanged,
    ),
  );
}

class HistoricalProjectsCenter extends StatefulWidget {
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  const HistoricalProjectsCenter({
    super.key,
    required this.home,
    required this.gateway,
  });

  @override
  State<HistoricalProjectsCenter> createState() =>
      _HistoricalProjectsCenterState();
}

class _HistoricalProjectsCenterState extends State<HistoricalProjectsCenter> {
  final _search = TextEditingController();
  int? _year;
  String? _status;

  @override
  void initState() {
    super.initState();
    _search.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final years =
        widget.home.projects
            .map((item) => item.year)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final values = widget.home.projects.where(
      (item) =>
          (query.isEmpty ||
              '${item.name} ${item.description ?? ''}'.toLowerCase().contains(
                query,
              )) &&
          (_year == null || item.year == _year) &&
          (_status == null || item.status == _status),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 12,
          children: [
            const SizedBox(
              width: 650,
              child: SectionIntro(
                eyebrow: 'HÉRITAGE',
                title: 'Projets historiques',
                description:
                    'Les initiatives retournées par le serveur, sans récit ni indicateur ajouté côté Flutter.',
              ),
            ),
            if (widget.home.permissions.canCreate)
              FilledButton.icon(
                onPressed: () =>
                    showHistoricalProjectDialog(context, widget.gateway),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau projet historique'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SearchField(controller: _search),
            FilterDropdown<int>(
              label: 'Année',
              value: _year,
              values: years,
              onChanged: (value) => setState(() => _year = value),
            ),
            FilterDropdown<String>(
              label: 'Statut',
              value: _status,
              values: const [
                'historique',
                'archive',
                'archivé',
                'continue',
                'continué',
                'developpement',
                'développement',
              ],
              itemLabel: historicalProjectStatusLabel,
              onChanged: (value) => setState(() => _status = value),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final item in values)
          HistoricalProjectCard(
            item: item,
            gateway: widget.gateway,
            canEdit: widget.home.permissions.canCreate,
          ),
      ],
    );
  }
}

class HistoricalProjectCard extends StatelessWidget {
  final HistoricalProjectModel item;
  final ArchivesGateway gateway;
  final bool canEdit;
  const HistoricalProjectCard({
    super.key,
    required this.item,
    required this.gateway,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) => RecordCard(
    title: item.name,
    eyebrow: '${item.periodLabel} · ${item.statusLabel}',
    description: item.description,
    memoryOnly: !item.isPersisted,
    onOpen: () => context.go('/archives/projects/${item.id}', extra: gateway),
    openLabel: 'Ouvrir projet',
    onEdit: canEdit && item.isPersisted
        ? () => showHistoricalProjectDialog(context, gateway, item: item)
        : null,
  );
}

class HallOfFameCenter extends StatefulWidget {
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  const HallOfFameCenter({
    super.key,
    required this.home,
    required this.gateway,
  });

  @override
  State<HallOfFameCenter> createState() => _HallOfFameCenterState();
}

class _HallOfFameCenterState extends State<HallOfFameCenter> {
  final _search = TextEditingController();
  int? _year;
  String? _type;
  bool _featured = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final years =
        widget.home.hallOfFame
            .map((item) => item.year)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final types =
        widget.home.hallOfFame
            .map((item) => item.entryType)
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final values = widget.home.hallOfFame.where(
      (item) =>
          (query.isEmpty ||
              '${item.title} ${item.subtitle ?? ''} ${item.description ?? ''}'
                  .toLowerCase()
                  .contains(query)) &&
          (_year == null || item.year == _year) &&
          (_type == null || item.entryType == _type) &&
          (!_featured || item.isFeatured),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 12,
          children: [
            const SizedBox(
              width: 650,
              child: SectionIntro(
                eyebrow: 'HALL OF FAME',
                title: 'Les moments qui restent',
                description:
                    'Une lecture chronologique et humaine, strictement fondée sur les informations disponibles.',
              ),
            ),
            if (widget.home.permissions.canCreate)
              FilledButton.icon(
                key: const Key('new_hall_of_fame_button'),
                onPressed: () => showHallOfFameDialog(context, widget.gateway),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle entrée Hall of Fame'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SearchField(controller: _search),
            FilterDropdown<int>(
              label: 'Année',
              value: _year,
              values: years,
              onChanged: (value) => setState(() => _year = value),
            ),
            FilterDropdown<String>(
              label: 'Type',
              value: _type,
              values: types,
              itemLabel: hallOfFameEntryTypeLabel,
              onChanged: (value) => setState(() => _type = value),
            ),
            FilterChip(
              label: const Text('Mis en avant'),
              selected: _featured,
              onSelected: (value) => setState(() => _featured = value),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final item in values)
          HallOfFameCard(
            item: item,
            gateway: widget.gateway,
            canEdit: widget.home.permissions.canCreate,
          ),
      ],
    );
  }
}

class HallOfFameCard extends StatelessWidget {
  final HallOfFameEntryModel item;
  final ArchivesGateway gateway;
  final bool canEdit;
  const HallOfFameCard({
    super.key,
    required this.item,
    required this.gateway,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) => RecordCard(
    title: item.title,
    eyebrow: '${item.year ?? 'Année non renseignée'} · ${item.entryTypeLabel}',
    description: item.subtitle ?? item.description,
    featured: item.isFeatured,
    memoryOnly: !item.isPersisted,
    badges: item.scoreValue == null
        ? const []
        : ['${item.scoreValue} ${item.scoreLabel ?? ''}'.trim()],
    onOpen: () =>
        context.go('/archives/hall-of-fame/${item.id}', extra: gateway),
    openLabel: 'Ouvrir le Hall of Fame',
    onEdit: canEdit && item.isPersisted
        ? () => showHallOfFameDialog(context, gateway, item: item)
        : null,
  );
}

class HistoricalStatisticsCenter extends StatelessWidget {
  final List<HistoricalStatisticModel> statistics;
  final ArchivePermissions permissions;
  final ArchivesGateway gateway;
  const HistoricalStatisticsCenter({
    super.key,
    required this.statistics,
    required this.permissions,
    required this.gateway,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionIntro(
        eyebrow: 'IMPACT HISTORIQUE',
        title: 'Chiffres et niveau de confiance',
        description:
            'Une valeur historique fournie par le serveur n’est pas présentée comme certifiée sans validation.',
      ),
      const SizedBox(height: 18),
      HistoricalStatisticsWrap(
        statistics: statistics,
        onEdit: permissions.canValidate
            ? (item) => showHistoricalStatisticDialog(context, gateway, item)
            : null,
      ),
    ],
  );
}

class ArchiveMediaCenter extends StatefulWidget {
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  const ArchiveMediaCenter({
    super.key,
    required this.home,
    required this.gateway,
  });

  @override
  State<ArchiveMediaCenter> createState() => _ArchiveMediaCenterState();
}

class _ArchiveMediaCenterState extends State<ArchiveMediaCenter> {
  final _search = TextEditingController();
  int? _year;
  String? _type;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _search.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final years =
        widget.home.media
            .map((item) => item.year)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final types =
        widget.home.media.map((item) => item.mediaType).toSet().toList()
          ..sort();
    final projects =
        widget.home.media
            .map((item) => item.projectId)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    final values = widget.home.media.where(
      (item) =>
          (query.isEmpty ||
              '${item.title} ${item.description ?? ''}'.toLowerCase().contains(
                query,
              )) &&
          (_year == null || item.year == _year) &&
          (_type == null || item.mediaType == _type) &&
          (_projectId == null || item.projectId == _projectId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 12,
          children: [
            const SectionIntro(
              eyebrow: 'MÉMOIRE COLLECTIVE',
              title: 'Médias historiques',
              description:
                  'Photos, vidéos, presse et présentations historiques.',
            ),
            if (widget.home.permissions.canCreate)
              FilledButton.icon(
                onPressed: () => showMediaDialog(context, widget.gateway),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau média'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SearchField(controller: _search),
            FilterDropdown<int>(
              label: 'Année',
              value: _year,
              values: years,
              onChanged: (value) => setState(() => _year = value),
            ),
            FilterDropdown<String>(
              label: 'Type de média',
              value: _type,
              values: types,
              itemLabel: historicalMediaTypeLabel,
              onChanged: (value) => setState(() => _type = value),
            ),
            FilterDropdown<String>(
              label: 'Projet',
              value: _projectId,
              values: projects,
              onChanged: (value) => setState(() => _projectId = value),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (values.isEmpty)
          const EmptyArchivesState(
            label: 'Aucun média ne correspond à ces filtres.',
          )
        else
          for (final item in values)
            ArchiveMediaCard(
              item: item,
              gateway: widget.gateway,
              canEdit: widget.home.permissions.canCreate,
            ),
      ],
    );
  }
}

class ArchivesCollectionCenter extends StatelessWidget {
  final String sectionLabel;
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  const ArchivesCollectionCenter({
    super.key,
    required this.sectionLabel,
    required this.home,
    required this.gateway,
  });

  @override
  Widget build(BuildContext context) {
    final children = switch (sectionLabel) {
      'Palmarès' => home.awards.map(
        (item) => RecordCard(
          title: item.title,
          eyebrow: [
            item.year,
            item.competition,
            item.rank,
            item.result,
          ].where((value) => value != null && '$value'.isNotEmpty).join(' · '),
          description: item.description,
          featured: item.isFeatured,
          memoryOnly: !item.isPersisted,
          onEdit: home.permissions.canCreate && item.isPersisted
              ? () => showAwardDialog(context, gateway, item: item)
              : null,
        ),
      ),
      'Compétitions' => home.competitions.map(
        (item) => RecordCard(
          title: item.name,
          eyebrow: [
            item.year,
            item.stage,
            item.result,
            item.location,
          ].where((value) => value != null && '$value'.isNotEmpty).join(' · '),
          description: item.description,
          featured: item.isFeatured,
          memoryOnly: !item.isPersisted,
          onEdit: home.permissions.canCreate && item.isPersisted
              ? () => showCompetitionDialog(context, gateway, item: item)
              : null,
        ),
      ),
      'Médias' => home.media.map(
        (item) => ArchiveMediaCard(
          item: item,
          gateway: gateway,
          canEdit: home.permissions.canCreate,
        ),
      ),
      'Documents' => home.documents.map(
        (item) => ArchiveDocumentCard(
          item: item,
          gateway: gateway,
          canEdit: home.permissions.canCreate,
        ),
      ),
      _ => const Iterable<RecordCard>.empty(),
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 12,
          children: [
            SectionIntro(
              eyebrow: 'MÉMOIRE COLLECTIVE',
              title: sectionLabel,
              description: _description,
            ),
            if (home.permissions.canCreate)
              FilledButton.icon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add),
                label: Text('Nouveau · $sectionLabel'),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (children.isEmpty)
          const EmptyArchivesState(label: 'Aucun contenu disponible.')
        else
          ...children,
      ],
    );
  }

  String get _description => switch (sectionLabel) {
    'Palmarès' =>
      'Distinctions, rangs et résultats, sans confondre les informations.',
    'Compétitions' =>
      'Une chronologie des participations retournées par le serveur.',
    'Médias' => 'Photos, vidéos, presse et présentations historiques.',
    'Documents' =>
      'Une collection historique dédiée, distincte du module Documents.',
    _ => '',
  };

  Future<void> _create(BuildContext context) => switch (sectionLabel) {
    'Palmarès' => showAwardDialog(context, gateway),
    'Compétitions' => showCompetitionDialog(context, gateway),
    'Médias' => showMediaDialog(context, gateway),
    'Documents' => showArchiveDocumentDialog(context, gateway),
    _ => Future.value(),
  };
}

class ArchiveMediaCard extends StatelessWidget {
  final ArchiveMediaModel item;
  final ArchivesGateway gateway;
  final bool canEdit;
  const ArchiveMediaCard({
    super.key,
    required this.item,
    required this.gateway,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) => RecordCard(
    title: item.title,
    eyebrow: '${item.year ?? ''} · ${item.mediaTypeLabel}',
    description: item.description,
    featured: item.isFeatured,
    memoryOnly: !item.isPersisted,
    onOpen: () => openArchiveUrl(
      context,
      item.file?.previewUrl ?? item.file?.downloadUrl ?? item.externalUrl,
    ),
    openLabel: item.externalUrl == null ? 'Ouvrir média' : 'Ouvrir',
    onEdit: canEdit && item.isPersisted
        ? () => showMediaDialog(context, gateway, item: item)
        : null,
  );
}

class ArchiveDocumentCard extends StatelessWidget {
  final ArchiveDocumentModel item;
  final ArchivesGateway gateway;
  final bool canEdit;
  const ArchiveDocumentCard({
    super.key,
    required this.item,
    required this.gateway,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) => RecordCard(
    title: item.title,
    eyebrow:
        '${item.year ?? ''} · ${item.documentTypeLabel} · ${archiveVisibilityLabel(item.visibility)}',
    description: item.description ?? item.sourceLabel,
    featured: item.isFeatured,
    memoryOnly: !item.isPersisted,
    onOpen: () => openArchiveUrl(
      context,
      item.file?.previewUrl ?? item.file?.downloadUrl,
    ),
    openLabel: 'Ouvrir document',
    onEdit: canEdit && item.isPersisted
        ? () => showArchiveDocumentDialog(context, gateway, item: item)
        : null,
  );
}

Future<void> openArchiveUrl(BuildContext context, String? value) async {
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null || !await launchUrl(uri, webOnlyWindowName: '_blank')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun lien exploitable disponible.')),
      );
    }
  }
}

class RecordCard extends StatelessWidget {
  final String title;
  final String eyebrow;
  final String? description;
  final List<String> badges;
  final bool featured;
  final bool memoryOnly;
  final VoidCallback? onOpen;
  final String openLabel;
  final VoidCallback? onEdit;
  const RecordCard({
    super.key,
    required this.title,
    required this.eyebrow,
    this.description,
    this.badges = const [],
    this.featured = false,
    this.memoryOnly = false,
    this.onOpen,
    this.openLabel = 'Ouvrir',
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description!),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (featured) const Chip(label: Text('Mis en avant')),
              if (memoryOnly)
                const Chip(label: Text('Mémoire historique Enactus ESP')),
              for (final badge in badges) Chip(label: Text(badge)),
            ],
          ),
          if (onOpen != null || onEdit != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Wrap(
                spacing: 8,
                children: [
                  if (onOpen != null)
                    TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(openLabel),
                    ),
                  if (onEdit != null)
                    TextButton.icon(
                      key: const Key('archive_edit_button'),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifier'),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class SectionIntro extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  const SectionIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(eyebrow, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(description),
    ],
  );
}

class EditorialList extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const EditorialList({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      if (children.isEmpty)
        const EmptyArchivesState(label: 'Aucune donnée disponible.')
      else
        ...children,
    ],
  );
}

class HistoricalImpactSummaryWrap extends StatelessWidget {
  final ArchiveImpactSummaryModel summary;
  const HistoricalImpactSummaryWrap({super.key, required this.summary});

  @override
  Widget build(BuildContext context) => summary.values.isEmpty
      ? const SizedBox.shrink()
      : Wrap(
          spacing: 12,
          runSpacing: 12,
          children: summary.values.entries
              .map(
                (entry) => SizedBox(
                  width: 220,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.value}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(_impactSummaryLabel(entry.key)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
}

class HistoricalStatisticsWrap extends StatelessWidget {
  final List<HistoricalStatisticModel> statistics;
  final ValueChanged<HistoricalStatisticModel>? onEdit;
  const HistoricalStatisticsWrap({
    super.key,
    required this.statistics,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) => statistics.isEmpty
      ? const EmptyArchivesState(
          label: 'Aucune statistique historique disponible.',
        )
      : Wrap(
          spacing: 12,
          runSpacing: 12,
          children: statistics
              .map(
                (item) => SizedBox(
                  width: 270,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.value == null
                                ? 'Non renseigné'
                                : '${item.value} ${item.unit ?? ''}'.trim(),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Chip(label: Text(item.confidenceLabel)),
                          if (item.description != null) Text(item.description!),
                          if (item.sourceLabel != null)
                            Text('Source : ${item.sourceLabel}'),
                          if (item.validatedAt != null)
                            Text(
                              'Validé le ${archiveDateLabel(item.validatedAt!)}',
                            ),
                          if (onEdit != null)
                            TextButton.icon(
                              onPressed: () => onEdit!(item),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Vérifier / modifier'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
}

class EmptyArchivesState extends StatelessWidget {
  final String label;
  const EmptyArchivesState({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Center(child: Text(label)),
  );
}

String archiveDateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _impactSummaryLabel(String key) {
  const labels = {
    'created_projects': 'Projets créés',
    'developing_projects': 'Projets en développement',
    'developed_products': 'Produits développés',
    'touched_sdgs': 'ODD concernés',
    'created_jobs': 'Emplois documentés',
    'saved_lives': 'Vies préservées documentées',
    'planted_trees': 'Arbres plantés documentés',
    'cumulative_fcfa_gains': 'Gains cumulés documentés',
    'impacted_lives': 'Vies touchées documentées',
  };
  final known = labels[key];
  if (known != null) return known;
  final words = key.split('_').where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return 'Indicateur historique';
  final text = words.join(' ');
  return '${text[0].toUpperCase()}${text.substring(1)}';
}
