import 'package:flutter/material.dart';

const demoInk = Color(0xFF102C3A);
const demoTeal = Color(0xFF007F86);
const demoGold = Color(0xFFFFCE62);

class DemoPanel extends StatelessWidget {
  const DemoPanel({super.key, required this.child, this.padding = 20});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}

class DemoTitle extends StatelessWidget {
  const DemoTitle(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class DemoGrid extends StatelessWidget {
  const DemoGrid({
    super.key,
    required this.children,
    this.minimum = 280,
    this.maximumColumns = 3,
  });
  final List<Widget> children;
  final double minimum;
  final int maximumColumns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = (constraints.maxWidth / (minimum * scale.clamp(1, 2)))
          .floor()
          .clamp(1, maximumColumns);
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class DemoPhoto extends StatelessWidget {
  const DemoPhoto(this.asset, {super.key, this.height = 190, this.label});
  final String asset;
  final double height;
  final String? label;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.asset(
      asset,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      semanticLabel: label,
      errorBuilder: (_, error, stack) => SizedBox(
        height: height,
        child: const ColoredBox(
          color: Color(0xFF234C56),
          child: Center(
            child: Icon(
              Icons.landscape_outlined,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ),
    ),
  );
}

class DemoHero extends StatelessWidget {
  const DemoHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.action,
    required this.onAction,
    this.asset = 'assets/heritage/world-cup-2022-delegation.jpg',
  });
  final String eyebrow, title, description, action, asset;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth > 800 &&
          MediaQuery.textScalerOf(context).scale(14) < 24;
      final copy = Padding(
        padding: EdgeInsets.all(wide ? 32 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: demoGold,
                letterSpacing: 1.2,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                height: 1.14,
                fontSize: wide ? 38 : 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: const TextStyle(color: Color(0xFFD4E6E8), height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: demoGold,
                foregroundColor: demoInk,
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(action),
            ),
          ],
        ),
      );
      final photo = Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) =>
                const ColoredBox(color: demoTeal),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC102C3A)],
              ),
            ),
          ),
          const Positioned(
            left: 18,
            right: 18,
            bottom: 16,
            child: Text(
              'L’esprit Enactus ESP, d’une génération à l’autre.',
              style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [demoInk, Color(0xFF145E67)]),
          ),
          child: wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: copy),
                      Expanded(flex: 2, child: photo),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 180, child: photo),
                    copy,
                  ],
                ),
        ),
      );
    },
  );
}

IconData demoIcon(String id) => switch (id) {
  'home' => Icons.space_dashboard_outlined,
  'archives' => Icons.photo_library_outlined,
  'alumni' => Icons.diversity_2_outlined,
  'projects' => Icons.rocket_launch_outlined,
  'recruitment' => Icons.how_to_reg_outlined,
  'academy' => Icons.school_outlined,
  'chat' => Icons.chat_bubble_outline_rounded,
  'posts' => Icons.dynamic_feed_outlined,
  'events' => Icons.event_outlined,
  'meetings' => Icons.video_camera_front_outlined,
  'members' => Icons.badge_outlined,
  'impact' => Icons.insights_outlined,
  'settings' => Icons.tune_rounded,
  'tasks' => Icons.task_alt_rounded,
  'documents' => Icons.description_outlined,
  'finance' => Icons.account_balance_wallet_outlined,
  'attendance' => Icons.how_to_reg_outlined,
  'poles' => Icons.groups_outlined,
  'veille' => Icons.track_changes_outlined,
  'games' => Icons.emoji_events_outlined,
  'notifications' => Icons.notifications_none_rounded,
  'profile' => Icons.person_outline_rounded,
  _ => Icons.explore_outlined,
};
