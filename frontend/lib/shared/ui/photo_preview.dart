import 'package:flutter/material.dart';

class PhotoPreviewTap extends StatelessWidget {
  final ImageProvider<Object>? image;
  final String title;
  final Widget child;

  const PhotoPreviewTap({
    super.key,
    required this.image,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (image == null) return child;
    return Tooltip(
      message: 'Agrandir la photo',
      child: Semantics(
        container: true,
        button: true,
        label: 'Agrandir la photo de $title',
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => showDialog<void>(
            context: context,
            useSafeArea: false,
            builder: (context) => Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    tooltip: 'Fermer la photo',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                body: SizedBox.expand(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Image(
                      image: image!,
                      fit: BoxFit.contain,
                      semanticLabel: 'Photo de $title',
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stack) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'La photo ne peut pas être chargée pour le moment.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
