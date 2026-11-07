import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../widgets/recruitment_style.dart';
import '../widgets/recruitment_workspace.dart';

/// Read-only campaign figures. This endpoint never returns candidate identities.
abstract interface class RecruitmentStatisticsGateway {
  Future<Map<String, dynamic>> fetch({String? campaignId});
}

class ApiRecruitmentStatisticsGateway implements RecruitmentStatisticsGateway {
  final ApiClient api;
  final AuthService auth;

  ApiRecruitmentStatisticsGateway({ApiClient? api, AuthService? auth})
    : api = api ?? ApiClient(),
      auth = auth ?? AuthService();

  @override
  Future<Map<String, dynamic>> fetch({String? campaignId}) async {
    final token = await auth.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Connectez-vous pour consulter les chiffres.');
    }
    final query = campaignId == null
        ? ''
        : '?campaign_id=${Uri.encodeQueryComponent(campaignId)}';
    return Map<String, dynamic>.from(
      await api.get('/recruitment/statistics$query', token: token) as Map,
    );
  }
}

/// Accessible to every validated Enacteur or Alumni, independently of
/// permissions to open individual applications or enter jury assessments.
class RecruitmentStatisticsScreen extends StatefulWidget {
  final RecruitmentStatisticsGateway? gateway;

  const RecruitmentStatisticsScreen({super.key, this.gateway});

  @override
  State<RecruitmentStatisticsScreen> createState() =>
      _RecruitmentStatisticsScreenState();
}

class _RecruitmentStatisticsScreenState
    extends State<RecruitmentStatisticsScreen> {
  late final RecruitmentStatisticsGateway _gateway;
  Map<String, dynamic>? _stats;
  String? _selectedCampaign;
  Object? _error;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiRecruitmentStatisticsGateway();
    _refresh();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _refresh({String? campaignId}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _gateway.fetch(
        campaignId: campaignId ?? _selectedCampaign,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _stats = result;
        _selectedCampaign = result['campaign_id']?.toString();
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _campaigns =>
      (_stats?['campaigns'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  List<Map<String, dynamic>> _breakdown(String key) {
    final data = _stats?['breakdowns'];
    if (data is! Map) return const [];
    return (data[key] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) => RecruitmentStyle(
    child: Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final compact = MediaQuery.sizeOf(context).width < 560;
        final horizontal = compact ? 14.0 : 24.0;
        final mayAccessDossiers = _stats?['can_access_applications'] == true;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const Key('recruitment-statistics-screen'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 32),
            children: [
              RecruitmentPageHeading(
                title: 'La campagne en chiffres',
                subtitle:
                    'La participation au recrutement Enactus ESP, vue d’ensemble.',
                actions: [
                  IconButton(
                    tooltip: 'Actualiser les chiffres',
                    onPressed: _loading ? null : () => _refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  if (mayAccessDossiers)
                    OutlinedButton.icon(
                      key: const Key('statistics-open-applications'),
                      onPressed: () => context.go('/recruitment'),
                      icon: const Icon(Icons.folder_shared_outlined),
                      label: const Text('Voir les candidatures'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(minHeight: 3),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          'Impossible de charger les chiffres de la campagne.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _refresh(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_stats != null) ...[
                const SizedBox(height: 18),
                if (_campaigns.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 630),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('statistics-campaign-$_selectedCampaign'),
                      initialValue: _selectedCampaign,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Campagne de recrutement',
                        prefixIcon: Icon(Icons.campaign_outlined),
                      ),
                      items: _campaigns
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item['id']?.toString(),
                              child: Text(
                                item['title']?.toString() ?? 'Campagne',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (value) {
                              if (value != null && value != _selectedCampaign) {
                                _refresh(campaignId: value);
                              }
                            },
                    ),
                  ),
                const SizedBox(height: 18),
                Card(
                  color: colors.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 22,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.how_to_reg_outlined,
                          color: colors.onSecondaryContainer,
                          size: 34,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_stats?['total'] ?? 0}',
                                key: const Key('statistics-total-applications'),
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSecondaryContainer,
                                ),
                              ),
                              Text(
                                'Candidatures reçues',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colors.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final panelWidth = constraints.maxWidth > 900
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    final sections = [
                      (
                        'department',
                        'Par département et filière',
                        Icons.school_outlined,
                      ),
                      (
                        'study_year',
                        'Par année d’études',
                        Icons.format_list_numbered_outlined,
                      ),
                      (
                        'study_level',
                        'Par niveau d’études',
                        Icons.auto_stories_outlined,
                      ),
                      (
                        'discovery_channel',
                        'Comment les candidats nous ont connus',
                        Icons.campaign_outlined,
                      ),
                      ('promotion', 'Par promotion', Icons.groups_outlined),
                    ];
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final section in sections)
                          SizedBox(
                            width: panelWidth,
                            child: _StatisticsBreakdownCard(
                              title: section.$2,
                              icon: section.$3,
                              items: _breakdown(section.$1),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Ces chiffres regroupent les candidatures déposées par '
                  'le formulaire officiel. Ils ne révèlent pas l’identité '
                  'des candidats. Les dossiers et les évaluations restent '
                  'réservés aux membres habilités.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _StatisticsBreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;

  const _StatisticsBreakdownCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              Text(
                'Aucune candidature enregistrée pour cette catégorie.',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              for (final item in items) ...[
                _StatisticsBreakdownRow(item: item),
                const SizedBox(height: 13),
              ],
          ],
        ),
      ),
    );
  }
}

class _StatisticsBreakdownRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _StatisticsBreakdownRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = (item['count'] as num?)?.toInt() ?? 0;
    final percent = ((item['percentage'] as num?)?.toDouble() ?? 0).clamp(
      0.0,
      100.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item['label']?.toString() ?? 'Non renseigné',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$count · ${percent.toStringAsFixed(1)} %',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: percent / 100,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: colors.surfaceContainerHighest,
        ),
      ],
    );
  }
}
