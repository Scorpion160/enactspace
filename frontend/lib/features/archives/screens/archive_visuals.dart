import 'package:flutter/material.dart';

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
              child: Icon(Icons.image_not_supported_outlined, size: 40),
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
