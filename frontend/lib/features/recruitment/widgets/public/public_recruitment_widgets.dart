import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/ui/app_back_button.dart';
import '../../models/application_status_presentation.dart';
import '../../models/application_tracking_model.dart';
import '../../models/recruitment_campaign_model.dart';

class PublicRecruitmentShell extends StatelessWidget {
  final Widget child;

  const PublicRecruitmentShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/login'),
        title: const Text('EnactSpace'),
      ),
      body: SafeArea(child: child),
    );
  }
}

class CampaignPublicCard extends StatelessWidget {
  final RecruitmentCampaignModel campaign;
  final VoidCallback onStart;

  const CampaignPublicCard({
    super.key,
    required this.campaign,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Campagne ${campaign.title}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CANDIDATURES OUVERTES',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.green.shade200
                      : Colors.green.shade800,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                campaign.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (campaign.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(
                  campaign.description!.trim(),
                  style: TextStyle(height: 1.55),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  _Fact(
                    icon: Icons.date_range_outlined,
                    label: 'Période',
                    value: campaign.periodLabel,
                  ),
                  _Fact(
                    icon: Icons.event_available_outlined,
                    label: 'Date limite',
                    value: campaign.endDate ?? 'À confirmer',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Semantics(
                button: true,
                label: 'Commencer ma candidature pour ${campaign.title}',
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text('Commencer ma candidature'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Fact({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Text('$label : $value'),
    ],
  );
}

class PublicRecruitmentEmptyState extends StatelessWidget {
  const PublicRecruitmentEmptyState({super.key});

  @override
  Widget build(BuildContext context) => _PublicState(
    icon: Icons.event_busy_outlined,
    title: 'Aucune campagne n’est ouverte pour le moment',
    message:
        'Les prochaines opportunités seront publiées ici. Si tu as déjà postulé, ton suivi reste disponible.',
    actions: [
      FilledButton(
        onPressed: () => context.go('/application-tracking'),
        child: Text('Suivre une candidature'),
      ),
      TextButton(
        onPressed: () => context.go('/login'),
        child: Text('Retour à la connexion'),
      ),
    ],
  );
}

class PublicRecruitmentErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const PublicRecruitmentErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => _PublicState(
    icon: Icons.cloud_off_outlined,
    title: 'Impossible de charger les campagnes',
    message:
        'Le service est momentanément indisponible. Tes informations n’ont pas été modifiées.',
    actions: [
      FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text('Réessayer'),
      ),
    ],
  );
}

class _PublicState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  const _PublicState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ),
      ),
    ),
  );
}

class ApplicationStepHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String title;
  const ApplicationStepHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / totalSteps;
    return Semantics(
      label: 'Progression, étape $currentStep sur $totalSteps, $title',
      value: '${(progress * 100).round()} pour cent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Étape $currentStep sur $totalSteps',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
            color: AppTheme.enactusYellow,
          ),
        ],
      ),
    );
  }
}

class ApplicationReviewSection extends StatelessWidget {
  final String title;
  final List<String> lines;
  final VoidCallback onEdit;
  const ApplicationReviewSection({
    super.key,
    required this.title,
    required this.lines,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            TextButton(onPressed: onEdit, child: Text('Modifier')),
          ],
        ),
        for (final line in lines.where((line) => line.trim().isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(line, style: TextStyle(height: 1.4)),
          ),
      ],
    ),
  );
}

class ApplicationSuccessView extends StatelessWidget {
  final String campaignTitle;
  final String email;
  final String trackingCode;
  const ApplicationSuccessView({
    super.key,
    required this.campaignTitle,
    required this.email,
    required this.trackingCode,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 64),
            const SizedBox(height: 18),
            Text(
              'Candidature envoyée',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(campaignTitle, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Semantics(
              label: 'Code de suivi $trackingCode',
              textField: true,
              readOnly: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.softBlack,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Column(
                  children: [
                    Text(
                      'TON CODE DE SUIVI',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      trackingCode,
                      style: TextStyle(
                        color: AppTheme.enactusYellow,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(email, style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Conserve ce code avec ton adresse e-mail. Ils seront demandés pour consulter l’avancement du dossier.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                Semantics(
                  button: true,
                  label: 'Copier le code de suivi',
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: trackingCode),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copié.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text('Copier le code'),
                  ),
                ),
                FilledButton(
                  onPressed: () => context.go('/application-tracking'),
                  child: Text('Suivre ma candidature'),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text('Retour à la connexion'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ApplicationTimeline extends StatelessWidget {
  final ApplicationTrackingModel tracking;
  const ApplicationTimeline({super.key, required this.tracking});
  static const _steps = [
    'Candidature reçue',
    'Étude du dossier',
    'Entretien',
    'Décision',
  ];

  @override
  Widget build(BuildContext context) {
    final status = ApplicationStatusPresentation.fromStatus(tracking.status);
    return Semantics(
      container: true,
      label: 'Chronologie de la candidature, ${status.title}',
      child: Column(
        children: [
          for (var index = 0; index < _steps.length; index++)
            _TimelineItem(
              label: _steps[index],
              complete:
                  !status.terminalException && index <= status.timelineStep,
              current: index == status.timelineStep,
              isLast: index == _steps.length - 1,
              exception:
                  status.terminalException && index == status.timelineStep,
            ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String label;
  final bool complete;
  final bool current;
  final bool isLast;
  final bool exception;
  const _TimelineItem({
    required this.label,
    required this.complete,
    required this.current,
    required this.isLast,
    required this.exception,
  });

  @override
  Widget build(BuildContext context) {
    final color = exception
        ? (Theme.of(context).brightness == Brightness.dark
              ? Colors.orange.shade200
              : Colors.brown.shade800)
        : complete || current
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              exception
                  ? Icons.info_outline_rounded
                  : complete
                  ? Icons.check_circle_rounded
                  : current
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: color,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: complete
                    ? AppTheme.enactusYellow
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: current ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
