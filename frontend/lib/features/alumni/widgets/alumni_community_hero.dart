import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared visual identity for the real alumni directory and the public demo.
class AlumniCommunityHero extends StatelessWidget {
  const AlumniCommunityHero({
    super.key,
    required this.total,
    required this.mentors,
    required this.activeMentorships,
    required this.onMemories,
    this.actions = const [],
    this.showHeritagePhoto = true,
  });
  final int total;
  final int mentors;
  final int activeMentorships;
  final VoidCallback onMemories;
  final List<Widget> actions;
  final bool showHeritagePhoto;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 780;
      final content = Padding(
        padding: EdgeInsets.all(wide ? 34 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ENACTUS ESP · GÉNÉRATIONS EN LIEN',
              style: TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Une histoire commune.\nDes liens pour la vie.',
              style: TextStyle(
                color: Colors.white,
                fontSize: wide ? 34 : 26,
                height: 1.16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Les projets nous rassemblent. La transmission nous fait grandir. '
              'Retrouvez les générations du club et continuez à écrire la suite.',
              style: TextStyle(color: Color(0xFFD4E8EA), height: 1.6),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                for (final stat in [
                  ('$total', 'profils'),
                  ('$mentors', 'mentors disponibles'),
                  ('$activeMentorships', 'mentorats actifs'),
                ])
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        stat.$2,
                        style: const TextStyle(
                          color: Color(0xFFB9D4D9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD166),
                    foregroundColor: const Color(0xFF102B36),
                  ),
                  onPressed: onMemories,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Retrouver nos souvenirs'),
                ),
                ...actions,
              ],
            ),
          ],
        ),
      );
      final theme = Theme.of(context);
      final mode = theme.brightness == Brightness.dark ? 'sombre' : 'clair';
      final artwork = Image.asset(
        'assets/heritage/alumni-generations-$mode.png',
        fit: BoxFit.contain,
        alignment: Alignment.bottomRight,
        excludeFromSemantics: true,
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C2836), Color(0xFF125764)],
            ),
          ),
          child: wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: content),
                      Expanded(
                        flex: 2,
                        child: showHeritagePhoto
                            ? const _AlumniMemoriesPhoto()
                            : artwork,
                      ),
                    ],
                  ),
                )
              : showHeritagePhoto
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 190, child: _AlumniMemoriesPhoto()),
                    content,
                  ],
                )
              : Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      right: 0,
                      width: constraints.maxWidth * 0.62,
                      child: Opacity(opacity: 0.20, child: artwork),
                    ),
                    content,
                  ],
                ),
        ),
      );
    },
  );
}

class AlumniMemoriesCard extends StatelessWidget {
  const AlumniMemoriesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 210, child: _AlumniMemoriesPhoto()),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('World Cup 2022', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Retrouve les photos et les récits de cette édition dans les Archives.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        Uri(
                          path: '/archives',
                          queryParameters: {'search': 'World Cup 2022'},
                        ).toString(),
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Ouvrir les Archives'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlumniMemoriesPhoto extends StatelessWidget {
  const _AlumniMemoriesPhoto();

  @override
  Widget build(BuildContext context) {
    final mode = Theme.of(context).brightness == Brightness.dark
        ? 'sombre'
        : 'clair';
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/heritage/world-cup-2022-emotion.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(0, .25),
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => ColoredBox(
            color: const Color(0xFF214C57),
            child: Image.asset(
              'assets/heritage/alumni-phototheque-$mode.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xE6092734)],
            ),
          ),
        ),
        const Positioned(
          left: 20,
          right: 20,
          bottom: 18,
          child: Text(
            'Des moments qu’on n’oublie pas.\nPhotothèque Enactus ESP · World Cup 2022',
            style: TextStyle(color: Colors.white, height: 1.5, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
