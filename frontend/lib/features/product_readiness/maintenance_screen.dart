import 'package:flutter/material.dart';

import '../../core/brand/brand_assets.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final bool checking;

  const MaintenanceScreen({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onPrivacy,
    required this.onTerms,
    this.checking = false,
  });

  @override
  Widget build(BuildContext context) {
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
                            const Icon(Icons.hub_rounded, size: 64),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Service temporairement indisponible',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('product-readiness-retry'),
                        onPressed: checking ? null : onRetry,
                        icon: checking
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: const Text('Réessayer'),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: onPrivacy,
                            child: const Text('Politique de confidentialité'),
                          ),
                          TextButton(
                            onPressed: onTerms,
                            child: const Text('Conditions d’utilisation'),
                          ),
                        ],
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
