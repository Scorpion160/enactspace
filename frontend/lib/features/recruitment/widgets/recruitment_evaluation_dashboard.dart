import 'package:flutter/material.dart';

/// Statistical overview derived from the selected recruitment campaign.
class RecruitmentEvaluationDashboard extends StatelessWidget {
  const RecruitmentEvaluationDashboard({super.key, required this.data});

  final Map<String, dynamic> data;

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _items(Object? value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  int _count(Object? value) => value is num ? value.toInt() : 0;
  double? _value(Object? value) => value is num ? value.toDouble() : null;

  String _integer(Object? value) => _count(value).toString();
  String _score(Object? value) {
    final score = _value(value);
    return score == null
        ? '—'
        : '${score.toStringAsFixed(2).replaceAll('.', ',')}/20';
  }

  String _average(Object? value) {
    final number = _value(value);
    return number == null
        ? '—'
        : number.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _percentage(Object? value) =>
      '${(_value(value) ?? 0).toStringAsFixed(1).replaceAll('.', ',')} %';

  @override
  Widget build(BuildContext context) {
    final overview = _map(data['overview']);
    final scoring = _map(data['scoring']);
    final disagreements = _map(data['disagreements']);
    final recommendations = _map(data['recommendations']);
    final groups = _map(data['groups']);
    final count = _count(overview['applications']);
    final minimum = _count(data['minimum_reviews']);
    final completed = _count(overview['completed']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          'Étude des dossiers',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Données calculées à partir des évaluations de la campagne sélectionnée.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        _metricGrid(context, [
          _Metric(
            '$completed / $count',
            'Dossiers ayant au moins $minimum notes',
            'Dossiers pour lesquels le nombre minimal d’évaluations est atteint.',
            Icons.fact_check_outlined,
          ),
          _Metric(
            _integer(overview['reviews']),
            'Évaluations enregistrées',
            'Dont ${_integer(overview['scored_reviews'])} avec une note.',
            Icons.rate_review_outlined,
          ),
          _Metric(
            _score(scoring['candidate_average']),
            'Moyenne des candidats',
            'Moyenne calculée à partir de la moyenne de chaque dossier noté.',
            Icons.functions_outlined,
          ),
          _Metric(
            _integer(disagreements['sensitive_total']),
            'Dossiers avec écarts importants',
            'Au moins 5 points entre deux notes, ou des avis favorables et défavorables opposés.',
            Icons.compare_arrows_outlined,
          ),
        ]),
        const SizedBox(height: 10),
        _panel(
          context,
          'Répartition des évaluations par dossier',
          Icons.checklist_rtl_outlined,
          [
            _progress(
              context,
              'Dossiers avec au moins $minimum notes',
              completed,
              count,
              supporting: _percentage(overview['completed_percentage']),
            ),
            const SizedBox(height: 10),
            Text(
              '${_integer(overview['missing_reviews'])} note(s) manquante(s) pour atteindre le minimum sur tous les dossiers. '
              '${_integer(overview['beyond_minimum'])} note(s) au-delà de ce minimum.',
            ),
            const SizedBox(height: 12),
            ..._items(overview['distribution']).map(
              (item) => _progress(
                context,
                '${item['label']} note(s)',
                _count(item['count']),
                count,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Moyenne : ${_average(overview['average_reviews'])} évaluation(s) par candidature. '
              'Jurés participants : ${_integer(overview['reviewers'])}.',
            ),
          ],
        ),
        _panel(context, 'Résultats des notes', Icons.insights_outlined, [
          if (scoring['candidate_average'] == null)
            const Text('Aucune note enregistrée pour cette campagne.')
          else ...[
            _metricGrid(context, [
              _Metric(
                _score(scoring['review_average']),
                'Moyenne des notes',
                'Toutes les notes prises ensemble.',
                Icons.calculate_outlined,
              ),
              _Metric(
                _score(scoring['median']),
                'Note au milieu du classement',
                'La moitié des dossiers notés se situe de chaque côté de cette valeur.',
                Icons.horizontal_rule_rounded,
              ),
              _Metric(
                _score(scoring['lowest']),
                'Moyenne la plus basse',
                '',
                Icons.south_rounded,
              ),
              _Metric(
                _score(scoring['highest']),
                'Moyenne la plus haute',
                '',
                Icons.north_rounded,
              ),
            ]),
            const SizedBox(height: 14),
            Text(
              'Dans le classement des moyennes individuelles, environ un quart des dossiers '
              'obtient ${_score(scoring['lower_quarter'])} ou moins, et environ un quart '
              'obtient ${_score(scoring['upper_quarter'])} ou plus.',
            ),
            const SizedBox(height: 5),
            Text(
              'Les 10 % de dossiers les mieux notés commencent autour de '
              '${_score(scoring['top_tenth_threshold'])}.',
            ),
            const SizedBox(height: 12),
            Text(
              'Répartition des moyennes des dossiers ayant atteint le minimum de notes',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ..._items(scoring['score_bands']).map(
              (item) => _progress(
                context,
                '${item['label']} sur 20',
                _count(item['count']),
                completed,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_integer(scoring['at_least_14'])} dossiers à 14/20 ou plus · '
              '${_integer(scoring['at_least_16'])} à 16/20 ou plus · '
              '${_integer(scoring['below_10'])} en dessous de 10/20.',
            ),
          ],
        ]),
        _panel(context, 'Écarts entre les évaluations', Icons.compare_outlined, [
          Text(
            'Un écart est la différence entre la note la plus haute et la note la plus basse d’un même dossier.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _metricGrid(context, [
            _Metric(
              _integer(disagreements['spread_ge_5']),
              'Écart d’au moins 5 points',
              '',
              Icons.warning_amber_outlined,
            ),
            _Metric(
              _integer(disagreements['opposite_opinions']),
              'Avis favorables et défavorables',
              '',
              Icons.swap_horiz_rounded,
            ),
            _Metric(
              _integer(disagreements['mixed_recommendations']),
              'Recommandations différentes',
              '',
              Icons.forum_outlined,
            ),
            _Metric(
              _score(disagreements['max_spread']),
              'Plus grand écart observé',
              '',
              Icons.trending_up_outlined,
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            '${_integer(disagreements['spread_ge_3'])} dossiers présentent au moins 3 points d’écart ; '
            '${_integer(disagreements['spread_ge_4'])} au moins 4 ; '
            '${_integer(disagreements['spread_ge_6'])} au moins 6.',
          ),
        ]),
        _panel(context, 'Avis du jury', Icons.how_to_vote_outlined, [
          Text(
            'Avis enregistrés individuellement',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...[
            ('favorable', 'Favorables'),
            ('reserve', 'Réservés'),
            ('defavorable', 'Défavorables'),
          ].map(
            (item) => _progress(
              context,
              item.$2,
              _count(_map(recommendations['votes'])[item.$1]),
              _count(overview['scored_reviews']),
            ),
          ),
          const Divider(height: 28),
          Text(
            'Avis le plus fréquent sur chaque dossier',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...[
            ('favorable', 'Favorable'),
            ('reserve', 'Réservé'),
            ('defavorable', 'Défavorable'),
            ('egalite', 'Égalité des avis'),
          ].map(
            (item) => _progress(
              context,
              item.$2,
              _count(_map(recommendations['majority'])[item.$1]),
              count,
            ),
          ),
        ]),
        _panel(
          context,
          'Répartition par département et niveau',
          Icons.school_outlined,
          [
            _groupTable(context, 'Départements', _items(groups['department'])),
            const SizedBox(height: 14),
            _groupTable(
              context,
              'Niveaux d’études',
              _items(groups['study_level']),
            ),
            const SizedBox(height: 14),
            _groupTable(context, 'Genre déclaré', _items(groups['gender'])),
          ],
        ),
        _panel(
          context,
          'Activité et état des candidatures',
          Icons.calendar_month_outlined,
          [
            _activity(context, _items(data['daily'])),
            const SizedBox(height: 15),
            Text(
              'État actuel des candidatures',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ..._map(data['statuses']).entries.map(
              (entry) => _line(
                context,
                _statusLabel(entry.key),
                _integer(entry.value),
              ),
            ),
            const SizedBox(height: 10),
            _line(
              context,
              'Entretiens programmés',
              _integer(data['interviews_scheduled']),
            ),
            _line(
              context,
              'Comptes de membres créés',
              _integer(data['converted_users']),
            ),
            if (data['target_headcount'] != null)
              _line(
                context,
                'Objectif de recrutement',
                _integer(data['target_headcount']),
              ),
            const Divider(height: 28),
            Text(
              'Champs non renseignés',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ...[
              ('phone', 'Téléphone'),
              ('motivation', 'Motivation'),
              ('availability', 'Disponibilités'),
              ('department', 'Département'),
              ('study_level', 'Niveau d’études'),
              ('known_enactus_from', 'Comment le candidat a connu Enactus'),
              ('questionnaire_answers', 'Questionnaire'),
            ].map(
              (field) => _line(
                context,
                field.$2,
                _integer(_map(data['missing_fields'])[field.$1]),
              ),
            ),
            const Divider(height: 28),
            Text(
              'Participation des jurés',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _line(
              context,
              'Évaluations par juré (moyenne)',
              _average(_map(data['reviewer_workload'])['average']),
            ),
            _line(
              context,
              'Plus grand nombre d’évaluations par juré',
              _integer(_map(data['reviewer_workload'])['highest']),
            ),
            _line(
              context,
              'Plus petit nombre d’évaluations par juré',
              _integer(_map(data['reviewer_workload'])['lowest']),
            ),
            _line(
              context,
              'Part réalisée par les 3 jurés les plus actifs',
              _percentage(
                _map(data['reviewer_workload'])['top_three_percentage'],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _statusLabel(String status) => switch (status) {
    'submitted' => 'Reçus',
    'under_review' => 'En cours d’étude',
    'interview_scheduled' => 'Entretiens programmés',
    'accepted' => 'Acceptés',
    'rejected' => 'Non retenus',
    'waiting_list' => 'En liste d’attente',
    'cancelled' => 'Annulés',
    _ => status,
  };

  Widget _metricGrid(BuildContext context, List<_Metric> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 920
            ? 4
            : width >= 580
            ? 2
            : 1;
        final cardWidth = (width - 10 * (columns - 1)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (metric) => SizedBox(
                  width: cardWidth,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            metric.icon,
                            size: 21,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            metric.value,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metric.label,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (metric.help.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              metric.help,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _panel(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      margin: const EdgeInsets.only(top: 13),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded:
            title == 'Répartition des évaluations par dossier' ||
            title == 'Résultats des notes',
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _progress(
    BuildContext context,
    String title,
    int value,
    int total, {
    String? supporting,
  }) {
    final ratio = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$value${supporting == null ? '' : ' · $supporting'}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _groupTable(
    BuildContext context,
    String label,
    List<Map<String, dynamic>> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('Aucune donnée.')
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['label']?.toString() ?? 'Non renseigné',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_integer(item['count'])} dossiers · ${_score(item['average'])}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_integer(item['completed'])} suffisamment notés · '
                    '${_integer(item['at_least_14'])} à 14/20 ou plus · '
                    '${_integer(item['high_disagreement'])} avec écart ≥ 5 points',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 12),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _activity(BuildContext context, List<Map<String, dynamic>> values) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Candidatures et évaluations par jour',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 7),
        if (values.isEmpty)
          const Text('Aucune activité enregistrée.')
        else
          ...values.map(
            (item) => _line(
              context,
              item['date']?.toString() ?? '',
              '${_integer(item['applications'])} candidatures · ${_integer(item['reviews'])} notes',
            ),
          ),
      ],
    );
  }
}

class _Metric {
  const _Metric(this.value, this.label, this.help, this.icon);
  final String value;
  final String label;
  final String help;
  final IconData icon;
}
