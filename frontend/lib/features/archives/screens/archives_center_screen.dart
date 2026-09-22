import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../models/archive_contract_models.dart';
import '../models/archive_models.dart';
import '../models/memory_timeline_models.dart';
import '../services/archives_gateway.dart';
import 'archives_center_sections.dart';

class ArchivesScreen extends StatefulWidget {
  final ArchivesGateway? gateway;
  final MemoryTimelineFilters initialFilters;

  const ArchivesScreen({
    super.key,
    this.gateway,
    this.initialFilters = const MemoryTimelineFilters(),
  });

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  late final ArchivesGateway _gateway;
  late MemoryTimelineFilters _filters;
  late final TextEditingController _search;
  ArchivePermissions _permissions = const ArchivePermissions();
  List<MemoryTimelineItem> _items = const [];
  String? _nextCursor;
  Object? _initialError;
  Object? _moreError;
  bool _loading = true;
  bool _loadingMore = false;
  bool _legacyMode = false;
  Future<ArchivesHomeData>? _legacyHome;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiArchivesGateway();
    _filters = widget.initialFilters;
    _search = TextEditingController(text: _filters.search);
    _loadInitial();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _initialError = null;
      _moreError = null;
    });
    try {
      final permissions = await _gateway.getPermissions();
      final effectiveFilters = permissions.canValidate
          ? _filters
          : _filters.copyWith(review: false);
      final page = await _gateway.getTimeline(filters: effectiveFilters);
      if (!mounted) return;
      setState(() {
        _permissions = permissions;
        _filters = effectiveFilters;
        _items = page.items;
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted) setState(() => _initialError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (_loadingMore || cursor == null || _legacyMode) return;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final page = await _gateway.getTimeline(
        filters: _filters,
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        final known = _items.map((item) => item.id).toSet();
        _items = [..._items, ...page.items.where((item) => known.add(item.id))];
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted) setState(() => _moreError = error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _applySearch(String value) {
    _filters = _filters.copyWith(search: value.trim());
    _loadInitial();
  }

  void _setReview(bool value) {
    _filters = _filters.copyWith(review: value);
    _loadInitial();
  }

  Future<void> _showFilters() async {
    final start = TextEditingController(text: _filters.startYear?.toString());
    final end = TextEditingController(text: _filters.endYear?.toString());
    var selectedType = _filters.resourceType;
    final result = await showDialog<MemoryTimelineFilters>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filtrer la mémoire'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('memory_start_year'),
                  controller: start,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Année de début',
                  ),
                ),
                TextField(
                  key: const Key('memory_end_year'),
                  controller: end,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Année de fin'),
                ),
                DropdownButtonFormField<String?>(
                  key: const Key('memory_resource_type'),
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type de repère',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Tous les types'),
                    ),
                    DropdownMenuItem(
                      value: 'institutional_event',
                      child: Text('Événement institutionnel'),
                    ),
                    DropdownMenuItem(
                      value: 'leadership_term',
                      child: Text('Mandat'),
                    ),
                    DropdownMenuItem(
                      value: 'project_year',
                      child: Text('Année de projet'),
                    ),
                    DropdownMenuItem(
                      value: 'project_relationship',
                      child: Text('Évolution de projet'),
                    ),
                    DropdownMenuItem(
                      value: 'competition',
                      child: Text('Compétition'),
                    ),
                    DropdownMenuItem(
                      value: 'award',
                      child: Text('Distinction'),
                    ),
                    DropdownMenuItem(value: 'framework', child: Text('Cadre')),
                    DropdownMenuItem(
                      value: 'generation',
                      child: Text('Génération'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedType = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                MemoryTimelineFilters(
                  projectId: _filters.projectId,
                  poleId: _filters.poleId,
                  memberId: _filters.memberId,
                  eventId: _filters.eventId,
                  search: _filters.search,
                  review: _filters.review,
                ),
              ),
              child: const Text('Effacer'),
            ),
            FilledButton(
              key: const Key('memory_apply_filters'),
              onPressed: () => Navigator.pop(
                context,
                MemoryTimelineFilters(
                  startYear: int.tryParse(start.text.trim()),
                  endYear: int.tryParse(end.text.trim()),
                  resourceType: selectedType,
                  projectId: _filters.projectId,
                  poleId: _filters.poleId,
                  memberId: _filters.memberId,
                  eventId: _filters.eventId,
                  search: _filters.search,
                  review: _filters.review,
                ),
              ),
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
    start.dispose();
    end.dispose();
    if (result == null || !mounted) return;
    _filters = result;
    await _loadInitial();
  }

  void _showLegacy() {
    setState(() {
      _legacyMode = true;
      _legacyHome ??= _gateway.loadHome();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: _legacyMode ? _buildLegacy() : _buildTimeline()),
  );

  Widget _buildTimeline() => RefreshIndicator(
    onRefresh: _loadInitial,
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 360) _loadMore();
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
              20,
              MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _header()),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_initialError != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _MemoryError(onRetry: _loadInitial),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _MemoryEmpty(filtered: _filters.isFiltered),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                18,
                MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                32,
              ),
              sliver: SliverList.builder(
                itemCount: _items.length + 1,
                itemBuilder: (context, index) {
                  if (index < _items.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MemoryTimelineCard(
                        item: _items[index],
                        onOpen: () => _openDetail(_items[index]),
                        onOpenSource: _items[index].source?.capability == null
                            ? null
                            : () => _openSource(
                                _items[index].source!.capability!,
                              ),
                      ),
                    );
                  }
                  if (_loadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_moreError != null) {
                    return Center(
                      child: OutlinedButton.icon(
                        key: const Key('memory_retry_more'),
                        onPressed: _loadMore,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer le chargement'),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
        ],
      ),
    ),
  );

  Widget _header() => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mémoire Enactus ESP',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Une chronologie institutionnelle vérifiée, reliée à ses sources.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('archives_search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: _applySearch,
            decoration: InputDecoration(
              hintText: 'Rechercher dans la mémoire',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Effacer la recherche',
                onPressed: () {
                  _search.clear();
                  _applySearch('');
                },
                icon: const Icon(Icons.clear),
              ),
              filled: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_filters.isFiltered)
                const Chip(
                  avatar: Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text('Vue filtrée'),
                ),
              if (_permissions.canValidate)
                FilterChip(
                  key: const Key('memory_review_mode'),
                  selected: _filters.review,
                  onSelected: _setReview,
                  label: const Text('Mode révision'),
                ),
              OutlinedButton.icon(
                key: const Key('memory_filters'),
                onPressed: _showFilters,
                icon: const Icon(Icons.tune),
                label: const Text('Filtres'),
              ),
              if (_permissions.canValidate)
                OutlinedButton.icon(
                  key: const Key('memory_legacy_area'),
                  onPressed: _showLegacy,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Archives héritées à vérifier'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildLegacy() => FutureBuilder<ArchivesHomeData>(
    future: _legacyHome,
    builder: (context, snapshot) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _legacyMode = false),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Retour à la mémoire vérifiée',
            ),
            const Expanded(
              child: Text(
                'Archives héritées à vérifier',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const Text(
          'Contenu de compatibilité distinct de la mémoire institutionnelle vérifiée.',
        ),
        const SizedBox(height: 20),
        if (snapshot.connectionState == ConnectionState.waiting)
          const Center(child: CircularProgressIndicator())
        else if (snapshot.hasError)
          _MemoryError(
            onRetry: () => setState(() => _legacyHome = _gateway.loadHome()),
          )
        else
          ArchivesOverview(home: snapshot.requireData, gateway: _gateway),
      ],
    ),
  );

  Future<void> _openDetail(MemoryTimelineItem item) async {
    try {
      final detail = await _gateway.getTimelineDetail(
        item.resourceType,
        item.id,
        review: _filters.review,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _MemoryDetail(item: detail),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce repère n’est plus accessible.')),
      );
    }
  }

  Future<void> _openSource(MemorySourceCapability capability) async {
    if (capability.type == 'document') {
      final id = capability.url.split('/').last;
      context.go('/documents/$id');
      return;
    }
    if (capability.type == 'stored_file') {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Source non accessible')));
      return;
    }
    final raw = capability.url.startsWith('/')
        ? '${ApiClient.serverUrl}${capability.url}'
        : capability.url;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Source non accessible')));
    }
  }
}

