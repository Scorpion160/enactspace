import 'package:flutter/material.dart';

/// A read-only, anonymous comparison for recruitment managers.
///
/// A provisional score is never a decision: only fully reviewed dossiers are
/// shown by default. Department and study-level filters are optional aids to
/// deliberation, not eligibility criteria or automatic quotas.
class RecruitmentComparisonPanel extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final bool screening;
  final ValueChanged<String>? onOpen;

  const RecruitmentComparisonPanel({
    super.key,
    required this.rows,
    required this.screening,
    this.onOpen,
  });

  @override
  State<RecruitmentComparisonPanel> createState() =>
      _RecruitmentComparisonPanelState();
}

class _RecruitmentComparisonPanelState
    extends State<RecruitmentComparisonPanel> {
  String _department = 'all';
  String _level = 'all';
  String _readiness = 'ready';
  bool _showAll = false;

  List<String> _options(String field) {
    final values = widget.rows
        .map((row) => row[field]?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()..sort();
    return values;
  }

  List<Map<String, dynamic>> get _sorted {
    final rows = widget.rows.where((row) {
      final ready = row['ready'] == true;
      return (_department == 'all' || row['department'] == _department) &&
          (_level == 'all' || row['study_level'] == _level) &&
          (_readiness == 'all' ||
              (_readiness == 'ready' ? ready : !ready));
    }).toList();
    rows.sort((a, b) {
      // Never rank an unfinished dossier above a complete one.
      final readyA = a['ready'] == true;
      final readyB = b['ready'] == true;
      if (readyA != readyB) return readyA ? -1 : 1;
      final aScore = (a['score'] as num?)?.toDouble();
      final bScore = (b['score'] as num?)?.toDouble();
      if (aScore == null && bScore != null) return 1;
      if (aScore != null && bScore == null) return -1;
      if (aScore != null && bScore != null) {
        final comparison = bScore.compareTo(aScore);
        if (comparison != 0) return comparison;
      }
      return (a['anonymous_code']?.toString() ?? '')
          .compareTo(b['anonymous_code']?.toString() ?? '');
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final rows = _sorted;
    final departments = _options('department');
    final levels = _options('study_level');
    final department = departments.contains(_department) ? _department : 'all';
    final level = levels.contains(_level) ? _level : 'all';
    final visible = _showAll ? rows : rows.take(25).toList();
    return Card(
      key: const Key('selection-comparison-panel'),
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(widget.screening
            ? 'Classement indicatif des dossiers'
            : 'Comparaison des évaluations d’entretien'),
        subtitle: const Text(
          'Notes décroissantes et filtres facultatifs · aucune décision automatique',
        ),
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Seuls les dossiers avec toutes leurs évaluations sont affichés '
            'par défaut. Une note encore provisoire ne doit pas déterminer '
            'une décision. Les filtres ne modifient ni les notes ni les '
            'règles d’éligibilité. Les identités restent masquées.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 245,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('comparison-department-$department'),
                  isExpanded: true,
                  initialValue: department,
                  decoration: const InputDecoration(
                    labelText: 'Département',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('Tous les départements')),
                    for (final name in departments)
                      DropdownMenuItem(
                        value: name,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _department = value ?? 'all';
                    _showAll = false;
                  }),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('comparison-level-$level'),
                  isExpanded: true,
                  initialValue: level,
                  decoration: const InputDecoration(
                    labelText: 'Niveau d’études',
                    prefixIcon: Icon(Icons.auto_stories_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('Tous les niveaux')),
                    for (final name in levels)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) => setState(() {
                    _level = value ?? 'all';
                    _showAll = false;
                  }),
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('comparison-readiness-$_readiness'),
                  isExpanded: true,
                  initialValue: _readiness,
                  decoration: const InputDecoration(
                    labelText: 'Avancement du dossier',
                    prefixIcon: Icon(Icons.fact_check_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'ready', child: Text('Évaluations complètes')),
                    DropdownMenuItem(
                        value: 'not_ready', child: Text('Avis à compléter')),
                    DropdownMenuItem(
                        value: 'all', child: Text('Tous les dossiers')),
                  ],
                  onChanged: (value) => setState(() {
                    _readiness = value ?? 'ready';
                    _showAll = false;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Text(
                '${rows.length} dossier(s) · tri par note décroissante',
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _department = 'all';
                _level = 'all';
                _readiness = 'ready';
                _showAll = false;
              }),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Réinitialiser'),
            ),
          ]),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Aucun dossier ne correspond aux filtres sélectionnés.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _ComparisonRow(
                position: i + 1,
                row: visible[i],
                onOpen: widget.onOpen,
              ),
            ],
          if (!_showAll && rows.length > visible.length)
            TextButton.icon(
              onPressed: () => setState(() => _showAll = true),
              icon: const Icon(Icons.unfold_more_outlined),
              label: Text('Afficher les ${rows.length} dossiers'),
            ),
          if (_showAll && rows.length > 25)
            TextButton.icon(
              onPressed: () => setState(() => _showAll = false),
              icon: const Icon(Icons.unfold_less_outlined),
              label: const Text('Limiter l’affichage'),
            ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final int position;
  final Map<String, dynamic> row;
  final ValueChanged<String>? onOpen;

  const _ComparisonRow({
    required this.position,
    required this.row,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ready = row['ready'] == true;
    final code = row['anonymous_code']?.toString() ?? 'Dossier anonymisé';
    final score = (row['score'] as num?)?.toDouble();
    final reviewCount = (row['review_count'] as num?)?.toInt() ?? 0;
    final requiredCount = (row['required_reviews'] as num?)?.toInt() ?? 3;
    final spread = (row['spread'] as num?)?.toDouble();
    final department = row['department']?.toString() ?? 'Département non précisé';
    final level = row['study_level']?.toString() ?? 'Niveau non précisé';
    final applicationId = row['application_id']?.toString() ?? '';
    final scoreText = score == null ? 'Sans note' : '${score.toStringAsFixed(1)}/100';
    final details = [
      department,
      level,
      '$reviewCount/$requiredCount avis',
      if (spread != null) 'Écart ${spread.toStringAsFixed(0)} points',
      ready ? 'Complet' : 'Provisoire',
    ].join(' · ');

    return ListTile(
      key: ValueKey('comparison-row-$applicationId'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: CircleAvatar(
        backgroundColor: colors.surfaceContainerHighest,
        child: Text('$position', style: TextStyle(color: colors.onSurface)),
      ),
      title: Text(code, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(details),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(scoreText, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(ready ? 'Avis complets' : 'À compléter',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        ],
      ),
      onTap: onOpen == null || applicationId.isEmpty
          ? null
          : () => onOpen!(applicationId),
    );
  }
}
