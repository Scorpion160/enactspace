import 'package:flutter/material.dart';

/// An adaptive heading: decoration never competes with the question or its input.
class PublicApplicationJourney extends StatelessWidget {
  final String campaignTitle;
  final int currentStep;
  final List<String> titles;
  const PublicApplicationJourney({
    super.key,
    required this.campaignTitle,
    required this.currentStep,
    required this.titles,
  });

  static const _icons = [
    Icons.waving_hand_outlined,
    Icons.school_outlined,
    Icons.lightbulb_outline_rounded,
    Icons.event_available_outlined,
    Icons.attach_file_rounded,
    Icons.fact_check_outlined,
  ];
  static const _messages = [
    'Tes idées peuvent faire bouger les choses.',
    'Chaque parcours apporte quelque chose à l’équipe.',
    'Ce qui t’anime nous intéresse.',
    'Trouvons la place de cet engagement dans ton quotidien.',
    'Une autre façon de raconter ton parcours.',
    'Un dernier regard, et à toi de jouer !',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 400 ? 20 : 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF29271E), Color(0xFF20242A)]
                  : const [Color(0xFFFFF5CE), Color(0xFFFFFCF2)],
            ),
            border: Border.all(color: dark ? const Color(0xFF665B32) : const Color(0xFFE9D899)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF483E20) : const Color(0xFFFFE69B),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(_icons[currentStep], color: dark ? const Color(0xFFFFD65A) : const Color(0xFF624500), size: 28),
                    ),
                  ),
                  Text('REJOINDRE ENACTUS ESP', softWrap: true,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: dark ? const Color(0xFFFFDE7A) : const Color(0xFF624500),
                      fontWeight: FontWeight.w800,
                    )),
                ],
              ),
              const SizedBox(height: 18),
              Text(_messages[currentStep],
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface, fontWeight: FontWeight.w800, height: 1.2,
                )),
              const SizedBox(height: 10),
              Text(campaignTitle, style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant, height: 1.5,
              )),
              if (currentStep == 0) ...[
                const SizedBox(height: 12),
                Text('Raconte-nous qui tu es, ce qui te motive et ce que tu aimerais construire avec l’équipe.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurface, height: 1.5)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Étape ${currentStep + 1} sur ${titles.length}',
                style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(titles[currentStep],
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Progression des étapes',
          value: '${currentStep + 1} sur ${titles.length}',
          child: Row(
            children: List.generate(titles.length, (index) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == titles.length - 1 ? 0 : 6),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: reducedMotion ? 0 : 180),
                  height: 6,
                  decoration: BoxDecoration(
                    color: index <= currentStep ? colors.primary : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )),
          ),
        ),
        const SizedBox(height: 12),
        Text(currentStep == 5
            ? 'Tu peux encore modifier chaque rubrique avant l’envoi.'
            : 'Tu peux revenir aux étapes précédentes : tes réponses restent en place.',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.5)),
      ],
    );
  }
}

class PublicApplicationQuestionCard extends StatelessWidget {
  final int number;
  final int total;
  final bool requiredAnswer;
  final Widget child;
  const PublicApplicationQuestionCard({
    super.key,
    required this.number,
    required this.total,
    required this.requiredAnswer,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('Question $number sur $total', style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant, fontWeight: FontWeight.w700,
              )),
              Text(requiredAnswer ? 'Nécessaire pour continuer' : 'Facultatif',
                style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
