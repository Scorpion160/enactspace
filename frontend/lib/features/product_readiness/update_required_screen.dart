import 'package:flutter/material.dart';

import '../../core/brand/brand_assets.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final Uri? storeUri;
  final VoidCallback? onUpdate;
  final VoidCallback onRetry;
  final bool checking;
  final bool launching;
  final bool launchFailed;

  const UpdateRequiredScreen({
    super.key,
    required this.storeUri,
    required this.onUpdate,
    required this.onRetry,
    this.checking = false,
    this.launching = false,
    this.launchFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    final unavailable = storeUri == null;
    final explanation = launchFailed
        ? 'Impossible d’ouvrir la boutique pour le moment. Vérifiez votre connexion puis réessayez.'
        : unavailable
        ? 'Le lien officiel de mise à jour n’est pas disponible. Veuillez vérifier à nouveau.'
        : 'Installez la dernière version d’EnactSpace pour continuer.';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        BrandAssets.icon512,
                        width: 88,
                        height: 88,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.system_update_rounded, size: 64),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Mise à jour requise',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(explanation, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      if (!unavailable)
                        FilledButton.icon(
                          key: const Key('product-readiness-update'),
                          onPressed: launching ? null : onUpdate,
                          icon: launching
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.open_in_new_rounded),
                          label: const Text('Mettre à jour'),
                        ),
                      if (!unavailable) const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('product-readiness-check-again'),
                        onPressed: checking ? null : onRetry,
                        icon: checking
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: const Text('Vérifier à nouveau'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
