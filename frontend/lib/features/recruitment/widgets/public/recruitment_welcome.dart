import 'package:flutter/material.dart';

import '../../../../shared/ui/heritage_photo.dart';

class RecruitmentWelcome extends StatelessWidget {
  const RecruitmentWelcome({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Et si ta prochaine aventure commençait ici ?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'À Enactus ESP, nous partons à la rencontre des communautés, nous cherchons à comprendre leurs besoins et nous construisons des solutions avec elles. Tu peux apporter ton regard, apprendre avec une équipe et transformer une idée en action.',
                style: TextStyle(height: 1.65, fontSize: 16),
              ),
              const SizedBox(height: 20),
              const HeritagePhoto(
                photo: HeritagePhotoData(
                  'world-cup-2018-delegation',
                  'Enactus ESP à la World Cup 2018 : une aventure portée par toute une équipe.',
                ),
                height: 250,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final stories = [
            (
              'Rencontrer et comprendre',
              'Une immersion commence par l’écoute. Tu apprends à poser les bonnes questions et à construire avec les personnes concernées.',
              const HeritagePhotoData(
                'haffe-2025-ecoute',
                'À Haffé, le dialogue ouvre le travail de terrain.',
              ),
            ),
            (
              'Créer avec les communautés',
              'Avec Dimbali, le travail se construit au plus près des femmes du GIE FAVEC. Les projets donnent du sens à ce que tu apprends.',
              const HeritagePhotoData(
                'dimbali-gie-favec',
                'Dimbali et les femmes du GIE FAVEC.',
              ),
            ),
            (
              'Grandir dans une équipe',
              'Brainstorming, formations, projets et présentations : tu avances avec d’autres enacteurs et enactrices, en partageant tes idées et tes responsabilités.',
              const HeritagePhotoData(
                'haffe-2025-parcelles',
                'Le travail de terrain accompagne le développement de Terrasen.',
              ),
            ),
          ];
          final columns =
              constraints.maxWidth < 680 ||
                  MediaQuery.textScalerOf(context).scale(16) > 24
              ? 1
              : 3;
          final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final story in stories)
                SizedBox(
                  width: width,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HeritagePhoto(photo: story.$3, height: 170),
                          const SizedBox(height: 14),
                          Text(
                            story.$1,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(story.$2, style: const TextStyle(height: 1.6)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      const Text(
        'Tu n’as pas besoin d’avoir déjà tout accompli. Raconte-nous ce qui t’anime, ce que tu aimerais apprendre et comment tu souhaites contribuer. Prends le temps de répondre avec tes mots.',
        style: TextStyle(height: 1.6, fontSize: 16),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comment ton dossier est étudié',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                'Le jury regarde cinq critères : ton envie d’agir avec les communautés, '
                'ta manière de comprendre un besoin, ton initiative et tes apprentissages, '
                'ta coopération, et l’engagement que tu peux tenir avec tes études. '
                'Chaque critère a le même poids.',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 10),
              const Text(
                'Les exemples du quotidien comptent aussi. Une expérience associative '
                'n’est pas indispensable ; la longueur de tes réponses ne donne pas de points. '
                'Les évaluations sont faites par des personnes, qui prennent la décision après discussion.',
                style: TextStyle(height: 1.6),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}
