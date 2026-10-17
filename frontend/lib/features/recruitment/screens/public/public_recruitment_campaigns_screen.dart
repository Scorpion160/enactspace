import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/recruitment_campaign_model.dart';
import '../../services/public_recruitment_gateway.dart';
import '../../widgets/public/public_recruitment_widgets.dart';
import '../../widgets/public/recruitment_welcome.dart';

class PublicRecruitmentCampaignsScreen extends StatefulWidget {
  final PublicRecruitmentGateway? gateway;

  const PublicRecruitmentCampaignsScreen({super.key, this.gateway});

  @override
  State<PublicRecruitmentCampaignsScreen> createState() =>
      _PublicRecruitmentCampaignsScreenState();
}

class _PublicRecruitmentCampaignsScreenState
    extends State<PublicRecruitmentCampaignsScreen> {
  late final PublicRecruitmentGateway _gateway;
  List<RecruitmentCampaignModel>? _campaigns;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? RecruitmentPublicGateway();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _campaigns = null;
      _failed = false;
    });
    try {
      final campaigns = await _gateway.loadCampaigns();
      if (mounted) setState(() => _campaigns = campaigns);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PublicRecruitmentShell(
      child: switch ((_campaigns, _failed)) {
        (_, true) => PublicRecruitmentErrorState(onRetry: _load),
        (null, false) => const _CampaignLoadingState(),
        (final campaigns?, false) => _CampaignList(campaigns: campaigns),
      },
    );
  }
}

class _CampaignLoadingState extends StatelessWidget {
  const _CampaignLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Chargement des campagnes',
        child: const SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _CampaignList extends StatelessWidget {
  final List<RecruitmentCampaignModel> campaigns;
  final _campaignsKey = GlobalKey();
  _CampaignList({required this.campaigns});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
      vertical: 24,
    ),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RecruitmentLandingHero(
          hasCampaigns: campaigns.isNotEmpty,
          onDiscover: () {
            final target = _campaignsKey.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(target,
                duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 250),
                alignment: 0,
              );
            }
          },
          onTrack: () => context.go('/application-tracking'),
        ),
        const SizedBox(height: 28),
        Semantics(
          key: _campaignsKey,
          header: true,
          child: Text('Les candidatures ouvertes',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 16),
        if (campaigns.isEmpty)
          const Card(child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Aucune campagne n’est ouverte pour le moment',
                style: TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
              SizedBox(height: 8),
              Text('Reviens ici pour découvrir les prochaines candidatures. Si tu as déjà postulé, ton suivi reste disponible.',
                style: TextStyle(height: 1.6)),
            ]),
          )),
        for (var index = 0; index < campaigns.length; index++) ...[
          CampaignPublicCard(
            campaign: campaigns[index],
            onStart: () => context.go('/recruitment/apply/${campaigns[index].id}'),
          ),
          if (index < campaigns.length - 1) const SizedBox(height: 16),
        ],
        const SizedBox(height: 36),
        const RecruitmentWelcome(),
        const SizedBox(height: 28),
      ]),
    )),
  );
}
