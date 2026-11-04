import 'dart:math';

import 'package:flutter/material.dart';
import 'package:frontend/shared/ui/app_filter_toolbar.dart';

import 'package:go_router/go_router.dart';

import '../../../core/text/searchable_text.dart';
import '../../../shared/ui/project_photo_gallery.dart';
import '../../../shared/ui/reading_blocks.dart';
import '../models/archive_models.dart';
import '../services/archives_gateway.dart';
import 'archive_visuals.dart';

class ArchiveMinutesScreen extends StatefulWidget {
  final String? minuteId;
  final ArchivesGateway? gateway;
  final String? search;
  final String? theme;
  const ArchiveMinutesScreen({
    super.key,
    this.minuteId,
    this.gateway,
    this.search,
    this.theme,
  });
  @override
  State<ArchiveMinutesScreen> createState() => _ArchiveMinutesScreenState();
}

class _ArchiveMinutesScreenState extends State<ArchiveMinutesScreen> {
  late final ArchivesGateway gateway = widget.gateway ?? ApiArchivesGateway();
  late Future<ArchivesHomeData> home = gateway.loadHome();
  @override
  Widget build(BuildContext context) => ArchiveTheme(
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Minute de l’enacteur'),
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/archives'),
        ),
      ),
      body: FutureBuilder<ArchivesHomeData>(
        future: home,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    home = gateway.loadHome();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final all = data.media.where(
            (item) => item.mediaType == 'minute_enacteur',
          );
          final minute = all
              .where((item) => item.id == widget.minuteId)
              .firstOrNull;
          final alternatives = all
              .where(
                (item) =>
                    item.id != widget.minuteId &&
                    _matchesMinute(item, widget.search, widget.theme),
              )
              .toList();
          return LayoutBuilder(
            builder: (context, constraints) => ListView(
              key: ValueKey(widget.minuteId),
              padding: EdgeInsets.symmetric(
                vertical: 24,
                horizontal: constraints.maxWidth > 1100
                    ? (constraints.maxWidth - 1040) / 2
                    : 16,
              ),
              children: [
                widget.minuteId == null
                    ? ArchiveMinutesCollection(home: data, gateway: gateway)
                    : minute == null
                    ? const Text('Cette Minute n’est pas disponible.')
                    : ArchiveMinuteReading(
                        item: minute,
                        onNext: alternatives.isEmpty
                            ? null
                            : () {
                                final next =
                                    alternatives[Random().nextInt(
                                      alternatives.length,
                                    )];
                                context.replace(
                                  _minuteLocation(
                                    next,
                                    widget.search,
                                    widget.theme,
                                  ),
                                  extra: gateway,
                                );
                              },
                      ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

bool _matchesMinute(ArchiveMediaModel item, String? search, String? theme) =>
    (theme == null || theme == item.theme) &&
    searchableText(
      '${item.title} ${item.speaker ?? ''} ${item.theme ?? ''} ${item.description ?? ''} ${item.year ?? ''}',
    ).contains(searchableText(search ?? ''));

String _minuteLocation(ArchiveMediaModel item, String? search, String? theme) =>
    Uri(
      pathSegments: ['', 'archives', 'minutes', item.id],
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'theme': ?theme,
      },
    ).toString();

class ArchiveMinutesCollection extends StatefulWidget {
  final ArchivesHomeData home;
  final ArchivesGateway gateway;
  const ArchiveMinutesCollection({
    super.key,
    required this.home,
    required this.gateway,
  });
  @override
  State<ArchiveMinutesCollection> createState() =>
      _ArchiveMinutesCollectionState();
}

class _ArchiveMinutesCollectionState extends State<ArchiveMinutesCollection> {
  final _search = TextEditingController();
  String? theme;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(ArchiveMediaModel item) => context.push(
    _minuteLocation(item, _search.text, theme),
    extra: widget.gateway,
  );
  @override
  Widget build(BuildContext context) {
    final all = widget.home.media
        .where((m) => m.mediaType == 'minute_enacteur')
        .toList();
    final themes = all.map((m) => m.theme).whereType<String>().toSet().toList()
      ..sort();
    final visible = all
        .where((item) => _matchesMinute(item, _search.text, theme))
        .toList();
    final filtered = _search.text.trim().isNotEmpty || theme != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveBanner(
          eyebrow: 'MINUTE DE L’ENACTEUR',
          title: 'Une minute. Une voix. De quoi avancer.',
          description:
              'À la fin de nos réunions, un enacteur ou une enactrice prend la parole : une réflexion, un conseil, un bout de son expérience. Ce petit rituel fait vivre les liens et transmet ce qui nous anime, au-delà des projets.',
          motif: ArchiveMotif.minute,
          actions: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(label: Text('${all.length} voix à découvrir')),
              if (filtered) Chip(label: Text('${visible.length} résultat(s)')),
              FilledButton.icon(
                onPressed: visible.isEmpty
                    ? null
                    : () => _open(visible[Random().nextInt(visible.length)]),
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Surprends-moi !'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppFilterToolbar(
          search: TextField(
            key: const Key('minute_search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Une personne, un thème, une année…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          quickFilters: [
            ChoiceChip(
              label: const Text('Toutes les voix'),
              selected: theme == null,
              onSelected: (_) => setState(() => theme = null),
            ),
            for (final value in themes)
              ChoiceChip(
                label: Text(value),
                selected: theme == value,
                onSelected: (_) => setState(() => theme = value),
              ),
          ],
          filters: const [],
          actions: const [],
          activeFilterCount: filtered ? 1 : 0,
          onReset: () => setState(() {
            _search.clear();
            theme = null;
          }),
        ),
        const SizedBox(height: 24),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Aucune Minute pour cette recherche. Essaie un autre mot ou un autre thème.',
            ),
          ),
        ResponsiveArchiveGrid(
          children: [
            for (final item in visible)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.theme ?? 'Une voix du club',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        [
                          item.speaker,
                          if (item.year != null) '${item.year}',
                        ].whereType<String>().join(' · '),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item.quote ?? item.description ?? '',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => _open(item),
                        icon: const Icon(Icons.auto_stories_outlined),
                        label: const Text('Lire sa Minute'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class ArchiveMinuteReading extends StatelessWidget {
  final ArchiveMediaModel item;
  final VoidCallback? onNext;
  const ArchiveMinuteReading({super.key, required this.item, this.onNext});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (item.theme != null) Chip(label: Text(item.theme!)),
            if (item.spokenOn != null)
              Chip(label: Text(item.spokenOn!.split('-').reversed.join('/')))
            else if (item.year != null)
              Chip(label: Text('${item.year}')),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          item.title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (item.speaker != null)
          Text(item.speaker!, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        if (item.imageAsset != null) ...[
          HeritageImage(asset: item.imageAsset!, title: item.title),
          const SizedBox(height: 24),
        ],
        if (item.quote != null) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SelectableText(
              '« ${item.quote} »',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                height: 1.5,
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        ReadingBlocks(item.description ?? ''),
        if (item.gallery.isNotEmpty) ...[
          const SizedBox(height: 24),
          ProjectPhotoGallery(photos: item.gallery),
        ],
        if (item.originalText != null)
          ExpansionTile(
            title: const Text('Lire les extraits conservés'),
            childrenPadding: const EdgeInsets.all(16),
            children: [ReadingBlocks(item.originalText!)],
          ),
        const SizedBox(height: 24),
        if (item.challenge != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ReadingBlocks('À toi de jouer\n${item.challenge}'),
          ),
        if (item.editorialNote != null)
          Text(
            item.editorialNote!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        const SizedBox(height: 12),
        Text(
          item.sourceLabel == null
              ? 'Source non renseignée'
              : 'Source : ${item.sourceLabel}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        if (onNext != null)
          OutlinedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Une autre voix'),
          ),
      ],
    );
  }
}
