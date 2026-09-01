import 'package:flutter/material.dart';

import '../models/archive_models.dart';
import '../services/archives_gateway.dart';
import 'archive_forms.dart';
import 'archives_center_sections.dart';

enum ArchivesSection {
  overview('Vue d’ensemble'),
  items('Archives'),
  projects('Projets historiques'),
  awards('Palmarès'),
  competitions('Compétitions'),
  media('Médias'),
  documents('Documents'),
  hallOfFame('Hall of Fame'),
  statistics('Statistiques');

  final String label;
  const ArchivesSection(this.label);
}

class ArchivesScreen extends StatefulWidget {
  final ArchivesGateway? gateway;
  const ArchivesScreen({super.key, this.gateway});

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  late final ArchivesGateway _gateway;
  final _search = TextEditingController();
  ArchivesHomeData? _home;
  List<ArchiveItemModel> _items = const [];
  Object? _error;
  bool _loading = true;
  ArchivesSection _section = ArchivesSection.overview;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiArchivesGateway();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<Object>([
        _gateway.loadHome(),
        _gateway.getItems(),
      ]);
      if (!mounted) return;
      setState(() {
        _home = values[0] as ArchivesHomeData;
        _items = values[1] as List<ArchiveItemModel>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
      children: [
        _ArchivesHeader(
          permissions: _home?.permissions ?? const ArchivePermissions(),
          onCreate: _createArchive,
          onExport: _export,
        ),
        const SizedBox(height: 18),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(56),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          _ErrorState(error: _error!, onRetry: _load)
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final section in ArchivesSection.values)
                ChoiceChip(
                  label: Text(section.label),
                  selected: _section == section,
                  onSelected: (_) => setState(() => _section = section),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionBody(),
        ],
      ],
    ),
  );

  Widget _sectionBody() => switch (_section) {
    ArchivesSection.overview => ArchivesOverview(
      home: _home!,
      gateway: _gateway,
    ),
    ArchivesSection.items => ArchiveItemsCenter(
      items: _items,
      gateway: _gateway,
      permissions: _home!.permissions,
    ),
    ArchivesSection.projects => HistoricalProjectsCenter(
      home: _home!,
      gateway: _gateway,
    ),
    ArchivesSection.media => ArchiveMediaCenter(
      home: _home!,
      gateway: _gateway,
    ),
    ArchivesSection.hallOfFame => HallOfFameCenter(
      home: _home!,
      gateway: _gateway,
    ),
    ArchivesSection.statistics => HistoricalStatisticsCenter(
      statistics: _home!.statistics,
      permissions: _home!.permissions,
      gateway: _gateway,
    ),
    _ => ArchivesCollectionCenter(
      sectionLabel: _section.label,
      home: _home!,
      gateway: _gateway,
    ),
  };

  Future<void> _createArchive() async {
    await showArchiveItemDialog(context, _gateway);
    await _load();
  }

  Future<void> _export() async {
    try {
      await _gateway.exportItemsCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export des archives préparé.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _ArchivesHeader extends StatelessWidget {
  final ArchivePermissions permissions;
  final VoidCallback onCreate;
  final VoidCallback onExport;
  const _ArchivesHeader({
    required this.permissions,
    required this.onCreate,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 16,
        spacing: 24,
        children: [
          const SizedBox(
            width: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archives & mémoire collective',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  'Les projets, les personnes et les moments qui ont construit Enactus ESP.',
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              if (permissions.canExport)
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exporter les archives'),
                ),
              if (permissions.canCreate)
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle archive'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('Impossible de charger la mémoire collective.'),
          Text('$error'),
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
