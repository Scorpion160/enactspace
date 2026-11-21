import 'package:flutter/material.dart';
import '../../services/recruitment_review_filters.dart';

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
  String _scoreBand = 'all';
  String _decision = 'all';
  String _disagreement = 'all';
  double _lowerCutoff = 10;
  double _upperCutoff = 15;
  String? _cutoffError;
  final _lowerController = TextEditingController(text: '10');
  final _upperController = TextEditingController(text: '15');
  bool _showAll = false;
  final _target = TextEditingController();
  int? _sortCacheKey;
  List<Map<String, dynamic>>? _sortCache;

  @override
  void dispose() {
    _target.dispose();
    _lowerController.dispose();
    _upperController.dispose();
    super.dispose();
  }

  List<String> _options(String field) {
    final values =
        widget.rows
            .map((row) => row[field]?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  void _updateCutoffs() {
    final lower = double.tryParse(_lowerController.text.replaceAll(',', '.'));
    final upper = double.tryParse(_upperController.text.replaceAll(',', '.'));
    setState(() {
      if (lower == null ||
          upper == null ||
          lower < 0 ||
          upper > 20 ||
          lower >= upper) {
        _cutoffError = 'Indique deux limites valides entre 0 et 20.';
      } else {
        _lowerCutoff = lower;
        _upperCutoff = upper;
        _cutoffError = null;
        _showAll = false;
      }
    });
  }

  void _selectBand(String band, {bool pendingOnly = false}) {
    setState(() {
      _scoreBand = band;
      _decision = pendingOnly ? 'pending' : 'all';
      _readiness = 'all';
      _showAll = false;
    });
  }

  List<Map<String, dynamic>> get _sorted {
    // Input and filter changes invalidate the cache; opening details or
    // editing the optional target no longer re-sorts the complete list.
    final key = Object.hash(
      identityHashCode(widget.rows),
      _department,
      _level,
      _readiness,
      _scoreBand,
      _decision,
      _disagreement,
      _lowerCutoff,
      _upperCutoff,
    );
    if (_sortCacheKey == key && _sortCache != null) {
      return _sortCache!;
    }
    final rows = widget.rows.where((row) {
      final ready = row['ready'] == true;
      return (_department == 'all' || row['department'] == _department) &&
          (_level == 'all' || row['study_level'] == _level) &&
          (_readiness == 'all' || (_readiness == 'ready' ? ready : !ready)) &&
          reviewScoreBandMatches(row, _scoreBand, _lowerCutoff, _upperCutoff) &&
          reviewDecisionMatches(row, _decision) &&
          reviewDisagreementMatches(row, _disagreement);
    }).toList();
    rows.sort((a, b) {
      final readyA = a['ready'] == true;
      final readyB = b['ready'] == true;
      // In today's pending queue, cases needing an extra jury review lead.
      final missingFirst = _scoreBand == 'middle' && _decision == 'pending';
      if (readyA != readyB) {
        return missingFirst ? (readyA ? 1 : -1) : (readyA ? -1 : 1);
      }
      final aScore = reviewJuryMean20(a);
      final bScore = reviewJuryMean20(b);
      if (aScore == null && bScore != null) return 1;
      if (aScore != null && bScore == null) return -1;
      if (aScore != null && bScore != null) {
        final comparison = bScore.compareTo(aScore);
        if (comparison != 0) return comparison;
      }
      return (a['anonymous_code']?.toString() ?? '').compareTo(
        b['anonymous_code']?.toString() ?? '',
      );
    });
    _sortCacheKey = key;
    _sortCache = rows;
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
    final readyCount = rows.where((row) => row['ready'] == true).length;
    final target = int.tryParse(_target.text.trim());
    final belowCount = widget.rows
        .where(
          (row) =>
              reviewScoreBandMatches(row, 'below', _lowerCutoff, _upperCutoff),
        )
        .length;
    final middleCount = widget.rows
        .where(
          (row) =>
              reviewScoreBandMatches(row, 'middle', _lowerCutoff, _upperCutoff),
        )
        .length;
    final aboveCount = widget.rows
        .where(
          (row) =>
              reviewScoreBandMatches(row, 'above', _lowerCutoff, _upperCutoff),
        )
        .length;
    final pendingMiddleCount = widget.rows
        .where(
          (row) =>
              reviewScoreBandMatches(
                row,
                'middle',
                _lowerCutoff,
                _upperCutoff,
              ) &&
              reviewDecisionMatches(row, 'pending'),
        )
        .length;
    return Card(
      key: const Key('selection-comparison-panel'),
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: widget.screening,
        title: Text(
          widget.screening
              ? 'Classement indicatif des dossiers'
              : 'Comparaison des évaluations d’entretien',
        ),
        subtitle: const Text('Retrouvez et comparez les dossiers facilement.'),
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.screening) ...[
            Card(
              margin: EdgeInsets.zero,
              color: colors.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Préparer le tri des dossiers',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sélectionnez une tranche pour retrouver les dossiers.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const Key('comparison-review-pending'),
                          onPressed: () =>
                              _selectBand('middle', pendingOnly: true),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: Text('À étudier ($pendingMiddleCount)'),
                        ),
                        ChoiceChip(
                          key: const Key('comparison-band-below'),
                          label: Text(
                            'Sous ${_lowerCutoff.toStringAsFixed(0)} ($belowCount)',
                          ),
                          selected: _scoreBand == 'below',
                          onSelected: (_) => _selectBand('below'),
                        ),
                        ChoiceChip(
                          key: const Key('comparison-band-middle'),
                          label: Text(
                            '${_lowerCutoff.toStringAsFixed(0)} à moins de ${_upperCutoff.toStringAsFixed(0)} ($middleCount)',
                          ),
                          selected: _scoreBand == 'middle',
                          onSelected: (_) => _selectBand('middle'),
                        ),
                        ChoiceChip(
                          key: const Key('comparison-band-above'),
                          label: Text(
                            '${_upperCutoff.toStringAsFixed(0)} et plus ($aboveCount)',
                          ),
                          selected: _scoreBand == 'above',
                          onSelected: (_) => _selectBand('above'),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      key: const Key('comparison-cutoffs-editor'),
                      initiallyExpanded: false,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      title: const Text('Ajuster les seuils'),
                      subtitle: const Text('Deux repères sur 20'),
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 150,
                              child: TextField(
                                key: const Key('comparison-cutoff-low'),
                                controller: _lowerController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Premier seuil',
                                  hintText: '10',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                onChanged: (_) => _updateCutoffs(),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: TextField(
                                key: const Key('comparison-cutoff-high'),
                                controller: _upperController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Second seuil',
                                  hintText: '15',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                onChanged: (_) => _updateCutoffs(),
                              ),
                            ),
                          ],
                        ),
                        if (_cutoffError != null)
                          Text(
                            _cutoffError!,
                            style: TextStyle(color: colors.error),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth >= 600
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
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
                          value: 'all',
                          child: Text('Tous les départements'),
                        ),
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
                    width: width,
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
                          value: 'all',
                          child: Text('Tous les niveaux'),
                        ),
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
                    width: width,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('comparison-readiness-$_readiness'),
                      isExpanded: true,
                      initialValue: _readiness,
                      decoration: const InputDecoration(
                        labelText: 'Évaluations',
                        prefixIcon: Icon(Icons.fact_check_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ready',
                          child: Text('Évaluations complètes'),
                        ),
                        DropdownMenuItem(
                          value: 'not_ready',
                          child: Text('Avis à compléter'),
                        ),
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Tous les dossiers'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _readiness = value ?? 'ready';
                        _showAll = false;
                      }),
                    ),
                  ),
                  if (widget.screening) ...[
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('comparison-decision-$_decision'),
                        initialValue: _decision,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Décision',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Toutes les décisions'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Sans décision'),
                          ),
                          DropdownMenuItem(
                            value: 'shortlisted',
                            child: Text('Présélectionnés'),
                          ),
                          DropdownMenuItem(
                            value: 'not_shortlisted',
                            child: Text('Non présélectionnés'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _decision = value ?? 'all';
                          _showAll = false;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('comparison-disagreement-$_disagreement'),
                        initialValue: _disagreement,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Écart entre jurés',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tous les écarts'),
                          ),
                          DropdownMenuItem(
                            value: 'high',
                            child: Text('5 points ou plus'),
                          ),
                          DropdownMenuItem(
                            value: 'low',
                            child: Text('Moins de 5 points'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _disagreement = value ?? 'all';
                          _showAll = false;
                        }),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            color: colors.surfaceContainerLow,
            child: ExpansionTile(
              initiallyExpanded: false,
              title: const Text('Estimer un effectif'),
              subtitle: const Text(
                'Pour le département et le niveau sélectionnés',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              children: [
                const SizedBox(height: 12),
                TextField(
                  key: const Key('comparison-target-scenario'),
                  controller: _target,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de places envisagé',
                    hintText: 'Par exemple : 5',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Text(
                  target == null || target < 1
                      ? '$readyCount dossiers avec évaluations complètes.'
                      : '$readyCount dossiers évalués · objectif de $target places '
                            '· différence : ${readyCount - target}.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${rows.length} dossier(s) · classement par note',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _department = 'all';
                  _level = 'all';
                  _readiness = 'ready';
                  _scoreBand = 'all';
                  _decision = 'all';
                  _disagreement = 'all';
                  _showAll = false;
                  _target.clear();
                }),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Réinitialiser'),
              ),
            ],
          ),
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
    final department =
        row['department']?.toString() ?? 'Département non précisé';
    final level = row['study_level']?.toString() ?? 'Niveau non précisé';
    final applicationId = row['application_id']?.toString() ?? '';
    final juryScore = reviewJuryMean20(row);
    final scoreText = juryScore == null
        ? 'Sans note /20'
        : '${juryScore.toStringAsFixed(2)}/20';
    final details = [
      department,
      level,
      '$reviewCount/$requiredCount avis',
      if (score != null) 'Barème ${score.toStringAsFixed(1)}/100',
      if (row['jury_score_source'] == 'rubric') 'Grille d’évaluation',
      if (row['jury_spread_20'] is num)
        'Écart ${((row['jury_spread_20'] as num).toDouble()).toStringAsFixed(1)}/20',
      if (row['decision'] == 'shortlisted') 'Présélectionné',
      if (row['decision'] == 'not_shortlisted') 'Non présélectionné',
      if (row['decision'] == null) 'Sans décision',
      ready ? 'Évalué' : 'Avis à compléter',
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
          Text(
            ready ? 'Avis complets' : 'À compléter',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ],
      ),
      onTap: onOpen == null || applicationId.isEmpty
          ? null
          : () => onOpen!(applicationId),
    );
  }
}