class _MemoryTimelineCard extends StatelessWidget {
  final MemoryTimelineItem item;
  final VoidCallback onOpen;
  final VoidCallback? onOpenSource;

  const _MemoryTimelineCard({
    required this.item,
    required this.onOpen,
    this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(item.trustLabel)),
                Chip(label: Text(item.originLabel)),
                Chip(label: Text(item.dateLabel)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (item.summary != null) ...[
              const SizedBox(height: 6),
              Text(item.summary!, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (item.relatedEntities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                item.relatedEntities.map((entity) => entity.label).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            if (item.source == null)
              const Text('Source non accessible')
            else if (onOpenSource == null)
              Text('${item.source!.label} · Source non accessible')
            else
              TextButton.icon(
                onPressed: onOpenSource,
                icon: const Icon(Icons.open_in_new),
                label: Text('Ouvrir la source · ${item.source!.label}'),
              ),
            if (item.hasUnavailableRelation)
              const Text('Élément source indisponible'),
          ],
        ),
      ),
    ),
  );
}

class _MemoryDetail extends StatelessWidget {
  final MemoryTimelineItem item;
  const _MemoryDetail({required this.item});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('${item.trustLabel} · ${item.originLabel} · ${item.dateLabel}'),
          if (item.summary != null) ...[
            const SizedBox(height: 16),
            Text(item.summary!),
          ],
          if (item.source != null) ...[
            const SizedBox(height: 16),
            Text('Source : ${item.source!.label} (${item.source!.type})'),
          ],
          if (item.capturedAt != null || item.createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              item.capturedAt != null
                  ? 'Capture : ${item.capturedAt!.toLocal()}'
                  : 'Création : ${item.createdAt!.toLocal()}',
            ),
          ],
          if (item.updatedAt != null) ...[
            const SizedBox(height: 8),
            Text('Mise à jour : ${item.updatedAt!.toLocal()}'),
          ],
          if (item.validatedAt != null) ...[
            const SizedBox(height: 8),
            Text('Validation : ${item.validatedAt!.toLocal()}'),
          ],
          if (item.hasUnavailableRelation) ...[
            const SizedBox(height: 12),
            const Text('Élément source indisponible'),
          ],
        ],
      ),
    ),
  );
}

class _MemoryEmpty extends StatelessWidget {
  final bool filtered;
  const _MemoryEmpty({required this.filtered});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        filtered
            ? 'Aucun repère ne correspond à ces filtres.'
            : 'Aucun repère institutionnel vérifié pour le moment.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _MemoryError extends StatelessWidget {
  final VoidCallback onRetry;
  const _MemoryError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('Impossible de charger la mémoire institutionnelle.'),
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
