import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/recruitment_campaign_model.dart';
import '../../services/public_recruitment_gateway.dart';
import '../../widgets/public/public_recruitment_widgets.dart';

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
        (final campaigns?, false) when campaigns.isEmpty =>
          const PublicRecruitmentEmptyState(),
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
  const _CampaignList({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
        vertical: 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rejoins le mouvement',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                'Découvre les campagnes ouvertes et choisis celle qui correspond à ton envie d’agir avec Enactus ESP.',
                style: TextStyle(
                  color: AppTheme.secondaryText,
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              for (var index = 0; index < campaigns.length; index++) ...[
                CampaignPublicCard(
                  campaign: campaigns[index],
                  onStart: () =>
                      context.go('/recruitment/apply/${campaigns[index].id}'),
                ),
                if (index < campaigns.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
