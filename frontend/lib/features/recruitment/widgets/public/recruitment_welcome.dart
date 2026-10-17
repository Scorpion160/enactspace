import 'package:flutter/material.dart';
import '../../../../shared/ui/heritage_photo.dart';

class RecruitmentLandingHero extends StatelessWidget {
  final bool hasCampaigns;
  final VoidCallback onDiscover;
  final VoidCallback onTrack;
  final Widget? campaignPanel;
  final Key? actionKey;
  const RecruitmentLandingHero({super.key, required this.hasCampaigns,
    required this.onDiscover, required this.onTrack, this.campaignPanel, this.actionKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900 && MediaQuery.textScalerOf(context).scale(16) <= 24;
      final copy = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextButton.icon(onPressed: onTrack, icon: const Icon(Icons.search_rounded),
          label: const Text('Suivre ma candidature'), style: TextButton.styleFrom(alignment: Alignment.centerLeft)),
        const SizedBox(height: 16),
        Text('REJOINDRE ENACTUS ESP', style: theme.textTheme.labelLarge?.copyWith(
          color: dark ? const Color(0xFFFFDE7A) : const Color(0xFF775500), fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('Tes idées.\nNotre énergie.', style: theme.textTheme.headlineLarge?.copyWith(
          fontSize: wide ? 46 : 34, fontWeight: FontWeight.w900, height: 1.05)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.only(bottom: 5),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFFFD34D), width: 5))),
          child: Text('Un impact ensemble.', style: theme.textTheme.headlineLarge?.copyWith(fontSize: wide ? 46 : 34, fontWeight: FontWeight.w900, height: 1.1)),
        ),
        const SizedBox(height: 16),
        const Text('Apprends, imagine et agis avec une équipe engagée auprès des communautés.',
          style: TextStyle(fontSize: 16, height: 1.5)),
        const SizedBox(height: 20),
        if (campaignPanel != null) campaignPanel!
        else if (hasCampaigns)
          FilledButton.icon(
            key: actionKey,
            onPressed: onDiscover,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD34D), foregroundColor: const Color(0xFF211B0B)),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Choisir ma campagne'),
          )
        else
          Text('Les prochaines candidatures seront annoncées ici.',
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      ]);
      final photo = _LandingPhotoComposition(wide: wide);
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(flex: 5, child: copy), const SizedBox(width: 32), Expanded(flex: 6, child: photo),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        copy, const SizedBox(height: 20), photo,
      ]);
    });
  }
}

class _LandingPhotoComposition extends StatelessWidget {
  final bool wide;
  const _LandingPhotoComposition({required this.wide});
  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned(top: 0, right: 0, child: Container(
      width: wide ? 180 : 110, height: 160,
      decoration: BoxDecoration(color: const Color(0xFFFFD34D), borderRadius: BorderRadius.circular(32)),
    )),
    Padding(padding: EdgeInsets.fromLTRB(0, 12, 14, wide ? 110 : 0), child: HeritagePhoto(
      photo: const HeritagePhotoData('resources/hafe-collectif-2022', 'Enactus ESP et les communautés à Haffé, en 2022.'),
      height: wide ? 360 : 220,
    )),
    if (wide) Positioned(bottom: 0, right: 0, child: SizedBox(width: 270,
      child: Card(elevation: 4, child: Padding(padding: const EdgeInsets.all(6), child: HeritagePhoto(
        photo: const HeritagePhotoData('haffe-2025-ecoute', 'Des idées qui prennent vie sur le terrain.'), height: 145,
      ))),
    )),
  ]);
}

