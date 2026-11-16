import 'package:flutter/material.dart';

/// Recruitment jury kit adapted from "Kit du jury.docx" (2026–2027).
/// Keep common prompts consistent across candidates while allowing follow-ups.
Future<void> showRecruitmentJuryKit(BuildContext context) {
  const parts = <(String, String)>[
    ('0–1 min', 'Accueil et présentation'),
    ('1–4 min', 'Motivation et compréhension d’Enactus'),
    ('4–7 min', 'Initiative, leadership et équipe'),
    ('7–9 min', 'Mise en situation'),
    ('9–12 min', 'Séquence orale en anglais'),
    ('12–15 min', 'Disponibilités et conclusion'),
    ('15–20 min', 'Délibération et saisie de la note collective'),
  ];
  const questions = <String, List<String>>{
    'Motivation et compréhension': [
      'Présente-toi brièvement et parle-nous de ton parcours.',
      'Comment as-tu découvert Enactus et pourquoi souhaites-tu rejoindre Enactus ESP ?',
      'Que comprends-tu de la mission d’Enactus et de l’entrepreneuriat à impact ?',
      'Qu’aimerais-tu apporter à l’équipe et qu’espères-tu apprendre ?',
      'Qu’est-ce qui pourrait te motiver à rester engagé dans les périodes exigeantes ?',
    ],
    'Initiative et travail d’équipe': [
      'Raconte une situation où tu as pris une initiative.',
      'Parle-nous d’un travail de groupe auquel tu as contribué. Quel était ton rôle ?',
      'Comment réagis-tu lorsqu’un membre ne respecte pas ses engagements ?',
      'Comment accueilles-tu une critique constructive ou un désaccord ?',
      'Quel enseignement as-tu tiré d’un échec ou d’une difficulté ?',
    ],
    'Esprit entrepreneurial': [
      'Quel problème social ou environnemental aimerais-tu résoudre ?',
      'Comment transformerais-tu une idée en projet concret ?',
      'Quelles solutions proposerais-tu si ton équipe manque de moyens ?',
      'Comment vérifierais-tu qu’un projet produit un impact durable ?',
    ],
    'Mise en situation (choisir un cas)': [
      'Ton équipe travaille depuis deux mois, sans résultats satisfaisants. Que fais-tu ?',
      'Tu n’es pas d’accord avec ton responsable de pôle. Comment réagis-tu ?',
      'Un membre ne fait pas sa part du travail et l’échéance approche.',
      'Un examen important a lieu le lendemain d’une échéance Enactus.',
    ],
    'Disponibilité et engagement': [
      'Combien d’heures par semaine peux-tu raisonnablement consacrer à Enactus ?',
      'Quelles contraintes récurrentes l’équipe devra-t-elle connaître ?',
      'Comment préviendras-tu si tu ne peux pas respecter un engagement ?',
    ],
    'Anglais (3 minutes)': [
      'Could you briefly introduce yourself and tell us why you want to join Enactus ESP?',
      'What is one social or environmental problem in your community that you would like to help solve, and why?',
      'Imagine you are representing Enactus ESP at the Enactus World Cup. How would you explain the value of your project?',
    ],
  };
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Kit du jury · Enactus ESP'),
      content: SizedBox(
        width: 750,
        height: 520,
        child: ListView(
          children: [
            const Text(
              'Un même socle de questions pour tous les candidats. '
              '15 minutes d’entretien, puis 5 minutes de délibération. '
              'La grille du jury est collective ; le score d’anglais sur 25 '
              'est distinct du score général sur 100.',
            ),
            const SizedBox(height: 12),
            for (final item in parts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 105,
                      child: Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(child: Text(item.$2)),
                  ],
                ),
              ),
            const Divider(height: 24),
            for (final group in questions.entries)
              ExpansionTile(
                title: Text(group.key),
                children: [
                  for (var i = 0; i < group.value.length; i++)
                    ListTile(
                      dense: true,
                      leading: Text('${i + 1}.'),
                      title: Text(group.value[i]),
                    ),
                ],
              ),
            const Divider(),
            const Text(
              'Repères : écouter des preuves et exemples concrets, éviter les '
              'biais, respecter le niveau d’expérience du candidat et noter '
              'l’intelligibilité en anglais plutôt que son accent. '
              'La recommandation doit être justifiée.',
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}
