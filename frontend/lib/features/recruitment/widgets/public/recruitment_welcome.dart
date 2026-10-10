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
                'Une rencontre sur le terrain, une idée qui prend forme, une équipe qui avance ensemble : voilà ce que tu peux vivre à Enactus ESP. Nous construisons avec les communautés des projets qui répondent à leurs besoins. Apporte ta curiosité, partage tes idées et prends part à l’aventure.',
                style: TextStyle(height: 1.65, fontSize: 16),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) => HeritagePhoto(
                  photo: const HeritagePhotoData(
                    'resources/hafe-collectif-2022',
                    'À Haffé en 2022, Enactus ESP et les communautés réunis autour des projets et du partage.',
                  ),
                  height: constraints.maxWidth * 3 / 4,
                ),
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
              'Écouter pour mieux agir',
              'Sur le terrain, tu rencontres les personnes concernées, tu écoutes leurs expériences et tu poses tes questions. Ces échanges t’aident à comprendre leurs besoins avant d’imaginer une solution avec elles.',
              const HeritagePhotoData(
                'haffe-2025-ecoute',
                'À Haffé, prendre le temps d’écouter et de comprendre.',
              ),
            ),
            (
              'Donner vie aux idées',
              'Avec Dimbali et les femmes du GIE FAVEC, les idées se construisent au contact du terrain. Tu apprends à proposer, à tester et à faire évoluer un projet avec les personnes qui l’utiliseront.',
              const HeritagePhotoData(
                'dimbali-gie-favec',
                'Dimbali et les femmes du GIE FAVEC.',
              ),
            ),
            (
              'Trouver ta place dans l’équipe',
              'Une idée à partager, une présentation à préparer, un défi à relever ensemble : chacun apporte sa contribution. Au fil des formations et des projets, tu développes tes compétences et tu crées des liens avec d’autres enacteurs et enactrices.',
              const HeritagePhotoData(
                'polytech-innovation-2025',
                'Enactus ESP réuni à Polytech Innovation en 2025.',
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
                          Text(
                            story.$1,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 14),
                          HeritagePhoto(
                            photo: story.$3,
                            height: (width - 36) * 3 / 4,
                          ),
                          const SizedBox(height: 14),
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
        'Ta candidature commence par ton histoire. Raconte-nous ce qui te motive, une initiative dont tu es fier ou fière, et ce que tu aimerais apprendre avec nous. Des exemples simples et sincères nous aideront à mieux te connaître.',
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
