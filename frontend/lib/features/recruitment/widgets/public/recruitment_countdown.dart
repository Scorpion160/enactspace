import 'package:flutter/material.dart';

import '../../models/recruitment_campaign_model.dart';

class RecruitmentCountdown extends StatelessWidget {
  final RecruitmentCampaignModel campaign;
  final DateTime now;
  const RecruitmentCountdown({
    super.key,
    required this.campaign,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final opening = campaign.openingInstant;
    final closing = campaign.closingInstant;
    final upcoming = opening != null && now.isBefore(opening);
    final target = upcoming ? opening : closing;
    if (!campaign.isActive || target == null || !now.isBefore(target)) {
      return const SizedBox.shrink();
    }
    final seconds = (target.difference(now).inMilliseconds / 1000).ceil();
    final values = [
      seconds ~/ 86400,
      (seconds ~/ 3600) % 24,
      (seconds ~/ 60) % 60,
      seconds % 60,
    ];
    const labels = ['Jours', 'Heures', 'Minutes', 'Secondes'];
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '${upcoming ? 'Ouverture' : 'Clôture'} dans ${values[0]} jours, ${values[1]} heures, ${values[2]} minutes et ${values[3]} secondes.',
      // Do not announce a live region every second to screen-reader users.
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              upcoming
                  ? 'L’aventure commence dans…'
                  : 'Encore un peu de temps pour te lancer !',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth < 230 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.6
                    ? 2
                    : 4;
                final width =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: width,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: i == 0
                              ? const Color(0xFFFFD34D)
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              values[i].toString().padLeft(2, '0'),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: i == 0
                                        ? const Color(0xFF211B0B)
                                        : colors.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              labels[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: i == 0
                                    ? const Color(0xFF211B0B)
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              upcoming
                  ? 'Ouverture à 00 h, heure de Dakar.'
                  : 'Jusqu’à la fin du dernier jour, heure de Dakar.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
