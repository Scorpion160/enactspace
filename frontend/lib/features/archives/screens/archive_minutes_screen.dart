import '../../../shared/ui/project_photo_gallery.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/ui/reading_blocks.dart';
import '../models/archive_models.dart';
import '../services/archives_gateway.dart';
import 'archive_visuals.dart';

class ArchiveMinutesScreen extends StatefulWidget {
  final String? minuteId;
  final ArchivesGateway? gateway;
  const ArchiveMinutesScreen({super.key, this.minuteId, this.gateway});
  @override
  State<ArchiveMinutesScreen> createState() => _ArchiveMinutesScreenState();
}

class _ArchiveMinutesScreenState extends State<ArchiveMinutesScreen> {
  late final ArchivesGateway gateway = widget.gateway ?? ApiArchivesGateway();
  late Future<ArchivesHomeData> home = gateway.loadHome();
  @override
  Widget build(BuildContext context) => Scaffold(
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
              onPressed: () => setState(() => home = gateway.loadHome()),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final matches = data.media.where((m) => m.id == widget.minuteId);
        return LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: EdgeInsets.symmetric(
              vertical: 24,
              horizontal: constraints.maxWidth > 1100
                  ? (constraints.maxWidth - 1040) / 2
                  : 16,
            ),
            children: [
              widget.minuteId == null
                  ? ArchiveMinutesCollection(home: data, gateway: gateway)
                  : matches.isEmpty
                  ? const Text('Cette Minute n’est pas disponible.')
                  : ArchiveMinuteReading(
                      item: matches.first,
                      onNext: () {
                        final minutes = data.media
                            .where((m) => m.mediaType == 'minute_enacteur')
                            .toList();
                        final next =
                            minutes[(minutes.indexOf(matches.first) + 1) %
                                minutes.length];
                        context.replace(
                          '/archives/minutes/${next.id}',
                          extra: gateway,
                        );
                      },
                    ),
            ],
          ),
        );
      },
    ),
  );
}

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
  String search = '';
  String? theme;
  @override
  Widget build(BuildContext context) {
    final all = widget.home.media
        .where((m) => m.mediaType == 'minute_enacteur')
        .toList();
    final themes = all.map((m) => m.theme).whereType<String>().toSet().toList()
      ..sort();
    final visible = all
        .where(
          (m) =>
              (theme == null || m.theme == theme) &&
              '${m.title} ${m.speaker ?? ''} ${m.theme ?? ''} ${m.description ?? ''} ${m.year ?? ''}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.record_voice_over_rounded,
          size: 44,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Une minute. Une voix. De quoi avancer.',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        const Text(
          'À la fin de nos réunions, un enacteur ou une enactrice prend la parole : une réflexion, un conseil, un bout de son expérience. Ce petit rituel fait vivre les liens et transmet ce qui nous anime, au-delà des projets.',
          style: TextStyle(height: 1.6),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text('${all.length} voix à découvrir')),
            FilledButton.icon(
              onPressed: all.isEmpty
                  ? null
                  : () {
                      final pool = visible.isEmpty ? all : visible;
                      context.push(
                        '/archives/minutes/${pool[Random().nextInt(pool.length)].id}',
                        extra: widget.gateway,
                      );
                    },
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Surprends-moi !'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('minute_search'),
          onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(
            labelText: 'Une personne, un thème, une année…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
                        onPressed: () => context.push(
                          '/archives/minutes/${item.id}',
                          extra: widget.gateway,
                        ),
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
        Text(item.speaker ?? '', style: Theme.of(context).textTheme.titleLarge),
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
          ReadingBlocks('À toi de jouer\n${item.challenge}'),
        if (item.editorialNote != null)
          Text(
            item.editorialNote!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        const SizedBox(height: 12),
        Text(
          'Source : ${item.sourceLabel ?? 'Archives Enactus ESP'}',
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
