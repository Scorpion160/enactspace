import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../recruitment/screens/application_tracking_screen.dart';
import '../recruitment/screens/public/public_application_flow_screen.dart';
import '../recruitment/screens/public/public_recruitment_campaigns_screen.dart';
import '../recruitment/widgets/public/public_application_field.dart';
import 'demo_recruitment_gateway.dart';
import 'demo_widgets.dart';

class DemoRecruitmentPanel extends StatelessWidget {
  const DemoRecruitmentPanel({super.key, required this.gateway});
  final DemoRecruitmentGateway gateway;

  void _open(BuildContext context, {bool tracking = false}) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      child: DemoRecruitmentExperience(
        gateway: gateway,
        initialLocation: tracking
            ? '/application-tracking'
            : '/recruitment/apply',
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: gateway,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DemoHero(
          eyebrow: 'RECRUTEMENT · DU PREMIER PAS À L’ACCUEIL',
          title: 'La prochaine génération\ncommence ici.',
          description: 'Essayez le véritable formulaire en six étapes, avec une campagne et un suivi fictifs. Retrouvez aussi le regard de l’équipe qui accompagne les candidatures.',
          action: 'Essayer le parcours candidat',
          onAction: () => _open(context),
          asset: 'assets/heritage/immersion-mars-2025.jpg',
        ),
        const SizedBox(height: 20),
        DemoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suivre une candidature d’exemple',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const SelectableText(
                'Code : ${DemoRecruitmentGateway.code}\nE-mail d’exemple : ${DemoRecruitmentGateway.email}',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 8),
              const Text(
                'Après un essai du formulaire, utilisez l’e-mail fictif saisi pendant cet essai. Aucun e-mail n’est envoyé.',
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const ValueKey('demo-track-application'),
                onPressed: () => _open(context, tracking: true),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Essayer le suivi'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const DemoTitle(
          'Côté équipe : accompagner chaque candidature.',
          'Dossiers fictifs · Les actions de gestion sont réservées aux responsables dans le compte réel. Ici, changez un statut pour voir le suivi évoluer sans convocation ni création de compte.',
        ),
        DemoGrid(
          children: [
            for (final entry in gateway.statuses.entries)
              DemoPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'demo-candidate-${entry.key}-${entry.value}',
                      ),
                      initialValue: entry.value,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        labelText: 'Statut dans cette démo',
                      ),
                      items: [
                        for (final status
                            in DemoRecruitmentGateway.statusLabels.entries)
                          DropdownMenuItem(
                            value: status.key,
                            child: Text(status.value, softWrap: true),
                          ),
                      ],
                      selectedItemBuilder: (_) => [
                        for (final status
                            in DemoRecruitmentGateway.statusLabels.values)
                          PublicApplicationChoiceText(status),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          gateway.changeStatus(entry.key, value);
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// A separate router confines every link in the real public recruitment UI to
/// the in-memory gateway, including its tracking and login fallback links.
class DemoRecruitmentExperience extends StatefulWidget {
  const DemoRecruitmentExperience({
    super.key,
    required this.gateway,
    required this.onClose,
    this.initialLocation = '/recruitment/apply',
  });
  final DemoRecruitmentGateway gateway;
  final VoidCallback onClose;
  final String initialLocation;
  @override
  State<DemoRecruitmentExperience> createState() =>
      _DemoRecruitmentExperienceState();
}

class _DemoRecruitmentExperienceState extends State<DemoRecruitmentExperience> {
  late final GoRouter router;
  late final _DemoRouteInformationProvider routeInformation;
  @override
  void initState() {
    super.initState();
    router = GoRouter(
      initialLocation: widget.initialLocation,
      overridePlatformDefaultLocation: true,
      routes: [
        GoRoute(
          path: '/recruitment/apply',
          builder: (_, _) =>
              PublicRecruitmentCampaignsScreen(gateway: widget.gateway),
          routes: [
            GoRoute(
              path: ':campaignId',
              builder: (_, _) => PublicApplicationFlowScreen(
                campaignId: DemoRecruitmentGateway.campaign.id,
                campaign: DemoRecruitmentGateway.campaign,
                gateway: widget.gateway,
                demoMode: true,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/application-tracking',
          builder: (_, _) => ApplicationTrackingScreen(gateway: widget.gateway),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: widget.onClose,
                  child: const Text('Revenir à la visite'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    routeInformation = _DemoRouteInformationProvider(
      router.routeInformationProvider,
    );
  }

  @override
  void dispose() {
    routeInformation.dispose();
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'RECRUTEMENT · DÉMONSTRATION\nFormulaire prérempli avec un exemple fictif et modifiable. Aucun dossier, fichier ou e-mail n’est transmis.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
                IconButton(
                  key: const ValueKey('demo-close-recruitment'),
                  tooltip: 'Revenir à la visite',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: Theme.of(context),
          routeInformationProvider: routeInformation,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
        ),
      ),
    ],
  );
}

/// Native recruitment links stay inside this visit. In particular, navigating
/// its form must never replace the public /demo URL with a live application URL.
class _DemoRouteInformationProvider extends RouteInformationProvider
    with ChangeNotifier {
  _DemoRouteInformationProvider(this.source) {
    source.addListener(notifyListeners);
  }
  final RouteInformationProvider source;
  @override
  RouteInformation get value => source.value;
  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    // Deliberately no SystemNavigator/browser URL update from this nested router.
  }
  @override
  void dispose() {
    source.removeListener(notifyListeners);
    super.dispose();
  }
}
