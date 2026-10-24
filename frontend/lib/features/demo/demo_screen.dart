import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/project_presentation.dart';
import '../../shared/ui/project_reference_documents.dart';
import '../alumni/widgets/alumni_community_hero.dart';
import 'demo_session.dart';
import 'demo_widgets.dart';

class DemoLoginEntry extends StatelessWidget {
  const DemoLoginEntry({super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ALUMNI DAY · BIENVENUE CHEZ VOUS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'L’histoire continue avec vous.',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Explorez EnactSpace en Enacteur ou en Alumni. Sans compte, à votre rythme.',
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.go('/demo'),
          icon: const Icon(Icons.explore_outlined),
          label: const Text('Découvrir la démo'),
        ),
      ],
    ),
  );
}

/// Public, intentionally self-contained: no API client, token, device permission,
/// notification, payment SDK or persistent store is reachable from this screen.
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key, this.profile, this.initialSection = 'home'});
  final DemoProfile? profile;
  final String initialSection;
  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  late DemoSession session;
  late String section;
  bool? dark;
  String query = '';
  String year = 'Tout';
  late final Future<List<Map<String, dynamic>>> memories;
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    session = DemoSession(widget.profile ?? DemoProfile.alumni)
      ..addListener(_refresh);
    section = _safeSection(widget.initialSection);
    memories = rootBundle
        .loadString('assets/img/alumni_day_heritage.json')
        .then(
          (raw) => (jsonDecode(raw) as List)
              .map((value) => Map<String, dynamic>.from(value as Map))
              .toList(),
        );
  }

  String _safeSection(String value) =>
      modulesFor(widget.profile ?? DemoProfile.alumni)
          .any((module) => module.id == value)
      ? value
      : 'home';

  @override
  void didUpdateWidget(DemoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      session.removeListener(_refresh);
      session.dispose();
      session = DemoSession(widget.profile ?? DemoProfile.alumni)
        ..addListener(_refresh);
      section = _safeSection(widget.initialSection);
      query = '';
      year = 'Tout';
    } else if (oldWidget.initialSection != widget.initialSection) {
      section = _safeSection(widget.initialSection);
      if (scroll.hasClients) scroll.jumpTo(0);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    session.removeListener(_refresh);
    session.dispose();
    scroll.dispose();
    super.dispose();
  }

  void navigate(String value) {
    setState(() {
      section = _safeSection(value);
      query = '';
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void notice(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: demoTeal,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
    final theme = Theme.of(context).copyWith(
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colors,
      textTheme: Theme.of(context).textTheme
          .apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0B1823)
          : const Color(0xFFF5F7F8),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
      ),
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final wide = MediaQuery.sizeOf(context).width >= 1050;
          return Scaffold(
            appBar: AppBar(
              leading: widget.profile == null
                  ? BackButton(onPressed: () => context.go('/login'))
                  : wide
                  ? const Icon(Icons.explore_outlined)
                  : Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        tooltip: 'Toutes les rubriques',
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
              title: Text(
                widget.profile == null
                    ? 'Découvrir EnactSpace'
                    : 'Démo · ${session.profile.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: isDark ? 'Passer en clair' : 'Passer en sombre',
                  onPressed: () => setState(() => dark = !isDark),
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
                if (widget.profile != null)
                  PopupMenuButton<String>(
                    tooltip: 'Changer de parcours',
                    onSelected: (value) => context.go('/demo/$value'),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'enacteur',
                        child: Text('Parcours Enacteur'),
                      ),
                      const PopupMenuItem(
                        value: 'alumni',
                        child: Text('Parcours Alumni'),
                      ),
                    ],
                  ),
                IconButton(
                  tooltip: 'Quitter la démo',
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            drawer: widget.profile == null || wide
                ? null
                : Drawer(
                    child: SafeArea(child: _navigation(context, drawer: true)),
                  ),
            body: widget.profile == null
                ? _entry(context)
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        color: colors.secondaryContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        child: Text(
                          'Démonstration · Données d’exemple · Vos essais restent dans cette visite.',
                          style: TextStyle(
                            color: colors.onSecondaryContainer,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            if (wide)
                              SizedBox(width: 244, child: _navigation(context)),
                            Expanded(
                              child: SingleChildScrollView(
                                key: const ValueKey('demo-content-scroll'),
                                controller: scroll,
                                padding: EdgeInsets.all(wide ? 28 : 16),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1240,
                                    ),
                                    child: _content(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            bottomNavigationBar: widget.profile == null || wide
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceAround,
                        spacing: 4,
                        children: [
                          for (final id in [
                            'home',
                            'archives',
                            'academy',
                            'chat',
                          ])
                            TextButton.icon(
                              onPressed: () => navigate(id),
                              icon: Icon(demoIcon(id), size: 19),
                              label: Text(switch (id) {
                                'home' => 'Accueil',
                                'archives' => 'Souvenirs',
                                'academy' => 'Academy',
                                _ => 'Chat',
                              }, style: const TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _navigation(BuildContext context, {bool drawer = false}) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EnactSpace',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'L’impact en héritage.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            for (final module in modulesFor(session.profile))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: ListTile(
                  dense: true,
                  selected: section == module.id,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(demoIcon(module.id), size: 21),
                  title: Text(module.title),
                  onTap: () {
                    if (drawer) Navigator.pop(context);
                    navigate(module.id);
                  },
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(14),
        child: OutlinedButton.icon(
          onPressed: () => context.go(
            '/demo/${session.profile == DemoProfile.alumni ? 'enacteur' : 'alumni'}',
          ),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Changer de parcours'),
        ),
      ),
    ],
  );

  Widget _entry(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DemoHero(
              eyebrow: 'ALUMNI DAY · ENACTUS ESP',
              title: 'Vous avez écrit l’histoire.\nVenez découvrir la suite.',
              description:
                  'Les générations changent, l’élan reste. '
                  'Explorez l’application imaginée pour apprendre, agir ensemble et garder notre mémoire vivante.',
              action: 'Retrouver les souvenirs du club',
              onAction: () => context.go('/demo/alumni?section=archives'),
              asset: 'assets/heritage/world-cup-2022-emotion.jpg',
            ),
            const SizedBox(height: 26),
            const DemoTitle(
              'Choisissez votre point de vue.',
              'Deux parcours libres, sans inscription. '
                  'Les profils et les activités sont fictifs ; les photos d’archives proviennent de la photothèque du club.',
            ),
            DemoGrid(
              minimum: 360,
              maximumColumns: 2,
              children: [
                _profileChoice(
                  context,
                  DemoProfile.enacteur,
                  'Apprendre. S’engager. Construire.',
                  'Academy, projets, discussions, tâches, documents, cotisations et vie du club.',
                  'assets/heritage/immersion-mars-2025.jpg',
                ),
                _profileChoice(
                  context,
                  DemoProfile.alumni,
                  'Retrouver. Transmettre. Inspirer.',
                  'Souvenirs, réseau Alumni, mentorat, événements et échanges entre générations.',
                  'assets/heritage/world-cup-2018-delegation.jpg',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const DemoPanel(
              child: Text(
                'Tout essayer, simplement. Les messages, inscriptions, '
                'brouillons et paiements de démonstration sont simulés. Aucun message n’est envoyé '
                'et aucun paiement n’est déclenché.',
                style: TextStyle(height: 1.6),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _profileChoice(
    BuildContext context,
    DemoProfile profile,
    String title,
    String description,
    String image,
  ) => DemoPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoPhoto(image),
        const SizedBox(height: 18),
        Text(
          profile.label.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(description, style: const TextStyle(height: 1.6)),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: ValueKey('demo-enter-${profile.name}'),
          onPressed: () => context.go('/demo/${profile.name}'),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text('Explorer en ${profile.label}'),
        ),
      ],
    ),
  );

  Widget _content(BuildContext context) => switch (section) {
    'home' => _home(context),
    'archives' => _archives(context),
    'alumni' => _alumni(context),
    'academy' => _academy(context),
    'chat' => _chat(context),
    'projects' => _projects(context),
    'tasks' => _tasks(context),
    'finance' => _finance(context),
    'documents' => _documents(context),
    'events' => _events(context),
    'posts' => _posts(context),
    'profile' => _profile(context),
    'notifications' => _notifications(context),
    'games' => _games(context),
    _ => _other(context),
  };

  Widget _home(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DemoHero(
        eyebrow:
            'VOTRE PARCOURS ${session.profile.label.toUpperCase()} · DÉMONSTRATION',
        title: session.profile == DemoProfile.alumni
            ? 'Toujours Enactus.\nToujours ensemble.'
            : 'Vos idées ont\nun terrain d’action.',
        description: session.profile == DemoProfile.alumni
            ? 'Retrouvez les moments qui vous ont marqués. Découvrez ce que les nouvelles générations construisent et comment continuer à transmettre.'
            : 'Apprenez, retrouvez votre équipe et faites avancer les projets. Explorez les outils qui donnent vie à l’engagement.',
        action: 'Ouvrir la capsule souvenirs',
        onAction: () => navigate('archives'),
      ),
      const SizedBox(height: 22),
      const DemoTitle(
        'Une visite à votre image.',
        'Commencez par un souvenir, une idée ou une rencontre.',
      ),
      DemoGrid(
        children: [
          _shortcut(
            context,
            'archives',
            'La mémoire du club',
            '40 photos publiques pour revivre les immersions, les compétitions et les projets.',
          ),
          _shortcut(
            context,
            'academy',
            'Apprendre pour agir',
            'Essayez une leçon puis un quiz. Votre progression évolue pendant la visite.',
          ),
          _shortcut(
            context,
            session.profile == DemoProfile.alumni ? 'alumni' : 'projects',
            session.profile == DemoProfile.alumni
                ? 'Passer le relais'
                : 'Du terrain à l’impact',
            session.profile == DemoProfile.alumni
                ? 'Découvrez les profils fictifs et simulez une proposition de mentorat.'
                : 'Découvrez les projets et leurs dossiers de présentation.',
          ),
        ],
      ),
      const SizedBox(height: 26),
      const DemoTitle(
        'Tout ce que vous pouvez explorer.',
        'Les rubriques correspondent au parcours choisi. Changez de profil pour découvrir l’autre regard.',
      ),
      DemoGrid(
        minimum: 245,
        children: [
          for (final module in modulesFor(
            session.profile,
          ).where((m) => m.id != 'home'))
            _shortcut(context, module.id, module.title, module.description),
        ],
      ),
    ],
  );

  Widget _shortcut(
    BuildContext context,
    String id,
    String title,
    String description,
  ) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => navigate(id),
      child: DemoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              demoIcon(id),
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(height: 1.6)),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _archives(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DemoHero(
        eyebrow: 'LA CAPSULE SOUVENIRS · ALUMNI DAY',
        title: 'Vous y étiez.\nOu vous en avez hérité.',
        description:
            'Derrière chaque projet, des visages, des rencontres et des moments partagés. '
            'Ouvrez une photo, retrouvez son histoire et gardez vos coups de cœur pendant la visite.',
        action: 'Partager un souvenir · essai',
        onAction: () => _contribute(context),
        asset: 'assets/heritage/world-cup-2022-emotion.jpg',
      ),
      const SizedBox(height: 22),
      TextField(
        key: const ValueKey('demo-archive-search'),
        onChanged: (value) => setState(() => query = value),
        decoration: const InputDecoration(
          labelText: 'Rechercher un projet, une année, un souvenir',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in [
            'Tout',
            '2016',
            '2018',
            '2020',
            '2021',
            '2022',
            '2025',
            'Favoris',
          ])
            ChoiceChip(
              label: Text(value),
              selected: year == value,
              onSelected: (_) => setState(() => year = value),
            ),
        ],
      ),
      const SizedBox(height: 18),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: memories,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const DemoPanel(
              child: Text(
                'Les photos n’ont pas pu être chargées. Revenez à l’accueil puis réessayez.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!.where((row) {
            final matches =
                '${row['title']} ${row['description']} ${row['year'] ?? ''}'
                    .toLowerCase()
                    .contains(query.toLowerCase());
            return matches &&
                (year == 'Tout' ||
                    year == 'Favoris' &&
                        session.savedMemories.contains(row['id']) ||
                    row['year']?.toString() == year);
          }).toList();
          if (rows.isEmpty) {
            return const DemoPanel(
              child: Text(
                'Aucun souvenir avec ce filtre. Essayez une autre année ou ajoutez un favori.',
              ),
            );
          }
          return DemoGrid(
            minimum: 280,
            children: [for (final row in rows) _memoryCard(context, row)],
          );
        },
      ),
      if (session.contributions.isNotEmpty) ...[
        const SizedBox(height: 24),
        const DemoTitle(
          'Vos souvenirs · essai local',
          'Ces textes disparaîtront à la fin de la visite.',
        ),
        for (final text in session.contributions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DemoPanel(
              child: Text(text, style: const TextStyle(height: 1.6)),
            ),
          ),
      ],
    ],
  );

  Widget _memoryCard(BuildContext context, Map<String, dynamic> row) =>
      DemoPanel(
        padding: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: ValueKey('memory-${row['id']}'),
              onTap: () => _openMemory(context, row),
              child: DemoPhoto(
                row['image_asset'] as String,
                label: row['title'] as String,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['year']?.toString() ?? 'Photothèque',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          row['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Garder ce souvenir pendant la visite',
                    onPressed: () => session.toggle(
                      session.savedMemories,
                      row['id'] as String,
                    ),
                    icon: Icon(
                      session.savedMemories.contains(row['id'])
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openMemory(context, row),
              child: const Text('Revivre ce moment'),
            ),
          ],
        ),
      );

  void _openMemory(
    BuildContext context,
    Map<String, dynamic> row,
  ) => showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: Text(row['title'] as String)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 420,
                    child: InteractiveViewer(
                      child: Image.asset(
                        row['image_asset'] as String,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    row['description'] as String,
                    style: const TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    'Source : ${row['source_label'] ?? 'Photothèque Enactus ESP'}'
                    '${row['source_url'] == null ? '' : '\n${row['source_url']}'}',
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _contribute(BuildContext context) async {
    final text = await _textDialog(
      context,
      'Votre souvenir',
      'Une rencontre, un projet, un moment…',
      'Conserver dans cette démo',
    );
    if (mounted && text != null) session.addContribution(text);
  }

  Widget _alumni(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AlumniCommunityHero(
        total: 3,
        mentors: session.mentoring ? 3 : 2,
        activeMentorships: 1,
        onMemories: () => navigate('archives'),
      ),
      const SizedBox(height: 22),
      const DemoTitle(
        'Un réseau qui transmet.',
        'Profils fictifs pour essayer l’annuaire et le mentorat. Aucune coordonnée réelle n’est affichée.',
      ),
      DemoPanel(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Je souhaite transmettre mon expérience'),
          subtitle: const Text(
            'Proposition de mentorat simulée pendant cette visite.',
          ),
          value: session.mentoring,
          onChanged: session.setMentoring,
        ),
      ),
      const SizedBox(height: 18),
      DemoGrid(
        children: [
          for (final profile in [
            ('Awa Démo', 'Énergie & transition', '2018', 'AD'),
            ('Moussa Démo', 'Entrepreneuriat & gestion', '2020', 'MD'),
            ('Fatou Démo', 'Numérique & innovation', '2022', 'FD'),
          ])
            DemoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 28, child: Text(profile.$4)),
                  const SizedBox(height: 16),
                  Text(
                    profile.$1,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(profile.$2),
                  const SizedBox(height: 8),
                  Text('Promotion ${profile.$3} · Profil fictif'),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _detail(
                      context,
                      profile.$1,
                      '${profile.$2}\n\nCe profil illustre les compétences, le parcours professionnel et la disponibilité pour le mentorat. '
                      'Une vraie prise de contact nécessite un compte et les droits associés.',
                      action: 'Proposer un échange · essai',
                      onAction: () async {
                        final text = await _textDialog(
                          context,
                          'Un sujet à partager',
                          'Quel accompagnement recherchez-vous ?',
                          'Simuler la proposition',
                        );
                        if (text != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Proposition simulée. Aucun message n’a été envoyé.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Découvrir le profil'),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );

  Widget _projects(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoTitle(
        'Des idées qui rencontrent le terrain.',
        'Découvrez les projets du club à travers leurs photos et dossiers de présentation.',
      ),
      DemoGrid(
        children: [
          for (final project in [
            ('Terrasen', 'assets/heritage/terrasen.jpg', 'terrasen'),
            ('Aquatus', 'assets/heritage/aquatus.jpg', 'aquatus'),
            ('Mën Nañ', 'assets/heritage/men-nan.jpg', 'men nan'),
            ('Shery', 'assets/heritage/shery.jpg', 'shery'),
            ('Dimbali', 'assets/heritage/dimbali-gie-favec.jpg', 'dimbali'),
          ])
            DemoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DemoPhoto(project.$2),
                  const SizedBox(height: 16),
                  Text(
                    project.$1,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Des équipes, des besoins réels et une démarche collective. '
                    'Le dossier de référence permet de distinguer objectifs et résultats documentés.',
                    style: TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () => _project(context, project.$1, project.$3),
                    child: const Text('Ouvrir le projet'),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );

  void _project(BuildContext context, String title, String key) {
    final documents = _projectDocuments(key);
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Les dossiers du projet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 18),
                    if (documents.isNotEmpty)
                      ProjectReferenceDocuments(documents: documents)
                    else
                      const Text(
                        'Retrouvez les photos de ce projet dans la capsule souvenirs.',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _academy(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DemoHero(
        eyebrow: 'ENACTSPACE ACADEMY · ESSAI INTERACTIF',
        title: 'Apprendre pour agir.',
        description: 'Explorez une leçon, testez vos connaissances et voyez votre progression évoluer.',
        action: 'Commencer la première leçon',
        onAction: () => _lesson(
          context,
          'ecouter',
          'Écouter avant de proposer',
          'Une solution utile commence par une écoute attentive.\n\n1. Rencontrez les personnes concernées.\n'
              '2. Observez leurs usages, leurs contraintes et leurs ressources.\n3. Reformulez le besoin avec elles.\n'
              '4. Testez une première idée, puis demandez un retour.\n\nExemple : avant de concevoir un outil, '
              'vérifiez qu’il peut être utilisé, entretenu et financé dans le contexte réel.',
        ),
        asset: 'assets/heritage/haffe-2025-ecoute.jpg',
      ),
      const SizedBox(height: 20),
      DemoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${session.completedLessons.length}/3 leçons · ${session.points} points de démonstration',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: session.completedLessons.length / 3),
          ],
        ),
      ),
      const SizedBox(height: 20),
      DemoGrid(
        children: [
          for (final lesson in [
            (
              'ecouter',
              'Écouter avant de proposer',
              'Écouter les personnes concernées, observer et reformuler le besoin.',
            ),
            (
              'construire',
              'Construire avec les communautés',
              'Co-construire : associer les personnes concernées aux choix, au test et à l’amélioration de la solution.',
            ),
            (
              'mesurer',
              'Mesurer ce qui change',
              'Distinguez ce que l’équipe réalise des changements observés. Une formation organisée est une activité ; une compétence acquise est un résultat à vérifier.',
            ),
          ])
            DemoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    session.completedLessons.contains(lesson.$1)
                        ? Icons.check_circle
                        : Icons.menu_book_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lesson.$2,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text('Leçon découverte · 2 min'),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () =>
                        _lesson(context, lesson.$1, lesson.$2, lesson.$3),
                    child: Text(
                      session.completedLessons.contains(lesson.$1)
                          ? 'Relire'
                          : 'Ouvrir la leçon',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 22),
      FilledButton.icon(
        key: const ValueKey('demo-open-quiz'),
        onPressed: () => _quiz(context),
        icon: const Icon(Icons.quiz_outlined),
        label: Text(
          session.quizPassed
              ? 'Quiz réussi · Rejouer'
              : 'Essayer le quiz découverte',
        ),
      ),
    ],
  );

  void _lesson(BuildContext context, String id, String title, String text) =>
      _detail(
        context,
        title,
        text,
        action: session.completedLessons.contains(id)
            ? 'Leçon déjà terminée'
            : 'Terminer cette leçon',
        onAction: () {
          session.completeLesson(id);
          Navigator.pop(context);
        },
      );

  void _quiz(BuildContext context) {
    int? selected;
    bool submitted = false;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Une idée utile commence par…'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, answer) in [
                    'Choisir une technologie à la mode',
                    'Écouter les personnes concernées',
                    'Annoncer des résultats sans mesure',
                  ].indexed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        selected == index
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text(answer),
                      onTap: submitted
                          ? null
                          : () => update(() => selected = index),
                    ),
                  if (submitted)
                    Text(
                      selected == 1
                          ? 'Bien joué ! Le besoin se comprend avec les personnes concernées.'
                          : 'La bonne réponse est : écouter les personnes concernées. La solution vient ensuite.',
                      style: const TextStyle(height: 1.6),
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
            if (!submitted)
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () {
                        update(() => submitted = true);
                        if (selected == 1) session.passQuiz();
                      },
                child: const Text('Vérifier ma réponse'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chat(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoTitle(
        'Les idées circulent.',
        'Conversation fictive · Aucun message n’est envoyé à une personne réelle.',
      ),
      DemoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
              title: const Text('Générations en lien'),
              subtitle: const Text('Groupe de démonstration'),
              trailing: IconButton(
                tooltip: 'Informations et médias partagés',
                icon: const Icon(Icons.info_outline),
                onPressed: () => _detail(
                  context,
                  'Générations en lien',
                  'Une conversation pour se retrouver et transmettre.\n\n'
                      'Médias partagés : photo de la World Cup 2022.\nDocuments : dossiers des projets.\n'
                      'Dans l’application, les informations du groupe regroupent membres, médias, liens et documents.',
                  action: 'Voir les photos',
                  onAction: () {
                    Navigator.pop(context);
                    navigate('archives');
                  },
                ),
              ),
            ),
            const Divider(),
            _bubble(
              context,
              'Awa · profil fictif',
              'Quel plaisir de retrouver ces souvenirs ! Sur quoi travaille la nouvelle génération ?',
            ),
            _bubble(
              context,
              'Moussa · profil fictif',
              'Les projets et l’Academy sont à découvrir depuis le menu. Bienvenue chez vous !',
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 310,
                child: InkWell(
                  onTap: () => navigate('archives'),
                  child: const DemoPhoto(
                    'assets/heritage/world-cup-2022-delegation.jpg',
                    height: 180,
                  ),
                ),
              ),
            ),
            for (final text in session.messages)
              _bubble(context, 'Vous · essai local', text, mine: true),
            const SizedBox(height: 20),
            _DemoComposer(onSend: session.send),
          ],
        ),
      ),
    ],
  );

  Widget _bubble(
    BuildContext context,
    String author,
    String text, {
    bool mine = false,
  }) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 520),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: mine
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            author,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(height: 1.5)),
        ],
      ),
    ),
  );

  Widget _tasks(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoTitle(
        'Chaque petite avancée compte.',
        'Cochez une tâche pour essayer le suivi personnel. Les exemples restent dans cette visite.',
      ),
      DemoPanel(
        child: Column(
          children: [
            for (final task in [
              'Préparer le support de présentation',
              'Relire le dossier du projet',
              'Partager le compte rendu',
            ])
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(task),
                subtitle: const Text('Exemple · Équipe projet'),
                value: session.completedTasks.contains(task),
                onChanged: (_) => session.toggle(session.completedTasks, task),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text('${session.completedTasks.length}/3 tâches terminées dans la démo.'),
    ],
  );

  Widget _finance(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoTitle(
        'Mes cotisations, en toute clarté.',
        'Exemple fictif · Aucun opérateur de paiement n’est appelé et aucun argent n’est transféré.',
      ),
      DemoGrid(
        children: [
          _stat('Cotisation d’exemple', '1 000 FCFA'),
          _stat('Paiement simulé', '${session.simulatedPaid} FCFA'),
          _stat(
            'Reste dans cet exemple',
            '${1000 - session.simulatedPaid} FCFA',
          ),
        ],
      ),
      const SizedBox(height: 20),
      DemoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Un justificatif, un suivi, une confirmation.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Déclarer un paiement, joindre un reçu et suivre sa validation : '
              'les étapes sont regroupées dans votre espace. Le paiement en ligne sera proposé une fois son activation terminée.',
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('demo-simulate-payment'),
              onPressed: session.simulatedPaid == 0
                  ? session.simulatePayment
                  : null,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Simuler un paiement de 1 000 FCFA'),
            ),
            if (session.simulatedPaid > 0)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Simulation terminée. Aucun paiement réel effectué.',
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _stat(String label, String value) => DemoPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _documents(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoTitle(
        'Les bons documents, au bon endroit.',
        'Dossiers publics et brouillons d’exemple. Aucun document officiel n’est délivré par la démo.',
      ),
      DemoGrid(
        children: [
          for (final project in [
            ('Terrasen', 'terrasen'),
            ('Aquatus', 'aquatus'),
            ('Mën Nañ', 'men nan'),
            ('Shery', 'shery'),
          ])
            DemoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 32),
                  const SizedBox(height: 14),
                  Text(
                    'Dossier ${project.$1}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _project(context, project.$1, project.$2),
                    child: const Text('Lire le dossier public'),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => _draft(context),
        icon: const Icon(Icons.edit_document),
        label: const Text('Essayer un brouillon'),
      ),
      for (final document in session.documents)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DemoPanel(
            child: Text(document, style: const TextStyle(height: 1.6)),
          ),
        ),
    ],
  );

  void _draft(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => _DemoDraft(onSave: session.saveDocument),
  );

  Widget _events(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoTitle(
        'Se retrouver, pour de vrai.',
        'Calendrier illustratif · Les inscriptions ci-dessous sont simulées.',
      ),
      DemoGrid(
        children: [
          for (final event in [
            (
              'Retrouvailles des générations',
              'Échanger sur les projets et les souvenirs du club.',
              'assets/heritage/world-cup-2022-emotion.jpg',
            ),
            (
              'Atelier de transmission',
              'Un temps pour partager son expérience avec les équipes.',
              'assets/heritage/haffe-2025-rencontre.jpg',
            ),
            (
              'Préparer une immersion',
              'Observer les besoins avant de proposer une solution.',
              'assets/heritage/immersion-mars-2025.jpg',
            ),
          ])
            DemoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DemoPhoto(event.$3),
                  const SizedBox(height: 16),
                  Text(
                    event.$1,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(event.$2, style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 8),
                  const Text(
                    'Événement de démonstration · Aucune date annoncée',
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        session.toggle(session.joinedEvents, event.$1),
                    icon: Icon(
                      session.joinedEvents.contains(event.$1)
                          ? Icons.check_circle_outline
                          : Icons.event_available_outlined,
                    ),
                    label: Text(
                      session.joinedEvents.contains(event.$1)
                          ? 'Annuler mon essai d’inscription'
                          : 'Essayer l’inscription',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );

  Widget _posts(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoTitle(
        'La vie du club, en partage.',
        'Publications d’exemple, illustrées par la photothèque publique.',
      ),
      DemoGrid(
        maximumColumns: 2,
        children: [
          for (final post in [
            (
              'Un même élan, plusieurs générations',
              'L’Alumni Day est une occasion de se retrouver et de découvrir la suite de l’histoire.',
              'assets/heritage/world-cup-2022-emotion.jpg',
            ),
            (
              'Du terrain aux idées',
              'Écouter, rencontrer et construire ensemble : l’esprit qui traverse nos projets.',
              'assets/heritage/haffe-2025-ecoute.jpg',
            ),
          ])
            DemoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DemoPhoto(post.$3, height: 240),
                  const SizedBox(height: 16),
                  Text(
                    post.$1,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(post.$2, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            session.toggle(session.likedPosts, post.$1),
                        icon: Icon(
                          session.likedPosts.contains(post.$1)
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        label: Text(
                          session.likedPosts.contains(post.$1)
                              ? 'Vous aimez · démo'
                              : 'J’aime · démo',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final text = await _textDialog(
                            context,
                            'Un mot pour l’équipe',
                            'Votre commentaire d’exemple',
                            'Simuler le commentaire',
                          );
                          if (text != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Commentaire simulé. Aucun contenu publié.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Commenter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );

  Widget _profile(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DemoTitle(
        'Votre parcours a de la valeur.',
        'Profil ${session.profile.label} fictif · Aucun compte n’a été créé.',
      ),
      DemoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 34,
              child: Icon(Icons.person_outline, size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              session.profile == DemoProfile.alumni
                  ? 'Alumni · Profil découverte'
                  : 'Enacteur · Profil découverte',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            const Text(
              'Compétences : esprit d’équipe, curiosité, gestion de projet.\n'
              'Motivation : apprendre et contribuer à des solutions utiles.',
              style: TextStyle(height: 1.8),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(label: Text(session.profile.label)),
                Chip(label: Text('${session.points} points · démo')),
                if (session.quizPassed)
                  const Chip(
                    avatar: Icon(Icons.workspace_premium_outlined),
                    label: Text('Curiosité en action · démo'),
                  ),
                const Chip(label: Text('Profil fictif')),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => _detail(
                context,
                'Un profil pour se présenter',
                'Dans votre compte, vous pouvez compléter vos informations, présenter vos compétences et retrouver vos engagements. '
                    'La visibilité et les actions dépendent de votre rôle.',
              ),
              child: const Text('Comprendre le profil'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _notifications(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoTitle(
        'Ce qui mérite votre attention.',
        'Notifications fictives. Appuyez pour ouvrir la rubrique correspondante.',
      ),
      for (final item in [
        (
          'Un souvenir à redécouvrir',
          'La capsule souvenirs vous attend.',
          'archives',
        ),
        ('Une nouvelle leçon', 'Découvrez le quiz de l’Academy.', 'academy'),
        (
          'Un message pour les générations',
          'Retrouvez la discussion de démonstration.',
          'chat',
        ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DemoPanel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                session.readNotifications.contains(item.$1)
                    ? Icons.mark_email_read_outlined
                    : Icons.notifications_active_outlined,
              ),
              title: Text(item.$1),
              subtitle: Text(item.$2),
              onTap: () {
                session.markRead(item.$1);
                navigate(item.$3);
              },
            ),
          ),
        ),
    ],
  );

  Widget _games(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DemoTitle(
        'L’engagement se partage aussi en jouant.',
        'Aperçu des jeux et récompenses. Les points de cette visite sont fictifs.',
      ),
      DemoGrid(
        children: [
          _stat('Votre progression de visite', '${session.points} points'),
          _shortcut(
            context,
            'academy',
            'Un quiz pour commencer',
            'Essayez une question et gagnez un badge de démonstration.',
          ),
        ],
      ),
      const SizedBox(height: 20),
      DemoGrid(
        children: [
          for (final title in ['Undercover', 'Loup-garou', 'Icebreakers'])
            DemoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sports_esports_outlined, size: 36),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _detail(
                      context,
                      title,
                      'Les jeux du club permettent de se retrouver en groupe. Dans le compte réel, les sessions '
                      'et leurs participants se retrouvent depuis cette rubrique. Cette visite présente un aperçu sans ouvrir de session multijoueur.',
                      action: 'Essayer un brise-glace',
                      onAction: () => _detail(
                        context,
                        'À vous de jouer !',
                        'En une phrase, racontez une idée que vous avez changée après avoir écouté quelqu’un d’autre.',
                      ),
                    ),
                    child: const Text('Découvrir le jeu'),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );

  Widget _other(BuildContext context) {
    final module = demoModules.firstWhere((value) => value.id == section);
    final rows = switch (section) {
      'members' => [
        (
          'Awa Démo · Communication',
          'Compétences : rédaction, présentation et création de contenu.\nPôle : Communication.\nProfil fictif, sans coordonnées personnelles.',
        ),
        (
          'Moussa Démo · Équipe projet',
          'Compétences : conception, expérimentation et travail de terrain.\nLa fiche membre rassemble les informations autorisées selon votre rôle.\nProfil fictif.',
        ),
      ],
      'impact' => [
        (
          'De l’action au changement',
          'Exemple fictif : un atelier organisé, dix participations et une compétence à évaluer.\nOn distingue les activités réalisées, les résultats observés et les preuves disponibles.',
        ),
        (
          'Des résultats documentés',
          'Les équipes peuvent suivre des indicateurs et leurs justificatifs. Les vues de gestion et la validation restent réservées aux personnes habilitées dans le compte réel.\nAucun chiffre de démonstration ne représente un résultat du club.',
        ),
      ],
      'settings' => [
        (
          'Clair ou sombre, à votre rythme',
          'Utilisez le soleil ou la lune en haut de cette page pour essayer les deux ambiances. Le choix reste propre à cette visite.',
        ),
        (
          'Rester informé',
          'Dans votre compte, les préférences permettent de personnaliser les notifications. Cette démonstration n’active aucune notification et ne vous abonne à aucun service.',
        ),
      ],
      'meetings' => [
        (
          'Préparer une réunion',
          'Objet : transmission entre générations.\nOrdre du jour : souvenirs, projets, accompagnement.\n'
              'Dans EnactMeet, les personnes invitées retrouvent les informations et le lien de réunion.',
        ),
        (
          'Essayer le salon',
          'Aperçu de la réunion : micro, caméra, participants et partage d’écran. '
              'Cette démonstration ne demande pas l’accès à votre caméra ou à votre microphone et ne rejoint aucune réunion réelle.',
        ),
      ],
      'attendance' => [
        (
          'Mon historique',
          'Atelier d’équipe · Présent\nRéunion de projet · Présent\nImmersion · Présent\n\nHistorique fictif de participation.',
        ),
        (
          'Comment pointer ?',
          'Dans le compte réel, le pointage utilise les possibilités autorisées par le responsable de la session : QR code ou NFC selon le matériel et les droits.',
        ),
      ],
      'poles' => [
        (
          'Pôles cœur',
          'Tech · Chimie · Gestion · IT\nDes compétences complémentaires pour concevoir et réaliser les projets.',
        ),
        (
          'Pôles support',
          'Communication · Organisation · Veille\nCommuniquer, préparer les activités, accompagner et suivre les engagements.',
        ),
      ],
      'veille' => [
        (
          'Mes engagements',
          'Retrouvez les échéances, les tâches et les rappels qui vous concernent. '
              'Les informations de suivi restent soumises aux droits d’accès du compte.',
        ),
        (
          'Demander un accompagnement',
          'Expliquez votre difficulté, échangez avec les responsables et suivez les prochaines étapes.',
        ),
      ],
      _ => [
        (
          'Explorer sans compte',
          'Choisissez un parcours et utilisez le menu pour explorer les fonctionnalités. '
              'Les actions sont simulées et restent dans cette visite. Les photos et dossiers publics sont issus des ressources embarquées du club.',
        ),
        (
          'Créer son propre accès',
          'Après la visite, revenez à la connexion. Si votre profil existe déjà, utilisez Première connexion. '
              'Pour rejoindre le réseau, choisissez le parcours de création de compte adapté. Aucun compte n’est créé dans la démo.',
        ),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoTitle(module.title, module.description),
        DemoGrid(
          children: [
            for (final item in rows)
              DemoPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      demoIcon(section),
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.$1,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(item.$2, style: const TextStyle(height: 1.7)),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: () => _detail(context, item.$1, item.$2),
                      child: const Text('Voir les détails'),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (section == 'veille') ...[
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final text = await _textDialog(
                context,
                'Demande d’accompagnement · essai',
                'Décrivez votre besoin',
                'Simuler la demande',
              );
              if (text != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Demande simulée. Aucun responsable n’a été contacté.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Essayer une demande'),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.go(
            '/demo/${session.profile == DemoProfile.alumni ? 'enacteur' : 'alumni'}',
          ),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Explorer aussi l’autre parcours'),
        ),
      ],
    );
  }

  void _detail(
    BuildContext context,
    String title,
    String text, {
    String? action,
    VoidCallback? onAction,
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: SelectableText(text, style: const TextStyle(height: 1.7)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        if (action != null)
          FilledButton(onPressed: onAction, child: Text(action)),
      ],
    ),
  );

  Future<String?> _textDialog(
    BuildContext context,
    String title,
    String hint,
    String action,
  ) => showDialog<String>(
    context: context,
    builder: (_) => _DemoTextInput(title: title, hint: hint, action: action),
  );
}

class _DemoTextInput extends StatefulWidget {
  const _DemoTextInput({
    required this.title,
    required this.hint,
    required this.action,
  });
  final String title, hint, action;
  @override
  State<_DemoTextInput> createState() => _DemoTextInputState();
}

class _DemoTextInputState extends State<_DemoTextInput> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 500,
      child: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 6,
        maxLength: 1000,
        decoration: InputDecoration(
          labelText: widget.hint,
          helperText: 'Essai local · Aucun envoi ni publication.',
          helperMaxLines: 2,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (controller.text.trim().isNotEmpty) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: Text(widget.action),
      ),
    ],
  );
}

class _DemoComposer extends StatefulWidget {
  const _DemoComposer({required this.onSend});
  final ValueChanged<String> onSend;
  @override
  State<_DemoComposer> createState() => _DemoComposerState();
}

class _DemoComposerState extends State<_DemoComposer> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void send() {
    if (controller.text.trim().isEmpty) return;
    widget.onSend(controller.text);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: TextField(
          key: const ValueKey('demo-chat-input'),
          controller: controller,
          maxLength: 1000,
          minLines: 1,
          maxLines: 5,
          onSubmitted: (_) => send(),
          decoration: const InputDecoration(
            labelText: 'Écrire un message d’essai',
            counterText: '',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton.filled(
        key: const ValueKey('demo-chat-send'),
        tooltip: 'Envoyer dans cette démo',
        onPressed: send,
        icon: const Icon(Icons.send_rounded),
      ),
    ],
  );
}

class _DemoDraft extends StatefulWidget {
  const _DemoDraft({required this.onSave});
  final ValueChanged<String> onSave;
  @override
  State<_DemoDraft> createState() => _DemoDraftState();
}

class _DemoDraftState extends State<_DemoDraft> {
  final object = TextEditingController(
    text: 'Demande d’appui pour une activité',
  );
  final body = TextEditingController(
    text: 'Présenter le projet et préciser le besoin d’accompagnement.',
  );
  bool preview = false;
  @override
  void dispose() {
    object.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(preview ? 'Aperçu du brouillon' : 'Brouillon de démonstration'),
    content: SizedBox(
      width: 580,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'EXEMPLE · AUCUNE VALEUR OFFICIELLE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            if (preview) ...[
              Text(
                object.text,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Text(body.text),
            ] else ...[
              TextField(
                key: const ValueKey('demo-draft-subject'),
                controller: object,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Objet'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                minLines: 4,
                maxLines: 7,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Votre demande'),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
      OutlinedButton(
        onPressed: () => setState(() => preview = !preview),
        child: Text(preview ? 'Modifier' : 'Aperçu'),
      ),
      FilledButton(
        onPressed: () {
          if (object.text.trim().isEmpty || body.text.trim().isEmpty) return;
          widget.onSave('BROUILLON D’EXEMPLE\n${object.text}\n\n${body.text}');
          Navigator.pop(context);
        },
        child: const Text('Garder dans la démo'),
      ),
    ],
  );
}

List<ProjectReferenceDocument> _projectDocuments(String key) {
  final asset = switch (key) {
    'terrasen' => 'terrasen-world-cup.pdf',
    'aquatus' => 'aquatus-synthese.pdf',
    'men nan' => 'men-nan-presentation.pdf',
    'shery' => 'shery-presentation.pdf',
    _ => null,
  };
  if (asset == null) return const [];
  return [
    ProjectReferenceDocument(
      title: 'Présentation du projet',
      asset: 'assets/documents/$asset',
      description: 'Dossier de référence public embarqué dans EnactSpace.',
      filename: asset,
      pages: switch (key) {
        'terrasen' => 26,
        'aquatus' => 28,
        'men nan' => 9,
        'shery' => 10,
        _ => 0,
      },
    ),
  ];
}
