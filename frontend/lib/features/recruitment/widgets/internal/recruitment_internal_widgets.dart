import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/application_model.dart';
import '../../models/application_status_presentation.dart';
import '../../models/recruitment_campaign_model.dart';

const internalApplicationStatuses = <String>[
  'submitted',
  'under_review',
  'interview_scheduled',
  'accepted',
  'rejected',
  'waiting_list',
  'cancelled',
];

class InternalRecruitmentHeader extends StatelessWidget {
  final String campaignLabel;
  final int visibleCount;
  final int totalCount;
  final int activeFilterCount;
  final VoidCallback onRefresh;
  final VoidCallback onToggleFilters;
  final VoidCallback onManageCampaigns;

  const InternalRecruitmentHeader({
    super.key,
    required this.campaignLabel,
    required this.visibleCount,
    required this.totalCount,
    required this.activeFilterCount,
    required this.onRefresh,
    required this.onToggleFilters,
    required this.onManageCampaigns,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recrutement',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(campaignLabel, style: const TextStyle(color: Colors.white70)),
      ],
    );
    final manageCampaigns = Semantics(
      button: true,
      label: 'Gérer les campagnes de recrutement',
      child: OutlinedButton.icon(
        key: const Key('manage-campaigns'),
        onPressed: onManageCampaigns,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          minimumSize: const Size(44, 44),
        ),
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Gérer les campagnes'),
      ),
    );
    final filters = Semantics(
      button: true,
      label: 'Filtres, $activeFilterCount actifs',
      child: OutlinedButton.icon(
        onPressed: onToggleFilters,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          minimumSize: const Size(44, 44),
        ),
        icon: const Icon(Icons.tune_rounded),
        label: Text(
          activeFilterCount == 0 ? 'Filtres' : 'Filtres ($activeFilterCount)',
        ),
      ),
    );
    final refresh = IconButton(
      onPressed: onRefresh,
      tooltip: 'Actualiser la liste',
      color: Colors.white,
      icon: const Icon(Icons.refresh_rounded),
    );
    final actions = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              manageCampaigns,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: filters),
                  const SizedBox(width: 8),
                  refresh,
                ],
              ),
            ],
          )
        : Wrap(spacing: 8, children: [manageCampaigns, filters, refresh]);
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            heading,
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: actions),
          ] else
            Row(
              children: [
                Expanded(child: heading),
                actions,
              ],
            ),
          const SizedBox(height: 16),
          Semantics(
            label: '$visibleCount candidatures visibles sur $totalCount',
            child: Text(
              '$visibleCount candidatures · $totalCount dossiers chargés',
              style: const TextStyle(
                color: AppTheme.enactusYellow,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InternalFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController poleController;
  final TextEditingController projectController;
  final TextEditingController departmentController;
  final TextEditingController classController;
  final List<RecruitmentCampaignModel> campaigns;
  final String campaignId;
  final String status;
  final String gender;
  final bool anonymized;
  final bool expanded;
  final DateTime? submittedFrom;
  final DateTime? submittedTo;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCampaignChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<bool> onAnonymizedChanged;
  final VoidCallback onPickSubmittedFrom;
  final VoidCallback onPickSubmittedTo;
  final VoidCallback onApply;
  final VoidCallback onReset;

  const InternalFilterBar({
    super.key,
    required this.searchController,
    required this.poleController,
    required this.projectController,
    required this.departmentController,
    required this.classController,
    required this.campaigns,
    required this.campaignId,
    required this.status,
    required this.gender,
    required this.anonymized,
    required this.expanded,
    required this.submittedFrom,
    required this.submittedTo,
    required this.onSearchChanged,
    required this.onCampaignChanged,
    required this.onStatusChanged,
    required this.onGenderChanged,
    required this.onAnonymizedChanged,
    required this.onPickSubmittedFrom,
    required this.onPickSubmittedTo,
    required this.onApply,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final primary = <Widget>[
      TextField(
        key: const Key('internal-search'),
        controller: searchController,
        onChanged: onSearchChanged,
        decoration: const InputDecoration(
          labelText: 'Rechercher',
          hintText: 'Nom, e-mail ou référence',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      DropdownButtonFormField<String>(
        key: const Key('internal-campaign-filter'),
        isExpanded: true,
        initialValue: campaignId,
        decoration: const InputDecoration(labelText: 'Campagne'),
        items: [
          const DropdownMenuItem(value: 'all', child: Text('Toutes')),
          ...campaigns.map(
            (item) => DropdownMenuItem(
              value: item.id,
              child: Text(item.title, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: onCampaignChanged,
      ),
      DropdownButtonFormField<String>(
        key: const Key('internal-status-filter'),
        isExpanded: true,
        initialValue: status,
        decoration: const InputDecoration(labelText: 'Statut'),
        items: [
          const DropdownMenuItem(value: 'all', child: Text('Tous')),
          ...internalApplicationStatuses.map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(
                ApplicationStatusPresentation.fromStatus(value).title,
              ),
            ),
          ),
        ],
        onChanged: onStatusChanged,
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact)
              ...primary.map(
                (child) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: primary
                    .map(
                      (child) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: child,
                        ),
                      ),
                    )
                    .toList(),
              ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _TextFilter(controller: poleController, label: 'Pôle'),
                        _TextFilter(
                          controller: projectController,
                          label: 'Projet',
                        ),
                        _TextFilter(
                          controller: departmentController,
                          label: 'Département',
                        ),
                        _TextFilter(
                          controller: classController,
                          label: 'Classe',
                        ),
                        _DateFilter(
                          label: 'Soumise à partir du',
                          value: submittedFrom,
                          onPressed: onPickSubmittedFrom,
                        ),
                        _DateFilter(
                          label: 'Soumise jusqu’au',
                          value: submittedTo,
                          onPressed: onPickSubmittedTo,
                        ),
                        SizedBox(
                          width: 210,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: gender,
                            decoration: const InputDecoration(
                              labelText: 'Genre',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('Tous'),
                              ),
                              DropdownMenuItem(
                                value: 'female',
                                child: Text('Femme'),
                              ),
                              DropdownMenuItem(
                                value: 'male',
                                child: Text('Homme'),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('Autre'),
                              ),
                            ],
                            onChanged: onGenderChanged,
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: anonymized,
                      onChanged: onAnonymizedChanged,
                      title: const Text('Mode anonymisé'),
                      subtitle: const Text(
                        'Masque l’identité dans la liste et la fiche.',
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          key: const Key('internal-reset-filters'),
                          onPressed: onReset,
                          child: const Text('Réinitialiser'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: onApply,
                          child: const Text('Appliquer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextFilter extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _TextFilter({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _DateFilter extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPressed;

  const _DateFilter({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(
        value == null
            ? label
            : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class ApplicationWorkbench extends StatelessWidget {
  final List<ApplicationModel> applications;
  final String Function(String) campaignTitle;
  final bool anonymized;
  final int rangeStart;
  final int rangeEnd;
  final int total;
  final int currentPage;
  final int pageCount;
  final ValueChanged<ApplicationModel> onOpen;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const ApplicationWorkbench({
    super.key,
    required this.applications,
    required this.campaignTitle,
    required this.anonymized,
    required this.rangeStart,
    required this.rangeEnd,
    required this.total,
    required this.currentPage,
    required this.pageCount,
    required this.onOpen,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '$rangeStart à $rangeEnd sur $total candidatures',
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '$rangeStart–$rangeEnd sur $total candidatures',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (pageCount > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('internal-previous-page'),
                  onPressed: onPrevious,
                  tooltip: 'Page précédente',
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('Page $currentPage sur $pageCount'),
                IconButton(
                  key: const Key('internal-next-page'),
                  onPressed: onNext,
                  tooltip: 'Page suivante',
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        if (mobile)
          ...applications.map(
            (item) => _ApplicationRow(
              application: item,
              campaign: campaignTitle(item.campaignId),
              anonymized: anonymized,
              mobile: true,
              onOpen: () => onOpen(item),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const _TableHeader(),
                ...applications.map(
                  (item) => _ApplicationRow(
                    application: item,
                    campaign: campaignTitle(item.campaignId),
                    anonymized: anonymized,
                    mobile: false,
                    onOpen: () => onOpen(item),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.softBlack.withValues(alpha: .04),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: const Row(
      children: [
        Expanded(flex: 3, child: Text('Candidat / référence')),
        Expanded(flex: 2, child: Text('Campagne')),
        Expanded(flex: 2, child: Text('Parcours / pôle')),
        Expanded(flex: 2, child: Text('Statut')),
        Expanded(child: Text('Évaluation')),
        Expanded(child: Text('Documents')),
        SizedBox(width: 142),
      ],
    ),
  );
}

class _ApplicationRow extends StatelessWidget {
  final ApplicationModel application;
  final String campaign;
  final bool anonymized;
  final bool mobile;
  final VoidCallback onOpen;

  const _ApplicationRow({
    required this.application,
    required this.campaign,
    required this.anonymized,
    required this.mobile,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final identity = anonymized
        ? application.anonymousCode
        : application.fullName;
    final documents = [
      application.cvUrl,
      application.motivationLetterUrl,
      application.attachmentUrl,
    ].where((value) => value?.trim().isNotEmpty == true).length;
    final row = mobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      identity,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  InternalStatusBadge(status: application.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(campaign, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(
                '${application.department ?? 'Département non renseigné'} · ${application.preferredPole ?? 'Pôle non renseigné'}',
              ),
              Text(
                'Évaluation : ${application.scoreLabel} · $documents/3 documents',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onOpen,
                  child: const Text('Ouvrir le dossier'),
                ),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                flex: 3,
                child: _TwoLines(
                  first: identity,
                  second: anonymized
                      ? 'Identité masquée'
                      : (application.trackingCode ?? application.id),
                ),
              ),
              Expanded(flex: 2, child: Text(campaign, maxLines: 2)),
              Expanded(
                flex: 2,
                child: _TwoLines(
                  first:
                      '${application.department ?? 'Non renseigné'} · ${application.className ?? '—'}',
                  second: application.preferredPole ?? 'Pôle non renseigné',
                ),
              ),
              Expanded(
                flex: 2,
                child: InternalStatusBadge(status: application.status),
              ),
              Expanded(
                child: Semantics(
                  label: 'Évaluation officielle ${application.scoreLabel}',
                  child: Text(application.scoreLabel),
                ),
              ),
              Expanded(
                child: Semantics(
                  label: '$documents documents',
                  child: Text('$documents/3'),
                ),
              ),
              SizedBox(
                width: 142,
                child: TextButton(
                  onPressed: onOpen,
                  child: const Text('Ouvrir le dossier'),
                ),
              ),
            ],
          );
    return Semantics(
      label: 'Candidature $identity, ${application.statusLabel}',
      child: Card(
        margin: mobile ? const EdgeInsets.only(bottom: 10) : EdgeInsets.zero,
        shape: mobile ? null : const RoundedRectangleBorder(),
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: row,
          ),
        ),
      ),
    );
  }
}

class _TwoLines extends StatelessWidget {
  final String first;
  final String second;

  const _TwoLines({required this.first, required this.second});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        first,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      Text(
        second,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class InternalStatusBadge extends StatelessWidget {
  final String status;

  const InternalStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final presentation = ApplicationStatusPresentation.fromStatus(status);
    final color = switch (presentation.status) {
      'accepted' => Colors.green.shade700,
      'rejected' => Colors.red.shade700,
      'interview_scheduled' => Colors.blue.shade700,
      'waiting_list' => Colors.orange.shade800,
      'cancelled' => Colors.grey.shade700,
      _ => AppTheme.softBlack,
    };
    return Semantics(
      label: 'Statut ${presentation.title}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Text(
          presentation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class InternalRecruitmentState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const InternalRecruitmentState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppTheme.secondaryText),
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
  );
}
