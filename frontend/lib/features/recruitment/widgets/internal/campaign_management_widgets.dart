import '../recruitment_workspace.dart';
import 'package:flutter/material.dart';

import '../../models/campaign_state_presentation.dart';
import '../../models/recruitment_campaign_model.dart';

class CampaignStateBadge extends StatelessWidget {
  final CampaignStatePresentation state;

  const CampaignStateBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (state.key) {
      'open' => dark ? Colors.green.shade200 : Colors.green.shade800,
      'planned' => dark ? Colors.lightBlue.shade200 : Colors.blue.shade800,
      'ended' => Theme.of(context).colorScheme.onSurfaceVariant,
      _ => dark ? Colors.orange.shade200 : Colors.deepOrange.shade800,
    };
    return Semantics(
      label: 'État de la campagne : ${state.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          border: Border.all(color: color.withValues(alpha: .28)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          state.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class CampaignManagementCard extends StatelessWidget {
  final RecruitmentCampaignModel campaign;
  final CampaignStatePresentation state;
  final int applicationCount;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const CampaignManagementCard({
    super.key,
    required this.campaign,
    required this.state,
    required this.applicationCount,
    required this.onView,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ended = state.key == 'ended';
    final active = campaign.isActive;
    return Semantics(
      container: true,
      label:
          'Campagne ${campaign.title}, état ${state.label}, période ${campaign.periodLabel}',
      child: Card(
        key: Key('campaign-${campaign.id}'),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CampaignStateBadge(state: state),
                  const SizedBox(height: 12),
                  Text(
                    campaign.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RecruitmentDescription(
                campaign.description?.trim().isNotEmpty == true
                    ? campaign.description!.trim()
                    : 'Aucune description renseignée.',
              ),
              const SizedBox(height: 14),
              _InfoLine(
                icon: Icons.calendar_month_outlined,
                label: campaign.periodLabel,
                semantics: 'Période ${campaign.periodLabel}',
              ),
              _InfoLine(
                icon: Icons.people_outline_rounded,
                label: '$applicationCount candidatures',
                semantics: '$applicationCount candidatures associées',
              ),
              _InfoLine(
                icon: active
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                label: active
                    ? 'Proposée selon sa période'
                    : 'Non proposée aux nouveaux candidats',
                semantics: active ? 'Activation active' : 'Activation inactive',
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Semantics(
                    button: true,
                    label: 'Consulter la campagne ${campaign.title}',
                    child: TextButton(
                      onPressed: onView,
                      child: const Text('Consulter'),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Modifier la campagne ${campaign.title}',
                    child: OutlinedButton(
                      onPressed: onEdit,
                      child: const Text('Modifier'),
                    ),
                  ),
                  if (active || !ended)
                    Semantics(
                      button: true,
                      label: active
                          ? 'Fermer la campagne ${campaign.title}'
                          : 'Ouvrir la campagne ${campaign.title}',
                      child: FilledButton.tonal(
                        onPressed: onToggle,
                        child: Text(active ? 'Fermer' : 'Ouvrir'),
                      ),
                    ),
                  Semantics(
                    button: true,
                    label: applicationCount > 0
                        ? 'Fermer la campagne ${campaign.title} en conservant ses dossiers'
                        : 'Supprimer la campagne ${campaign.title}',
                    child: IconButton(
                      key: Key('delete-campaign-${campaign.id}'),
                      onPressed: onDelete,
                      tooltip: applicationCount > 0
                          ? 'Fermer et conserver les dossiers'
                          : 'Supprimer définitivement',
                      color: applicationCount > 0
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.error,
                      icon: Icon(
                        applicationCount > 0
                            ? Icons.archive_outlined
                            : Icons.delete_outline_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CampaignManagementState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CampaignManagementState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 44,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semantics;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.semantics,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: semantics,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    ),
  );
}
