import 'package:flutter/material.dart';

class HeritagePhotoData {
  final String asset;
  final String caption;
  const HeritagePhotoData(this.asset, this.caption);
}

HeritagePhotoData? heritagePhotoFor(String subject) {
  final key = subject.toLowerCase();
  if (key.contains('dimbali')) {
    return const HeritagePhotoData(
      'dimbali-gie-favec',
      'Dimbali, au plus près des femmes du GIE FAVEC.',
    );
  }
  if (key.contains('deconaane')) {
    return const HeritagePhotoData(
      'deconaane-filtre',
      'Deconaane : une solution de filtration pensée pour les besoins du quotidien.',
    );
  }
  if (key.contains('terrasen')) {
    return const HeritagePhotoData(
      'haffe-2025-parcelles',
      'À Haffé, le travail de terrain accompagne le développement de Terrasen.',
    );
  }
  if (key.contains('shery')) {
    return const HeritagePhotoData(
      'shery',
      'Les personnes et leurs besoins restent au cœur de notre engagement.',
    );
  }
  if (key.contains('aquatus') || key.contains('aquapon')) {
    return const HeritagePhotoData(
      'aquatus',
      'Le dialogue avec les communautés nourrit les projets du club.',
    );
  }
  if (key.contains('mën nañ') ||
      key.contains('mën nan') ||
      key.contains('men nan')) {
    return const HeritagePhotoData(
      'niaguiss-2025-produits',
      'À Niaguiss, Mën Nañ poursuit son travail avec les communautés.',
    );
  }
  if (key.contains('immersion') ||
      key.contains('enquête') ||
      key.contains('ciblage')) {
    return const HeritagePhotoData(
      'haffe-2025-ecoute',
      'Écouter, rencontrer et comprendre : le projet commence sur le terrain.',
    );
  }
  if (key.contains('mentor') || key.contains('ndiaga')) {
    return const HeritagePhotoData(
      'professeur-ndiaga-ndiaye',
      'Professeur Ndiaga Ndiaye, un accompagnement qui continue d’inspirer Enactus ESP.',
    );
  }
  if (key.contains('présenter') || key.contains('compétition')) {
    return const HeritagePhotoData(
      'world-cup-2018-delegation',
      'La délégation d’Enactus ESP à la World Cup 2018.',
    );
  }
  return null;
}

/// Bundled photos remain readable offline and offer a full-size view on tap.
class HeritagePhoto extends StatelessWidget {
  final HeritagePhotoData photo;
  final double height;
  const HeritagePhoto({super.key, required this.photo, this.height = 240});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Agrandir la photo. ${photo.caption}',
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showDialog<void>(
              context: context,
              useSafeArea: false,
              builder: (context) => Dialog.fullscreen(
                child: Scaffold(
                  appBar: AppBar(title: const Text('Photothèque Enactus ESP')),
                  body: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4,
                            child: Center(
                              child: Image.asset(
                                'assets/heritage/${photo.asset}.jpg',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            photo.caption,
                            textAlign: TextAlign.center,
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/heritage/${photo.asset}.jpg',
                height: height,
                fit: BoxFit.cover,
                alignment: photo.asset == 'haffe-2025-parcelles'
                    ? Alignment.bottomCenter
                    : photo.asset.contains('delegation') ||
                          photo.asset == 'shery'
                    ? Alignment.topCenter
                    : Alignment.center,
                semanticLabel: photo.caption,
                errorBuilder: (context, error, stack) => Container(
                  height: height,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Text('La photo est momentanément indisponible.'),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          photo.caption,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 4),
        Text(
          'Source : Photothèque Enactus ESP',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
