import 'package:flutter/material.dart';

import '../../services/recruitment_selection_api.dart';

/// Candidate shortlist with independent screening scores, retained after
/// publication and displayed anonymously until identities are revealed.
class RecruitmentShortlistPanel extends StatefulWidget {
  final String campaignId;
  final int refreshToken;
  final ValueChanged<String>? onOpen;
  final RecruitmentSelectionApi? api;

  const RecruitmentShortlistPanel({
    super.key,
    required this.campaignId,
    required this.refreshToken,
    this.onOpen,
    this.api,
  });

  @override
  State<RecruitmentShortlistPanel> createState() =>
      _RecruitmentShortlistPanelState();
}

class _RecruitmentShortlistPanelState extends State<RecruitmentShortlistPanel> {
  late final RecruitmentSelectionApi _api;
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>>? _rows;
  String? _error;
  String _department = 'all';
  String _level = 'all';
  bool _showAll = false;
  bool _identityVisible = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? RecruitmentSelectionApi();
    _load();
  }

  @override
  void didUpdateWidget(covariant RecruitmentShortlistPanel old) {
    super.didUpdateWidget(old);
    if (widget.campaignId != old.campaignId ||
        widget.refreshToken != old.refreshToken) {
      if (widget.campaignId != old.campaignId) {
        _rows = null;
        _department = 'all';
        _level = 'all';
        _search.clear();
        _showAll = false;
      }
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final data = await _api.request(
        'campaigns/${widget.campaignId}/selection/shortlist',
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows = (data['rows'] as List? ?? const [])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
        _identityVisible = data['identities_revealed'] == true;
        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = 'Impossible de charger les candidats retenus.');
    }
  }

  List<String> _values(String key) {
    final values =
        (_rows ?? const <Map<String, dynamic>>[])
            .map((row) => row[key]?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final all = _rows ?? const <Map<String, dynamic>>[];
    final search = _search.text.trim().toLowerCase();
    final rows = all.where((row) {
      final candidate = [
        row['candidate_name']?.toString() ?? '',
        row['anonymous_code']?.toString() ?? '',
      ].join(' ').toLowerCase();
      return (_department == 'all' || row['department'] == _department) &&
          (_level == 'all' || row['study_level'] == _level) &&
          (search.isEmpty || candidate.contains(search));
    }).toList();
    final visible = _showAll ? rows : rows.take(25).toList();

    return Card(
      key: const Key('screening-shortlist-panel'),
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          'Retenus pour entretien (${all.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text('Consulter le classement par note sur 20'),
        leading: Icon(Icons.groups_2_outlined, color: colors.primary),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_rows == null && _error == null)
            const LinearProgressIndicator()
          else if (_error != null)
            Row(
              children: [
                Expanded(child: Text(_error!)),
                TextButton(onPressed: _load, child: const Text('Réessayer')),
              ],
            )
          else ...[
            if (!_identityVisible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Les noms apparaîtront après la publication des résultats '
                  'et la levée de l’anonymat.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            TextField(
              key: const Key('shortlist-search'),
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Rechercher un candidat',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _showAll = false),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final dropdowns = <Widget>[
                  DropdownButtonFormField<String>(
                    key: ValueKey('shortlist-department-$_department'),
                    initialValue: _values('department').contains(_department)
                        ? _department
                        : 'all',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Département',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Tous les départements'),
                      ),
                      for (final item in _values('department'))
                        DropdownMenuItem(
                          value: item,
                          child: Text(item, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _department = value ?? 'all';
                      _showAll = false;
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('shortlist-level-$_level'),
                    initialValue: _values('study_level').contains(_level)
                        ? _level
                        : 'all',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Niveau',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Tous les niveaux'),
                      ),
                      for (final item in _values('study_level'))
                        DropdownMenuItem(
                          value: item,
                          child: Text(item, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _level = value ?? 'all';
                      _showAll = false;
                    }),
                  ),
                ];
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dropdowns[0],
                      const SizedBox(height: 10),
                      dropdowns[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: dropdowns[0]),
                    const SizedBox(width: 12),
                    Expanded(child: dropdowns[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${rows.length} candidat(s) · Note décroissante',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _department = 'all';
                    _level = 'all';
                    _search.clear();
                    _showAll = false;
                  }),
                  child: const Text('Effacer les filtres'),
                ),
              ],
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucun candidat ne correspond à ces filtres.'),
              ),
            for (final row in visible) ...[
              const Divider(height: 1),
              _ShortlistRow(row: row, onOpen: widget.onOpen),
            ],
            if (!_showAll && visible.length < rows.length)
              TextButton.icon(
                onPressed: () => setState(() => _showAll = true),
                icon: const Icon(Icons.unfold_more),
                label: Text('Afficher les ${rows.length} candidats'),
              ),
            if (_showAll && rows.length > 25)
              TextButton.icon(
                onPressed: () => setState(() => _showAll = false),
                icon: const Icon(Icons.unfold_less),
                label: const Text('Réduire la liste'),
              ),
          ],
        ],
      ),
    );
  }
}

class _ShortlistRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final ValueChanged<String>? onOpen;

  const _ShortlistRow({required this.row, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final id = row['application_id']?.toString() ?? '';
    final code = row['anonymous_code']?.toString() ?? 'Candidat';
    final name = row['candidate_name']?.toString();
    final label = name != null && name.isNotEmpty ? name : code;
    final rank = (row['rank'] as num?)?.toInt() ?? 0;
    final score = (row['jury_average_20'] as num?)?.toDouble();
    final scoreText = score == null
        ? 'Sans note'
        : '${score.toStringAsFixed(2)}/20';
    final department =
        row['department']?.toString() ?? 'Département non précisé';
    final level = row['study_level']?.toString() ?? 'Niveau non précisé';
    final count = (row['review_count'] as num?)?.toInt() ?? 0;
    final planned = row['interview_scheduled'] == true
        ? ' · Entretien programmé'
        : '';
    return ListTile(
      key: ValueKey('shortlist-row-$id'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: colors.surfaceContainerHighest,
        child: Text('$rank', style: TextStyle(color: colors.onSurface)),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$department · $level · $count avis$planned'),
      trailing: Text(
        scoreText,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: onOpen == null || id.isEmpty ? null : () => onOpen!(id),
    );
  }
}
