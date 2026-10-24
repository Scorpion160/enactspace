import 'package:flutter/material.dart';

/// Shared visual identity for the real alumni directory and the public demo.
class AlumniCommunityHero extends StatelessWidget {
  const AlumniCommunityHero({
    super.key,
    required this.total,
    required this.mentors,
    required this.activeMentorships,
    required this.onMemories,
    this.actions = const [],
  });
  final int total;
  final int mentors;
  final int activeMentorships;
  final VoidCallback onMemories;
  final List<Widget> actions;

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
      final photo = Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/heritage/world-cup-2022-emotion.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, .25),
            errorBuilder: (_, error, stack) =>
                const ColoredBox(color: Color(0xFF214C57)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC092734)],
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
                      Expanded(flex: 2, child: photo),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 190, child: photo),
                    content,
                  ],
                ),
        ),
      );
    },
  );
}