class RecruitmentWelcome extends StatelessWidget {
  const RecruitmentWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const stories = [
      ('Agir avec les communautés', 'Écoute les personnes concernées et construis avec elles des réponses à leurs besoins.',
        HeritagePhotoData('haffe-2025-ecoute', 'À Haffé, écouter pour mieux comprendre.')),
      ('Donner vie à tes idées', 'Propose, teste et fais évoluer des projets au contact du terrain.',
        HeritagePhotoData('dimbali-gie-favec', 'Dimbali et les femmes du GIE FAVEC.')),
      ('Apprendre en équipe', 'Développe tes compétences et partage des expériences avec les enacteurs et enactrices.',
        HeritagePhotoData('polytech-innovation-2025', 'Polytech Innovation, en 2025.')),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Une aventure à vivre ensemble', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      const Text('Découvre ce que tu peux vivre à Enactus ESP.', style: TextStyle(height: 1.5)),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 && MediaQuery.textScalerOf(context).scale(16) <= 24 ? 3 : 1;
        final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (final story in stories)
            SizedBox(width: width, child: _LandingStory(
              title: story.$1, text: story.$2, photo: story.$3, horizontal: columns == 1,
            )),
        ]);
      }),
      const SizedBox(height: 30),
      Text('Comment ça se passe ?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      const _JourneyStep(number: '01', title: 'Raconte-nous ton parcours',
        text: 'Choisis une campagne ouverte et complète ta candidature. Relis tes réponses avant de les envoyer.'),
      const _JourneyStep(number: '02', title: 'L’équipe étudie ton dossier',
        text: 'Ton dossier est examiné par les personnes chargées du recrutement. Les prochaines étapes dépendent de la campagne.'),
      const _JourneyStep(number: '03', title: 'Suis les prochaines étapes',
        text: 'Conserve ton code de suivi pour consulter les informations et les éventuelles invitations à un entretien.'),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
        child: Text('Ton envie d’agir fait la différence. Pas besoin d’expérience associative pour te lancer.', style: TextStyle(color: theme.colorScheme.onSecondaryContainer, height: 1.5, fontWeight: FontWeight.w600))),
      const SizedBox(height: 24),
      Text('Avant de te lancer', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      const Card(child: Column(children: [
        _WelcomeQuestion(title: 'Faut-il déjà avoir une expérience associative ?',
          answer: 'Non. Tes expériences dans les études, la famille, un petit projet ou le quotidien comptent aussi. Des réponses simples et sincères nous aident à te connaître.'),
        _WelcomeQuestion(title: 'Quels documents préparer ?',
          answer: 'Prépare tes coordonnées, ton niveau d’études et ton département. Tu peux joindre un CV, une lettre de motivation ou une réalisation : ces documents sont facultatifs.'),
        _WelcomeQuestion(title: 'Comment mon dossier est-il étudié ?',
          answer: 'Le jury regarde cinq critères de même poids : ton envie d’agir avec les communautés, ta manière de comprendre un besoin, ton initiative et tes apprentissages, ta coopération, et l’engagement que tu peux tenir avec tes études. La longueur de tes réponses ne donne pas de points. Les évaluations sont faites par des personnes, qui prennent la décision après discussion.'),
        _WelcomeQuestion(title: 'Comment retrouver ma candidature ?',
          answer: 'Après l’envoi, conserve le code de suivi affiché. Utilise « Suivre ma candidature » avec les informations demandées pour consulter son avancement.'),
      ])),
    ]);
  }
}

class _JourneyStep extends StatelessWidget {
  final String number, title, text;
  const _JourneyStep({required this.number, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ExcludeSemantics(child: Text(number, style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800))),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6), Text(text, style: const TextStyle(height: 1.5)),
      ])),
    ]),
  );
}

class _WelcomeQuestion extends StatelessWidget {
  final String title, answer;
  const _WelcomeQuestion({required this.title, required this.answer});
  @override
  Widget build(BuildContext context) => ExpansionTile(
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    children: [Text(answer, style: const TextStyle(height: 1.6))],
  );
}

class _LandingStory extends StatelessWidget {
  final String title, text;
  final HeritagePhotoData photo;
  final bool horizontal;
  const _LandingStory({required this.title, required this.text, required this.photo, required this.horizontal});
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: LayoutBuilder(builder: (context, constraints) {
      final compact = horizontal && constraints.maxWidth >= 310 && MediaQuery.textScalerOf(context).scale(16) <= 24;
      final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), Text(text, style: const TextStyle(height: 1.5)),
      ]);
      if (compact) {
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: 115, child: HeritagePhoto(photo: photo, height: 105)),
          const SizedBox(width: 14), Expanded(child: copy),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HeritagePhoto(photo: photo, height: horizontal ? 145 : 160),
        const SizedBox(height: 14), copy,
      ]);
    }),
  ));
}
