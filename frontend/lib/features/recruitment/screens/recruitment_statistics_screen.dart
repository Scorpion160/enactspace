import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/recruitment_message.dart';
import '../services/recruitment_service.dart';
import '../widgets/recruitment_workspace.dart';

class RecruitmentStatisticsScreen extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(String? campaignId)? loader;
  const RecruitmentStatisticsScreen({super.key, this.loader});

  @override
  State<RecruitmentStatisticsScreen> createState() => _RecruitmentStatisticsScreenState();
}

class _RecruitmentStatisticsScreenState extends State<RecruitmentStatisticsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? campaignId]) async {
    final generation = ++_generation;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await (widget.loader?.call(campaignId) ?? RecruitmentService().getStatistics(campaignId: campaignId));
      if (mounted && generation == _generation) setState(() => _data = data);
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null && _loading) return const Center(child: CircularProgressIndicator());
    final campaigns = (data?['campaigns'] as List? ?? const []).whereType<Map>().toList();
    final breakdowns = data?['breakdowns'] as Map? ?? const {};
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => _load(data?['campaign_id'] as String?),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
        children: [
          RecruitmentPageHeading(
            title: 'La campagne en chiffres',
            subtitle: 'Les candidatures reçues, en un coup d’œil. Cette vue est partagée avec les enacteurs et les alumni.',
            actions: [
              if (data?['can_access_applications'] == true)
                FilledButton.icon(
                  onPressed: () => context.go('/recruitment/dossiers'),
                  icon: const Icon(Icons.inbox_outlined),
                  label: const Text('Ouvrir les candidatures'),
                ),
              IconButton(
                tooltip: 'Actualiser les chiffres',
                onPressed: _loading ? null : () => _load(data?['campaign_id'] as String?),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(recruitmentMessage(_error, fallback: 'Les chiffres n’ont pas pu être chargés. Réessaie dans un instant.'),
                style: TextStyle(color: colors.error)),
            ),
          if (campaigns.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              key: ValueKey(data?['campaign_id']),
              initialValue: data?['campaign_id'] as String?,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Campagne'),
              items: [for (final campaign in campaigns)
                DropdownMenuItem(value: campaign['id'].toString(), child: Text(campaign['title'].toString()))],
              onChanged: _loading ? null : (value) => _load(value),
            ),
            const SizedBox(height: 20),
          ],
          if (data != null) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${data['total'] ?? 0}', key: const Key('recruitment-statistics-total'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(color: colors.onPrimaryContainer, fontWeight: FontWeight.w800)),
                Text('candidatures reçues', style: TextStyle(color: colors.onPrimaryContainer, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Les chiffres portent sur tous les dossiers de la campagne, quel que soit le juré chargé de leur étude.',
                  style: TextStyle(color: colors.onPrimaryContainer)),
              ]),
            ),
            const SizedBox(height: 20),
            if (campaigns.isEmpty) const Text('Aucune campagne pour le moment.'),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850 && MediaQuery.textScalerOf(context).scale(14) < 22 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
              const sections = {
                'department': 'Par département', 'study_level': 'Par niveau d’études',
                'study_year': 'Par année dans le cursus', 'promotion': 'Par promotion',
                'discovery_channel': 'Comment ont-ils connu Enactus ESP ?',
              };
              return Wrap(spacing: 16, runSpacing: 16, children: [
                for (final section in sections.entries)
                  SizedBox(width: width, child: _BreakdownCard(
                    title: section.value,
                    rows: (breakdowns[section.key] as List? ?? const []).whereType<Map>().toList(),
                  )),
              ]);
            }),
          ],
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final List<Map> rows;
  const _BreakdownCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          if (rows.isEmpty) const Text('Aucune candidature pour le moment.'),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(row['label'].toString())),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${row['count']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${row['percentage']} %', style: TextStyle(color: colors.onSurfaceVariant)),
                  ]),
                ]),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: ((row['percentage'] as num? ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
                  minHeight: 5, borderRadius: BorderRadius.circular(4),
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
