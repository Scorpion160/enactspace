import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/brand/brand_assets.dart';
import '../services/app_info_provider.dart';

class AboutScreen extends StatelessWidget {
  final AppInfoProvider infoProvider;

  AboutScreen({super.key, AppInfoProvider? infoProvider})
    : infoProvider = infoProvider ?? PackageAppInfoProvider();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Image.asset(BrandAssets.logoFull, height: 92),
                        const SizedBox(height: 20),
                        Text(
                          'EnactSpace',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'L’impact en mouvement',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text('Enactus ESP'),
                        const SizedBox(height: 20),
                        FutureBuilder<AppInfo>(
                          future: infoProvider.load(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(snapshot.data!.display);
                            }
                            if (snapshot.hasError) {
                              return const Text('Version indisponible');
                            }
                            return const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                        ),
                        const Divider(height: 36),
                        const Text(
                          'V1 conçue et développée par Chicodev — 2026',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text('Maintenance : Pôle IT — Enactus ESP'),
                        const SizedBox(height: 20),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('Politique de confidentialité'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/legal/privacy'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.gavel_outlined),
                          title: const Text('Conditions d’utilisation'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/legal/terms'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
