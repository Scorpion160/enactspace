import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TeamWorkspaceTools extends StatelessWidget {
  final String name;
  final String? poleId;
  final String? projectId;
  const TeamWorkspaceTools({
    super.key,
    required this.name,
    this.poleId,
    this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    final scope = Uri(
      queryParameters: {'pole_id': ?poleId, 'project_id': ?projectId},
    ).query;
    final tools = [
      (
        'Tâches',
        'Organiser les actions et remettre le travail.',
        Icons.task_alt_rounded,
        '/tasks?$scope',
      ),
      (
        'Engagements',
        'Convenir des résultats et des formations utiles.',
        Icons.flag_outlined,
        '/veille?$scope&tab=plans',
      ),
      (
        'Blocages',
        'Partager une difficulté et préparer une aide.',
        Icons.handshake_outlined,
        '/veille?$scope&tab=blockers',
      ),
      (
        'Bilans',
        'Faire le point et préparer la passation.',
        Icons.insights_rounded,
        '/veille?$scope&tab=reports',
      ),
      (
        'Documents',
        'Retrouver les documents de l’équipe.',
        Icons.folder_outlined,
        '/documents?$scope',
      ),
      (
        'Événements',
        'Préparer les rencontres et les activités.',
        Icons.event_outlined,
        '/events?$scope',
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Travailler ensemble · $name',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ouvre un outil avec le pôle ou le projet déjà sélectionné. Les droits de chaque personne restent ceux de son équipe.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth < 550 ||
                        MediaQuery.textScalerOf(context).scale(16) > 24
                    ? 1
                    : constraints.maxWidth < 900
                    ? 2
                    : 3;
                final width =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final tool in tools)
                      SizedBox(
                        width: width,
                        child: Card(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            onTap: () => context.push(tool.$4),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    tool.$3,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    tool.$1,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    tool.$2,
                                    style: const TextStyle(height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
