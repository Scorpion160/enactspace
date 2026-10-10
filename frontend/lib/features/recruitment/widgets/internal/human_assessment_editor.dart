import 'package:flutter/material.dart';

class HumanAssessmentEditor extends StatefulWidget {
  final Map<String, dynamic> rubric;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;
  final Map<String, dynamic>? initialAssessment;
  const HumanAssessmentEditor({
    super.key,
    required this.rubric,
    required this.onChanged,
    this.enabled = true,
    this.initialAssessment,
  });
  @override
  State<HumanAssessmentEditor> createState() => _HumanAssessmentEditorState();
}

class _HumanAssessmentEditorState extends State<HumanAssessmentEditor> {
  final Map<String, int> _ratings = {};
  final Map<String, String> _evidence = {};
  List<Map<String, dynamic>> get _criteria =>
      (widget.rubric['criteria'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
  @override
  void initState() {
    super.initState();
    if (!isCompleteHumanAssessment(widget.initialAssessment, widget.rubric)) {
      return;
    }
    for (final row in widget.initialAssessment!['ratings'] as List) {
      _ratings[row['criterion_id']] = row['rating'] as int;
      _evidence[row['criterion_id']] = row['evidence'].toString();
    }
  }

  void _notify() => widget.onChanged({
    'rubric_version': widget.rubric['version'],
    'ratings': [
      for (final criterion in _criteria)
        {
          'criterion_id': criterion['id'],
          'rating': _ratings[criterion['id']],
          'evidence': _evidence[criterion['id']] ?? '',
        },
    ],
  });
  @override
  Widget build(BuildContext context) {
    final criteria = _criteria;
    final completed = criteria
        .where(
          (c) =>
              _ratings.containsKey(c['id']) &&
              (_evidence[c['id']] ?? '').trim().isNotEmpty,
        )
        .length;
    final total = _ratings.values.fold<int>(0, (sum, score) => sum + score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.rubric['guidance']?.toString() ?? '',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 12),
        Text(
          completed == criteria.length && criteria.isNotEmpty
              ? 'Ton évaluation : ${total * 5}/100'
              : '$completed/${criteria.length} critères renseignés',
          key: const Key('rubric-completion'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final criterion in criteria) ...[
          const SizedBox(height: 20),
          Text(
            criterion['label']?.toString() ?? '',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            criterion['description']?.toString() ?? '',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: ValueKey('rubric-rating-${criterion['id']}'),
            isExpanded: true,
            initialValue: _ratings[criterion['id']],
            decoration: const InputDecoration(labelText: 'Niveau observé'),
            hint: const Text('À évaluer'),
            items: [
              for (var score = 0; score <= 4; score++)
                DropdownMenuItem(value: score, child: Text('$score/4')),
            ],
            onChanged: !widget.enabled
                ? null
                : (score) {
                    if (score == null) return;
                    setState(
                      () => _ratings[criterion['id'].toString()] = score,
                    );
                    _notify();
                  },
          ),
          if (_ratings.containsKey(criterion['id'])) ...[
            const SizedBox(height: 8),
            Text(
              (criterion['anchors'] as List)[_ratings[criterion['id']]!]
                  .toString(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('rubric-evidence-${criterion['id']}'),
            enabled: widget.enabled,
            initialValue: _evidence[criterion['id']],
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Exemple ou observation',
              hintText:
                  'Ce qui, dans la réponse ou l’entretien, justifie ta note.',
            ),
            onChanged: (value) {
              setState(() => _evidence[criterion['id'].toString()] = value);
              _notify();
            },
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Une réponse manquante reste à préciser. Le parcours scolaire, '
          'l’apparence, le genre et la longueur du texte ne donnent aucun point. '
          'Un déplacement impossible peut être compensé par une contribution utile avant ou après la mission.',
        ),
      ],
    );
  }
}

bool isCompleteHumanAssessment(
  Map<String, dynamic>? assessment,
  Map<String, dynamic>? rubric,
) {
  if (assessment == null ||
      rubric == null ||
      assessment['rubric_version'] != rubric['version']) {
    return false;
  }
  final expected = (rubric['criteria'] as List? ?? [])
      .whereType<Map>()
      .map((c) => c['id'])
      .toSet();
  final rows = (assessment['ratings'] as List? ?? []).whereType<Map>().toList();
  return expected.isNotEmpty &&
      rows.length == expected.length &&
      rows.map((c) => c['criterion_id']).toSet().containsAll(expected) &&
      rows.every(
        (row) =>
            row['rating'] is int &&
            row['rating'] >= 0 &&
            row['rating'] <= 4 &&
            (row['evidence']?.toString() ?? '').trim().isNotEmpty,
      );
}
