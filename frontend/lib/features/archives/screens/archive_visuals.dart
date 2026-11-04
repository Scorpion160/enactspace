import 'package:flutter/material.dart';

enum ArchiveMotif {
  binder('classeur', Icons.inventory_2_outlined),
  minute('minute', Icons.auto_stories_outlined),
  award('distinction', Icons.emoji_events_outlined),
  media('phototheque', Icons.photo_library_outlined);

  const ArchiveMotif(this.asset, this.icon);
  final String asset;
  final IconData icon;
}

class ArchiveTheme extends StatelessWidget {
  const ArchiveTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    final colors = base.colorScheme.copyWith(
      primary: dark ? const Color(0xFF68D8D9) : const Color(0xFF00666C),
      onPrimary: dark ? const Color(0xFF101920) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF193744)
          : const Color(0xFFDDEFEA),
      onPrimaryContainer: dark
          ? const Color(0xFFF4F7FA)
          : const Color(0xFF103947),
      secondaryContainer: dark
          ? const Color(0xFF30281E)
          : const Color(0xFFFAF0D9),
      onSecondaryContainer: dark
          ? const Color(0xFFF6DFB3)
          : const Color(0xFF47361A),
      surface: dark ? const Color(0xFF17222D) : Colors.white,
      surfaceContainerLow: dark
          ? const Color(0xFF17222D)
          : const Color(0xFFF9F7F1),
      surfaceContainerHighest: dark
          ? const Color(0xFF223340)
          : const Color(0xFFE8EEE9),
      onSurface: dark ? const Color(0xFFF4F7FA) : const Color(0xFF101920),
      onSurfaceVariant: dark
          ? const Color(0xFFBAC7D5)
          : const Color(0xFF52616C),
      outlineVariant: dark ? const Color(0xFF344351) : const Color(0xFFD9DEDC),
    );
    final paper = dark ? const Color(0xFF0C1218) : const Color(0xFFF6F4EE);
    return Theme(
      data: base.copyWith(
        colorScheme: colors,
        scaffoldBackgroundColor: paper,
        textTheme: base.textTheme.apply(
          bodyColor: colors.onSurface,
          displayColor: colors.onSurface,
        ),
        cardTheme: base.cardTheme.copyWith(
          color: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFC72C),
            foregroundColor: const Color(0xFF101920),
            minimumSize: const Size(44, 44),
          ),
        ),
      ),
      child: ColoredBox(color: paper, child: child),
    );
  }
}

class ArchiveIllustration extends StatelessWidget {
  const ArchiveIllustration({super.key, required this.motif});
  final ArchiveMotif motif;

  @override
  Widget build(BuildContext context) {
    final tone = Theme.of(context).brightness == Brightness.dark
        ? 'sombre'
        : 'clair';
    return Image.asset(
      'assets/heritage/illustrations/${motif.asset}-$tone.png',
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => ExcludeSemantics(
        child: Icon(motif.icon, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class ArchiveBanner extends StatelessWidget {
  const ArchiveBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.motif,
    this.actions,
  });

  final String eyebrow;
  final String title;
  final String description;
  final ArchiveMotif motif;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF4F7FA) : const Color(0xFF101920);
    final secondary = dark ? const Color(0xFFBDE1E4) : const Color(0xFF40515D);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF17222D), Color(0xFF103947)]
              : const [Color(0xFFFAF0D9), Color(0xFFF6E6BF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: dark
                      ? const Color(0xFF68D8D9)
                      : const Color(0xFF00666C),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style:
                      (wide
                              ? theme.textTheme.headlineMedium
                              : theme.textTheme.headlineSmall)
                          ?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w900,
                          ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: secondary, height: 1.45),
              ),
              if (actions != null) ...[const SizedBox(height: 14), actions!],
            ],
          );
          if (wide) {
            return Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 20),
                SizedBox(
                  width: 188,
                  height: 128,
                  child: ArchiveIllustration(motif: motif),
                ),
              ],
            );
          }
          return Stack(
            children: [
              if (MediaQuery.textScalerOf(context).scale(1) <= 1.3)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Opacity(
                    opacity: 0.14,
                    child: SizedBox(
                      width: 94,
                      height: 74,
                      child: ArchiveIllustration(motif: motif),
                    ),
                  ),
                ),
              SizedBox(width: double.infinity, child: text),
            ],
          );
        },
      ),
    );
  }
}

class ArchivePlaceholder extends StatelessWidget {
  const ArchivePlaceholder({super.key, required this.motif, this.label});
  final ArchiveMotif motif;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 84, child: ArchiveIllustration(motif: motif)),
          if (label != null)
            Text(
              label!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
        ],
      ),
    );
  }
}

/// Preserve the whole photograph, including inscriptions on the trophies.
class HeritageImage extends StatelessWidget {
  final String asset;
  final String title;
  final bool interactive;
  const HeritageImage({
    super.key,
    required this.asset,
    required this.title,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).width < 600 ? 220 : 260,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            cacheWidth: 1200,
            semanticLabel: title,
            errorBuilder: (_, _, _) => const Center(
              child: ArchivePlaceholder(
                motif: ArchiveMotif.media,
                label: 'Image indisponible',
              ),
            ),
          ),
        ),
      ),
    );
    if (!interactive) return picture;
    return Semantics(
      button: true,
      label: 'Agrandir $title',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text(title),
                leading: IconButton(
                  tooltip: 'Fermer la photo',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    semanticLabel: title,
                  ),
                ),
              ),
            ),
          ),
        ),
        child: picture,
      ),
    );
  }
}

/// Natural-height cards wrap without fixed heights or horizontal scrolling.
class ResponsiveArchiveGrid extends StatelessWidget {
  final List<Widget> children;
  const ResponsiveArchiveGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
      final columns = largeText
          ? (width >= 1100 ? 2 : 1)
          : (width >= 1100 ? 3 : (width >= 700 ? 2 : 1));
      final cardWidth = (width - 16 * (columns - 1)) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          for (final child in children)
            SizedBox(width: cardWidth, child: child),
        ],
      );
    },
  );
}
