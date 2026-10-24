import 'package:flutter/material.dart';

import 'demo_session.dart';
import 'demo_widgets.dart';

const demoPoles = [
  (
    'Tech',
    'Pôle cœur',
    'Concevoir, fabriquer et tester les solutions techniques.',
    Icons.handyman_outlined,
  ),
  (
    'Chimie',
    'Pôle cœur',
    'Étudier les procédés, les formulations et les matériaux.',
    Icons.science_outlined,
  ),
  (
    'Gestion',
    'Pôle cœur',
    'Construire le modèle économique et organiser le suivi.',
    Icons.business_center_outlined,
  ),
  (
    'IT',
    'Pôle cœur',
    'Développer les outils et les solutions numériques.',
    Icons.code_rounded,
  ),
  (
    'Communication',
    'Pôle support',
    'Faire connaître les projets et raconter la vie du club.',
    Icons.campaign_outlined,
  ),
  (
    'Organisation',
    'Pôle support',
    'Préparer les rencontres, la logistique et les activités.',
    Icons.event_note_outlined,
  ),
  (
    'Veille',
    'Pôle support',
    'Suivre les engagements et partager les opportunités.',
    Icons.track_changes_rounded,
  ),
];

class DemoPolesPanel extends StatelessWidget {
  const DemoPolesPanel({
    super.key,
    required this.session,
    required this.onTasks,
  });
  final DemoSession session;
  final VoidCallback onTasks;

  void _detail(BuildContext context, (String, String, String, IconData) pole) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pôle ${pole.$1}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(pole.$3, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 18),
                  const Text(
                    'Une équipe, plusieurs contributions.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Awa Démo · Coordination\nMoussa Démo · Équipe\nFatou Démo · Équipe\n\nMembres fictifs pour illustrer une fiche de pôle.',
                    style: TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Feuille de route d’exemple\n1. Préparer l’activité\n2. Répartir les tâches\n3. Mettre en commun les résultats',
                    style: TextStyle(height: 1.7),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onTasks();
              },
              child: const Text('Essayer le suivi des tâches'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoTitle(
        'Des compétences qui se rencontrent.',
        'Quatre pôles cœur et trois pôles support. Explorez leurs missions et leurs équipes fictives, puis essayez une demande de participation.',
      ),
      DemoGrid(
        children: [
          for (final pole in demoPoles)
            DemoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    pole.$4,
                    size: 38,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    pole.$1,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pole.$2,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(pole.$3, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    key: ValueKey('demo-pole-${pole.$1}'),
                    onPressed: () => _detail(context, pole),
                    child: const Text('Découvrir l’équipe et les missions'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        session.toggle(session.poleRequests, pole.$1),
                    icon: Icon(
                      session.poleRequests.contains(pole.$1)
                          ? Icons.check_circle_outline
                          : Icons.person_add_alt_1_outlined,
                    ),
                    label: Text(
                      session.poleRequests.contains(pole.$1)
                          ? 'Demande simulée · Annuler'
                          : 'Essayer une demande de participation',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 18),
      const Text(
        'Dans le compte réel, l’affectation aux pôles et les actions de gestion suivent les droits de chaque rôle. Les demandes ci-dessus ne sont envoyées à personne.',
        style: TextStyle(height: 1.6),
      ),
    ],
  );
}
