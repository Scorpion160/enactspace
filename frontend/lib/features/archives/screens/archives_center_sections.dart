import 'package:flutter/material.dart';
import 'package:frontend/shared/ui/app_filter_toolbar.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/text/searchable_text.dart';
import '../../../shared/attachments/attachment_picker.dart';
import '../models/archive_models.dart';
import 'archive_visuals.dart';
import '../services/archives_gateway.dart';
import 'archive_forms.dart';
import 'archive_minutes_screen.dart';

Future<void> _refreshAfterWrite(
  Future<bool> result,
  VoidCallback? onChanged,
) async {
  if (await result) onChanged?.call();
}

class HistoricalMemoryContents extends StatefulWidget {
  final ArchivesHomeData home;
  final ArchivesGateway gateway;

  final VoidCallback? onChanged;
  const HistoricalMemoryContents({
    super.key,
    required this.home,
    this.onChanged,
    required this.gateway,
  });

  @override
  State<HistoricalMemoryContents> createState() =>
      _HistoricalMemoryContentsState();
}

class _HistoricalMemoryContentsState extends State<HistoricalMemoryContents> {
  String _section = 'Vue d’ensemble';

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    final gateway = widget.gateway;
    final contents = switch (_section) {
      'Minute de l’enacteur' => ArchiveMinutesCollection(
        home: home,
        gateway: gateway,
      ),
      'Chiffres' => HistoricalStatisticsCenter(
        statistics: home.statistics,
        permissions: home.permissions,
        gateway: gateway,
        onChanged: widget.onChanged,
      ),
      'Projets' => HistoricalProjectsCenter(
        home: home,
        gateway: gateway,
        onChanged: widget.onChanged,
      ),
      'Hall of Fame' => HallOfFameCenter(
        home: home,
        gateway: gateway,
        onChanged: widget.onChanged,
      ),
      'Médias' => ArchiveMediaCenter(
        home: home,
        gateway: gateway,
        onChanged: widget.onChanged,
      ),
      'Palmarès' || 'Compétitions' || 'Documents' => ArchivesCollectionCenter(
        sectionLabel: _section,
        home: home,
        gateway: gateway,
        onChanged: widget.onChanged,
      ),
      _ => ArchivesOverview(
        home: home,
        gateway: gateway,
        onOpenStatistics: () => setState(() => _section = 'Chiffres'),
        onChanged: widget.onChanged,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const sections = [
              'Vue d’ensemble',
              'Chiffres',
              'Projets',
              'Palmarès',
              'Compétitions',
              'Hall of Fame',
              'Minute de l’enacteur',
              'Documents',
              'Médias',
            ];
            if (constraints.maxWidth < 600) {
              return KeyedSubtree(
                key: ValueKey(_section),
                child: DropdownButtonFormField<String>(
                  key: const Key('historical_section_selector'),
                  initialValue: _section,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Explorer la mémoire',
                  ),
                  items: [
                    for (final section in sections)
                      DropdownMenuItem(value: section, child: Text(section)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _section = value);
                  },
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final section in sections)
                  ChoiceChip(
                    label: Text(section),
                    selected: _section == section,
                    onSelected: (_) => setState(() => _section = section),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        contents,
      ],
    );
  }
}

class ArchivesOverview extends StatelessWidget {
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  final VoidCallback? onOpenStatistics;
  final VoidCallback? onChanged;
  const ArchivesOverview({
    super.key,
    required this.home,
    required this.gateway,
    this.onOpenStatistics,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const ArchiveBanner(
        eyebrow: 'MÉMOIRE INSTITUTIONNELLE',
        title: 'L’aventure Enactus ESP',
        description:
            'Depuis 2015, des générations d’étudiants de l’ESP transforment leurs idées en solutions pour les communautés. Découvre les projets qui ont porté cette aventure, les personnes qu’ils accompagnent et les moments qui ont fait grandir le club.',
        motif: ArchiveMotif.binder,
      ),
      const SizedBox(height: 16),
      if (home.statistics.isEmpty)
        HistoricalImpactSummaryWrap(summary: home.summary)
      else
        HistoricalStatisticsWrap(statistics: home.statistics.take(4).toList()),
      if (onOpenStatistics != null)
        TextButton.icon(
          onPressed: onOpenStatistics,
          icon: const Icon(Icons.insights_outlined),
          label: const Text('Voir tous les chiffres historiques'),
        ),
      const SizedBox(height: 28),
      if (home.media.any((item) => item.imageAsset != null))
        EditorialList(
          title: 'Trophées et moments du club',
          children: home.media
              .where((item) => item.imageAsset != null)
              .take(3)
              .map(
                (item) => ArchiveMediaCard(
                  item: item,
                  gateway: gateway,
                  canEdit: false,
                ),
              )
              .toList(),
        ),
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
                onChanged: onChanged,
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
                onChanged: onChanged,
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
                onChanged: onChanged,
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
    final query = searchableText(_search.text);
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
          description: 'Documents, photos et récits de la vie du club.',
        ),
        const SizedBox(height: 16),
        AppFilterToolbar(
          search: SearchField(controller: _search),
          quickFilters: const [],
          filters: [
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
          actions: const [],
          activeFilterCount: [
            _year,
            _category,
            _status,
            _visibility,
          ].where((v) => v != null).length,
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
              onOpen: () => context.push(
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
  Widget build(BuildContext context) => TextField(
    key: const Key('archives_search'),
    controller: controller,
    decoration: const InputDecoration(
      hintText: 'Rechercher',
      prefixIcon: Icon(Icons.search),
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
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey((label, value)),
    initialValue: values.contains(value) ? value : null,
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
  );
}

class HistoricalProjectsCenter extends StatefulWidget {
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  final VoidCallback? onChanged;
  const HistoricalProjectsCenter({
    super.key,
    required this.home,
    this.onChanged,
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
    final query = searchableText(_search.text);
    final years =
        widget.home.projects
            .expand((item) => item.matchingYears)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final statuses =
        widget.home.projects.map((item) => item.statusLabel).toSet().toList()
          ..sort();
    final values = widget.home.projects.where(
      (item) =>
          (query.isEmpty ||
              searchableText(
                '${item.name} ${item.description ?? ''} ${item.sourceLabel ?? ''}',
              ).contains(query)) &&
          (_year == null || item.matchingYears.contains(_year)) &&
          (_status == null || item.statusLabel == _status),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArchiveBanner(
          eyebrow: 'HÉRITAGE',
          title: 'Projets historiques',
          description:
              'Découvrez les projets d’Enactus ESP, leur histoire, leur impact et leur héritage.',
          motif: ArchiveMotif.binder,
          actions: widget.home.permissions.canCreate
              ? FilledButton.icon(
                  onPressed: () => _refreshAfterWrite(
                    showHistoricalProjectDialog(context, widget.gateway),
                    widget.onChanged,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau projet historique'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        AppFilterToolbar(
          search: SearchField(controller: _search),
          quickFilters: const [],
          filters: [
            FilterDropdown<int>(
              label: 'Année',
              value: _year,
              values: years,
              onChanged: (value) => setState(() => _year = value),
            ),
            FilterDropdown<String>(
              label: 'Statut',
              value: _status,
              values: statuses,
              onChanged: (value) => setState(() => _status = value),
            ),
          ],
          actions: const [],
          activeFilterCount:
              [_year, _status].where((v) => v != null).length +
              (query.isEmpty ? 0 : 1),
          onReset: () => setState(() {
            _search.clear();
            _year = null;
            _status = null;
          }),
        ),
        const SizedBox(height: 20),
        if (values.isEmpty)
          const EmptyArchivesState(
            label: 'Aucun projet ne correspond à ces filtres.',
          ),
        ResponsiveArchiveGrid(
          children: [
            for (final item in values)
              HistoricalProjectCard(
                item: item,
                gateway: widget.gateway,
                canEdit: widget.home.permissions.canCreate,
                onChanged: widget.onChanged,
              ),
          ],
        ),
      ],
    );
  }
}

class HistoricalProjectCard extends StatelessWidget {
  final HistoricalProjectModel item;
  final ArchivesGateway gateway;
  final bool canEdit;
  final VoidCallback? onChanged;
  const HistoricalProjectCard({
    super.key,
    required this.item,
    this.onChanged,
    required this.gateway,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) => RecordCard(
    title: item.name,
    eyebrow: '${item.periodLabel} · ${item.statusLabel}',
    imageAsset: item.imageAsset,
    sourceUrl: item.sourceUrl,
    sourceLabel: item.sourceLabel,
    description: item.description,
    memoryOnly: !item.isPersisted,
    onOpen: () => context.push('/archives/projects/${item.id}', extra: gateway),
    openLabel: 'Ouvrir le projet',
    onEdit: canEdit && item.isPersisted
        ? () => _refreshAfterWrite(
            showHistoricalProjectDialog(context, gateway, item: item),
            onChanged,
          )
        : null,
  );
}

class HallOfFameCenter extends StatefulWidget {
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  final VoidCallback? onChanged;
  const HallOfFameCenter({
    super.key,
    required this.home,
    this.onChanged,
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
    final query = searchableText(_search.text);
    final years =
        widget.home.hallOfFame
            .map((item) => item.year)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final hasUndatedEntries = widget.home.hallOfFame.any(
      (item) => item.year == null,
    );
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
              searchableText(
                '${item.title} ${item.subtitle ?? ''} ${item.description ?? ''} ${item.sourceLabel ?? ''}',
              ).contains(query)) &&
          (_year == null || (item.year ?? -1) == _year) &&
          (_type == null || item.entryType == _type) &&
          (!_featured || item.isFeatured),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArchiveBanner(
          eyebrow: 'HALL OF FAME',
          title: 'Les moments qui restent',
          description: 'Les moments qui ont marqué l’histoire d’Enactus ESP.',
          motif: ArchiveMotif.award,
          actions: widget.home.permissions.canCreate
              ? FilledButton.icon(
                  key: const Key('new_hall_of_fame_button'),
                  onPressed: () => _refreshAfterWrite(
                    showHallOfFameDialog(context, widget.gateway),
                    widget.onChanged,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle entrée Hall of Fame'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        AppFilterToolbar(
          search: SearchField(controller: _search),
          quickFilters: [
            FilterChip(
              label: const Text('Mis en avant'),
              selected: _featured,
              onSelected: (value) => setState(() => _featured = value),
            ),
          ],
          filters: [
            FilterDropdown<int>(
              label: 'Année',
              value: _year,
              values: [...years, if (hasUndatedEntries) -1],
              itemLabel: (year) => year == -1 ? 'Non renseignée' : '$year',
              onChanged: (value) => setState(() => _year = value),
            ),
            FilterDropdown<String>(
              label: 'Type',
              value: _type,
              values: types,
              itemLabel: hallOfFameEntryTypeLabel,
              onChanged: (value) => setState(() => _type = value),
            ),
          ],
          actions: const [],
          activeFilterCount:
              [_year, _type].where((v) => v != null).length +
              (_featured ? 1 : 0) +
              (query.isEmpty ? 0 : 1),
          onReset: () => setState(() {
            _search.clear();
            _year = null;
            _type = null;
            _featured = false;
          }),
        ),
        const SizedBox(height: 20),
        if (values.isEmpty)
          const EmptyArchivesState(
            label: 'Aucune entrée ne correspond à ces filtres.',
          ),
        ResponsiveArchiveGrid(
          children: [
            for (final item in values)
              HallOfFameCard(
                item: item,
                gateway: widget.gateway,
                canEdit: widget.home.permissions.canCreate,
                onChanged: widget.onChanged,
              ),
          ],
        ),
      ],
    );
  }
}

class HallOfFameCard extends StatelessWidget {
  final HallOfFameEntryModel item;
  final ArchivesGateway gateway;
  final bool canEdit;
  final VoidCallback? onChanged;
  const HallOfFameCard({
    super.key,
    required this.item,
    this.onChanged,
    required this.gateway,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) => RecordCard(
    title: item.title,
    eyebrow: '${item.year ?? 'Année non renseignée'} · ${item.entryTypeLabel}',
    imageAsset: item.imageAsset,
    sourceUrl: item.sourceUrl ?? item.externalUrl,
    sourceLabel: item.sourceLabel,
    description: item.subtitle ?? item.description,
    featured: item.isFeatured,
    memoryOnly: !item.isPersisted,
    badges: item.scoreValue == null
        ? const []
        : ['${item.scoreValue} ${item.scoreLabel ?? ''}'.trim()],
    onOpen: () =>
        context.push('/archives/hall-of-fame/${item.id}', extra: gateway),
    openLabel: 'Ouvrir le Hall of Fame',
    onEdit: canEdit && item.isPersisted
        ? () => _refreshAfterWrite(
            showHallOfFameDialog(context, gateway, item: item),
            onChanged,
          )
        : null,
  );
}

class HistoricalStatisticsCenter extends StatelessWidget {
  final List<HistoricalStatisticModel> statistics;
  final ArchivePermissions permissions;
  final ArchivesGateway gateway;
  final VoidCallback? onChanged;
  const HistoricalStatisticsCenter({
    super.key,
    required this.statistics,
    required this.permissions,
    this.onChanged,
    required this.gateway,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const ArchiveBanner(
        eyebrow: 'IMPACT HISTORIQUE',
        title: 'Chiffres et provenance',
        motif: ArchiveMotif.binder,
        description:
            'Retrouvez les principaux résultats du club au fil des années.',
      ),
      const SizedBox(height: 18),
      HistoricalStatisticsWrap(
        statistics: statistics,
        showStatus: true,
        onEdit: permissions.canValidate
            ? (item) => _refreshAfterWrite(
                showHistoricalStatisticDialog(context, gateway, item),
                onChanged,
              )
            : null,
      ),
    ],
  );
}

class ArchiveMediaCenter extends StatefulWidget {
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  final VoidCallback? onChanged;
  const ArchiveMediaCenter({
    super.key,
    required this.home,
    this.onChanged,
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
    final query = searchableText(_search.text);
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
              searchableText(
                '${item.title} ${item.description ?? ''} ${item.sourceLabel ?? ''}',
              ).contains(query)) &&
          (_year == null || item.year == _year) &&
          (_type == null || item.mediaType == _type) &&
          (_projectId == null || item.projectId == _projectId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArchiveBanner(
          eyebrow: 'MÉMOIRE COLLECTIVE',
          title: 'Médias historiques',
          description: 'Photos, vidéos, presse et présentations historiques.',
          motif: ArchiveMotif.media,
          actions: widget.home.permissions.canCreate
              ? FilledButton.icon(
                  onPressed: () => _refreshAfterWrite(
                    showMediaDialog(context, widget.gateway),
                    widget.onChanged,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau média'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        AppFilterToolbar(
          search: SearchField(controller: _search),
          quickFilters: const [],
          filters: [
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
          actions: const [],
          activeFilterCount:
              [_year, _type, _projectId].where((v) => v != null).length +
              (query.isEmpty ? 0 : 1),
          onReset: () => setState(() {
            _search.clear();
            _year = null;
            _type = null;
            _projectId = null;
          }),
        ),
        const SizedBox(height: 20),
        if (values.isEmpty)
          const EmptyArchivesState(
            label: 'Aucun média ne correspond à ces filtres.',
          )
        else
          ResponsiveArchiveGrid(
            children: [
              for (final item in values)
                ArchiveMediaCard(
                  item: item,
                  gateway: widget.gateway,
                  canEdit: widget.home.permissions.canCreate,
                  onChanged: widget.onChanged,
                ),
            ],
          ),
      ],
    );
  }
}

class ArchivesCollectionCenter extends StatelessWidget {
  final String sectionLabel;
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  final VoidCallback? onChanged;
  const ArchivesCollectionCenter({
    super.key,
    required this.sectionLabel,
    required this.home,
    this.onChanged,
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
          onOpen: () =>
              context.push('/archives/awards/${item.id}', extra: gateway),
          openLabel: 'Découvrir la distinction',
          description: item.description,
          imageAsset: item.imageAsset,
          motif: ArchiveMotif.award,
          sourceUrl: item.sourceUrl,
          sourceLabel: item.sourceLabel,
          featured: item.isFeatured,
          memoryOnly: !item.isPersisted,
          onEdit: home.permissions.canCreate && item.isPersisted
              ? () => _refreshAfterWrite(
                  showAwardDialog(context, gateway, item: item),
                  onChanged,
                )
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
          onOpen: () =>
              context.push('/archives/competitions/${item.id}', extra: gateway),
          openLabel: 'Découvrir le concours',
          description: item.description,
          imageAsset: item.imageAsset,
          motif: ArchiveMotif.award,
          sourceUrl: item.sourceUrl,
          sourceLabel: item.sourceLabel,
          featured: item.isFeatured,
          memoryOnly: !item.isPersisted,
          onEdit: home.permissions.canCreate && item.isPersisted
              ? () => _refreshAfterWrite(
                  showCompetitionDialog(context, gateway, item: item),
                  onChanged,
                )
              : null,
        ),
      ),
      'Médias' => home.media.map(
        (item) => ArchiveMediaCard(
          item: item,
          gateway: gateway,
          canEdit: home.permissions.canCreate,
          onChanged: onChanged,
        ),
      ),
      'Documents' => home.documents.map(
        (item) => ArchiveDocumentCard(
          item: item,
          gateway: gateway,
          canEdit: home.permissions.canCreate,
          onChanged: onChanged,
        ),
      ),
      _ => const Iterable<RecordCard>.empty(),
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArchiveBanner(
          eyebrow: 'MÉMOIRE COLLECTIVE',
          title: sectionLabel,
          description: _description,
          motif: switch (sectionLabel) {
            'Palmarès' || 'Compétitions' => ArchiveMotif.award,
            'Médias' => ArchiveMotif.media,
            _ => ArchiveMotif.binder,
          },
          actions: home.permissions.canCreate
              ? FilledButton.icon(
                  onPressed: () =>
                      _refreshAfterWrite(_create(context), onChanged),
                  icon: const Icon(Icons.add),
                  label: Text(switch (sectionLabel) {
                    'Palmarès' => 'Nouvelle distinction',
                    'Compétitions' => 'Nouvelle compétition',
                    'Documents' => 'Nouveau document historique',
                    _ => 'Nouveau média',
                  }),
                )
              : null,
        ),
        const SizedBox(height: 18),
        if (children.isEmpty)
          const EmptyArchivesState(label: 'Aucun contenu disponible.')
        else
          ResponsiveArchiveGrid(children: children),
      ],
    );
  }

  String get _description => switch (sectionLabel) {
    'Palmarès' =>
      'Les distinctions et résultats d’Enactus ESP au fil des années.',
    'Compétitions' =>
      'Les participations d’Enactus ESP aux compétitions nationales et internationales.',
    'Médias' => 'Photos, vidéos, presse et présentations historiques.',
    'Documents' =>
      'Une collection historique dédiée, distincte du module Documents.',
    _ => '',
  };

  Future<bool> _create(BuildContext context) => switch (sectionLabel) {
    'Palmarès' => showAwardDialog(context, gateway),
    'Compétitions' => showCompetitionDialog(context, gateway),
    'Médias' => showMediaDialog(context, gateway),
    'Documents' => showArchiveDocumentDialog(context, gateway),
    _ => Future.value(false),
  };
}

class ArchiveMediaCard extends StatelessWidget {
  final ArchiveMediaModel item;
  final ArchivesGateway gateway;
  final bool canEdit;
  final VoidCallback? onChanged;
  const ArchiveMediaCard({
    super.key,
    required this.item,
    this.onChanged,
    required this.gateway,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) => RecordCard(
    title: item.title,
    eyebrow: '${item.year ?? ''} · ${item.mediaTypeLabel}',
    imageAsset: item.imageAsset,
    motif: ArchiveMotif.media,
    placeholderLabel:
        item.fileId != null &&
            item.file?.downloadUrl == null &&
            item.file?.previewUrl == null
        ? 'Média indisponible'
        : null,
    attachment: item.file,
    sourceUrl: item.sourceUrl ?? item.externalUrl,
    sourceLabel: item.sourceLabel,
    description: item.description,
    featured: item.isFeatured,
    memoryOnly: !item.isPersisted,
    onOpen: item.mediaType == 'minute_enacteur'
        ? () => context.push('/archives/minutes/${item.id}', extra: gateway)
        : item.mediaType == 'recit'
        ? () => showDialog<void>(
            context: context,
            builder: (context) => Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(item.title),
                  leading: IconButton(
                    tooltip: 'Retour aux récits',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                body: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: ArchiveMinuteReading(item: item),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : null,
    openLabel: item.mediaType == 'minute_enacteur'
        ? 'Lire sa Minute'
        : item.mediaType == 'recit'
        ? 'Lire le récit'
        : item.externalUrl == null
        ? 'Ouvrir média'
        : 'Ouvrir',
    onEdit: canEdit && item.isPersisted
        ? () => _refreshAfterWrite(
            showMediaDialog(context, gateway, item: item),
            onChanged,
          )
        : null,
  );
}

class ArchiveDocumentCard extends StatelessWidget {
  final ArchiveDocumentModel item;
  final ArchivesGateway gateway;
  final bool canEdit;
  final VoidCallback? onChanged;
  const ArchiveDocumentCard({
    super.key,
    required this.item,
    this.onChanged,
    required this.gateway,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) => RecordCard(
    title: item.title,
    eyebrow:
        '${item.year ?? ''} · ${item.documentTypeLabel} · ${archiveVisibilityLabel(item.visibility)}',
    description: item.description,
    sourceLabel: item.sourceLabel,
    attachment: item.file,
    featured: item.isFeatured,
    memoryOnly: !item.isPersisted,
    onOpen: item.documentId == null
        ? null
        : () => context.push('/documents/${item.documentId}'),
    openLabel: 'Ouvrir document',
    onEdit: canEdit && item.isPersisted
        ? () => _refreshAfterWrite(
            showArchiveDocumentDialog(context, gateway, item: item),
            onChanged,
          )
        : null,
  );
}

Future<void> openArchiveUrl(BuildContext context, String? value) async {
  final resolved = value?.startsWith('/') == true
      ? '${ApiClient.serverUrl}$value'
      : value;
  final uri = resolved == null ? null : Uri.tryParse(resolved);
  if (uri == null ||
      !{'https', 'http'}.contains(uri.scheme) ||
      !await launchUrl(uri, webOnlyWindowName: '_blank')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun lien exploitable disponible.')),
      );
    }
  }
}

class RecordCard extends StatelessWidget {
  final String title;
  final String? imageAsset;
  final ArchiveMotif motif;
  final String? placeholderLabel;
  final ArchiveFileModel? attachment;
  final String? sourceUrl;
  final String? sourceLabel;
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
    this.imageAsset,
    this.motif = ArchiveMotif.binder,
    this.placeholderLabel,
    this.attachment,
    this.sourceUrl,
    this.sourceLabel,
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
  Widget build(BuildContext context) {
    final fileUrl = attachment?.downloadUrl ?? attachment?.previewUrl;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageAsset != null) ...[
              HeritageImage(asset: imageAsset!, title: title),
            ] else
              ArchivePlaceholder(motif: motif, label: placeholderLabel),
            const SizedBox(height: 14),
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
              Text(
                description!,
                maxLines: onOpen == null ? null : 4,
                overflow: onOpen == null
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (featured) const Chip(label: Text('Mis en avant')),

                for (final badge in badges) Chip(label: Text(badge)),
              ],
            ),
            if (sourceLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                'Source : $sourceLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onOpen != null ||
                onEdit != null ||
                sourceUrl != null ||
                fileUrl != null)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (fileUrl != null)
                      StoredAttachmentButton(
                        url: fileUrl,
                        fileName: attachment!.name,
                      ),
                    if (sourceUrl != null)
                      TextButton.icon(
                        onPressed: () => openArchiveUrl(context, sourceUrl),
                        icon: const Icon(Icons.link),
                        label: const Text('Consulter la source'),
                      ),
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
        ResponsiveArchiveGrid(children: children),
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
                            _historicalNumber(entry.value),
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
  final bool showStatus;
  final ValueChanged<HistoricalStatisticModel>? onEdit;
  const HistoricalStatisticsWrap({
    super.key,
    required this.statistics,
    this.showStatus = false,
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
                                : '${item.isMinimum ? 'Plus de ' : ''}${_historicalNumber(item.value!)} ${item.unit ?? ''}'
                                      .trim(),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),

                          if (item.description != null) Text(item.description!),
                          Text(
                            item.sourceLabel == null
                                ? 'Source non renseignée'
                                : 'Source : ${item.sourceLabel}',
                          ),
                          if (showStatus) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.confidenceLabel,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],

                          if (onEdit != null &&
                              !(item.isPersisted && item.isValidated))
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

String _historicalNumber(num value) => NumberFormat(
  '#,##0.########',
  'fr_FR',
).format(value).replaceAll(RegExp('[\u00a0\u202f]'), ' ');

String _impactSummaryLabel(String key) {
  const labels = {
    'lives_impacted': 'Vies impactées',
    'jobs_created': 'Emplois créés',
    'people_trained': 'Personnes formées',
    'products_developed': 'Produits développés',
    'work_hours': 'Heures de travail investies',
    'sdgs_touched': 'ODD touchés',
    'revenue_usd_2021_2022': 'Revenus 2021–2022 (USD)',
    'beneficiary_income_increase_pct':
        'Hausse des revenus des bénéficiaires (%)',
    'trees_planted': 'Arbres plantés',
    'field_kilometers': 'Kilomètres parcourus sur le terrain',
    'created_projects': 'Projets créés',
    'developing_projects': 'Projets en développement',
    'developed_products': 'Produits développés',
    'touched_sdgs': 'ODD concernés',
    'created_jobs': 'Emplois créés',
    'saved_lives': 'Vies préservées',
    'planted_trees': 'Arbres plantés',
    'cumulative_fcfa_gains': 'Gains cumulés',
    'impacted_lives': 'Vies touchées',
  };
  final known = labels[key];
  if (known != null) return known;
  final words = key.split('_').where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return 'Indicateur historique';
  final text = words.join(' ');
  return '${text[0].toUpperCase()}${text.substring(1)}';
}
