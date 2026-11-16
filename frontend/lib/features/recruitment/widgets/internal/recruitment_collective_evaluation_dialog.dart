import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';

const _criteria = <String, String>{
  'motivation': 'Motivation et engagement · 20 pts',
  'mission_enactus': 'Compréhension de la mission Enactus · 15 pts',
  'initiative_leadership': 'Initiative et leadership · 15 pts',
  'travail_equipe': 'Travail en équipe et adaptation · 15 pts',
  'esprit_entrepreneurial': 'Esprit entrepreneurial · 15 pts',
  'communication': 'Communication et expression · 10 pts',
  'disponibilite': 'Disponibilité et implication · 10 pts',
};
const _weights = <String, int>{
  'motivation': 20,
  'mission_enactus': 15,
  'initiative_leadership': 15,
  'travail_equipe': 15,
  'esprit_entrepreneurial': 15,
  'communication': 10,
  'disponibilite': 10,
};
const _english = <String, String>{
  'comprehension_orale': 'Compréhension orale',
  'fluidite': 'Fluidité et spontanéité',
  'vocabulaire': 'Vocabulaire',
  'grammaire': 'Grammaire',
  'prononciation': 'Prononciation et intelligibilité',
};

/// Shared evaluation: one saved group score, not three individual evaluations.
/// English is deliberately NOT added to the general /100 score.
Future<bool> showCollectiveEvaluationDialog(
  BuildContext context, {
  required String applicationId,
  required String candidateName,
}) async {
  final api = ApiClient();
  final auth = AuthService();
  final token = await auth.getToken();
  if (token == null) return false;
  final endpoint = '/recruitment/applications/$applicationId/interview/collective';
  final Map<String, dynamic> existing;
  try {
    existing = Map<String, dynamic>.from(
      await api.get(endpoint, token: token) as Map,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger la grille du jury.')),
      );
    }
    return false;
  }
  final canEdit = existing['can_edit'] == true;
  final previous = existing['ratings'] is Map
      ? Map<String, dynamic>.from(existing['ratings'] as Map)
      : <String, dynamic>{};
  final ratings = <String, int?>{
    for (final key in _criteria.keys) key: (previous[key] as num?)?.toInt(),
  };
  final previousEnglish = existing['english'] is Map
      ? Map<String, dynamic>.from(existing['english'] as Map)
      : <String, dynamic>{};
  var useEnglish = existing['english'] is Map;
  final english = <String, int?>{
    for (final key in _english.keys)
      key: (previousEnglish[key] as num?)?.toInt(),
  };
  final strengths = TextEditingController(
    text: existing['strengths']?.toString() ?? '',
  );
  final vigilance = TextEditingController(
    text: existing['vigilance']?.toString() ?? '',
  );
  final potential = TextEditingController(
    text: existing['potential']?.toString() ?? '',
  );
  final pole = TextEditingController(
    text: existing['recommended_pole']?.toString() ?? '',
  );
  final justification = TextEditingController(
    text: existing['justification']?.toString() ?? '',
  );
  var recommendation = existing['recommendation']?.toString() ?? 'reserve';
  const recommendations = <String, String>{
    'reserve': 'En attente de délibération',
    'tres_favorable': 'Très favorable',
    'favorable': 'Favorable',
    'a_discuter': 'À discuter',
    'defavorable': 'Défavorable',
  };
  var saving = false;
  String? error;
  try {
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) {
              final complete = ratings.values.every((value) => value != null);
              final englishComplete =
                  !useEnglish || english.values.every((value) => value != null);
              final score = complete
                  ? _weights.entries.fold<double>(
                      0,
                      (total, entry) =>
                          total + ratings[entry.key]! * entry.value / 5,
                    )
                  : null;
              final englishScore = englishComplete && useEnglish
                  ? english.values.fold<int>(0, (s, v) => s + v!)
                  : null;
              return AlertDialog(
                title: Text('Évaluation collective · $candidateName'),
                content: SizedBox(
                  width: 680,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Une seule note commune est enregistrée au nom du jury. '
                          'Elle peut être saisie par un juré désigné. '
                          'La décision finale reste distincte du score.',
                        ),
                        if (!canEdit)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Cette note collective a déjà un saisisseur désigné. Adressez-vous aux responsables pour toute correction.'),
                          ),
                        const SizedBox(height: 12),
                        for (final entry in _criteria.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DropdownButtonFormField<int?>(
                              key: ValueKey('collective-${entry.key}'),
                              isExpanded: true,
                              initialValue: ratings[entry.key],
                              decoration: InputDecoration(
                                labelText: entry.value,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('Non évalué')),
                                for (var i = 1; i <= 5; i++)
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text('$i / 5'),
                                  ),
                              ],
                              onChanged: saving || !canEdit
                                  ? null
                                  : (value) =>
                                        update(() => ratings[entry.key] = value),
                            ),
                          ),
                        Text(
                          score == null
                              ? 'Score général non calculé — critères à compléter'
                              : 'Score général : ${score.toStringAsFixed(0)} / 100',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Divider(height: 26),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: useEnglish,
                          title: const Text('Évaluer également l’anglais'),
                          subtitle: const Text(
                            'Score distinct sur 25, sans incidence automatique sur le classement.',
                          ),
                          onChanged: saving || !canEdit
                              ? null
                              : (value) => update(() => useEnglish = value),
                        ),
                        if (useEnglish)
                          for (final entry in _english.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: DropdownButtonFormField<int?>(
                                key: ValueKey('english-${entry.key}'),
                                initialValue: english[entry.key],
                                decoration: InputDecoration(
                                  labelText: entry.value,
                                  border: const OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(value: null, child: Text('Non évalué')),
                                  for (var i = 1; i <= 5; i++)
                                    DropdownMenuItem(
                                      value: i,
                                      child: Text('$i / 5'),
                                    ),
                                ],
                                onChanged: saving || !canEdit
                                    ? null
                                    : (value) => update(
                                        () => english[entry.key] = value,
                                      ),
                              ),
                            ),
                        if (useEnglish)
                          Text(englishScore == null
                              ? 'Anglais : évaluation partielle'
                              : 'Anglais : $englishScore / 25'),
                        const SizedBox(height: 8),
                        for (final data in [
                          ('Points forts observés', strengths),
                          ('Points de vigilance', vigilance),
                          ('Potentiel de progression', potential),
                          ('Pôle recommandé', pole),
                          ('Justification de la recommandation', justification),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: TextField(
                              controller: data.$2,
                              maxLines: data.$2 == justification ? 3 : 2,
                              decoration: InputDecoration(
                                labelText: data.$1,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        DropdownButtonFormField<String>(
                          initialValue: recommendations.containsKey(recommendation)
                              ? recommendation
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Appréciation du jury',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final choice in recommendations.entries)
                              DropdownMenuItem(
                                value: choice.key,
                                child: Text(choice.value),
                              ),
                          ],
                          onChanged: saving || !canEdit
                              ? null
                              : (value) =>
                                    update(() => recommendation = value ?? recommendation),
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: saving || !canEdit
                        ? null
                        : () async {
                            update(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              await api.putJson(
                                endpoint,
                                token: token,
                                data: {
                                  'ratings': {
                                    for (final entry in ratings.entries)
                                      entry.key: entry.value,
                                  },
                                  'english': useEnglish
                                      ? {
                                          for (final entry in english.entries)
                                            entry.key: entry.value,
                                        }
                                      : null,
                                  'strengths': strengths.text.trim(),
                                  'vigilance': vigilance.text.trim(),
                                  'potential': potential.text.trim(),
                                  'recommended_pole': pole.text.trim(),
                                  'justification': justification.text.trim(),
                                  'recommendation': recommendation,
                                },
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } catch (_) {
                              update(() {
                                saving = false;
                                error = 'Impossible d’enregistrer la note collective.';
                              });
                            }
                          },
                    child: const Text('Enregistrer la note du jury'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;
  } finally {
    strengths.dispose();
    vigilance.dispose();
    potential.dispose();
    pole.dispose();
    justification.dispose();
  }
}
