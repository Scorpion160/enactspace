import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../models/pole_portfolio_models.dart';

class PoleDetailView extends StatelessWidget {
  final PoleDetailData data;
  final VoidCallback onBack;
  final Widget? management;
  final Widget? teamSection;
  final VoidCallback? onHistory;

  const PoleDetailView({
    super.key,
    required this.data,
    required this.onBack,
    this.management,
    this.teamSection,
    this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final item = data.item;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          leading: IconButton(
            tooltip: 'Retour au portefeuille',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(item.pole.name),
          actions: [
            if (onHistory != null)
              TextButton.icon(
                key: const Key('pole_memory_link'),
                onPressed: onHistory,
                icon: const Icon(Icons.history),
                label: const Text('Historique'),
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
              return Padding(
                padding: EdgeInsets.fromLTRB(padding, 22, padding, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          label: 'Résumé du pôle ${item.pole.name}',
                          child: PoleOverviewSection(item: item),
                        ),
                        if (management != null) ...[
                          const SizedBox(height: 10),
                          management!,
                        ],
                        const SizedBox(height: 14),
                        Semantics(
                          header: true,
                          label: 'Équipe du pôle',
                          child: teamSection ?? PoleTeamSection(item: item),
                        ),
                        const SizedBox(height: 14),
                        Semantics(
                          header: true,
                          label: 'Travail du pôle',
                          child: PoleWorkSection(
                            item: item,
                            taskAssignees: data.taskAssignees,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Semantics(
                          header: true,
                          label: 'Activité du pôle',
                          child: PoleActivitySection(data: data),
                        ),
                        const SizedBox(height: 14),
                        Semantics(
                          header: true,
                          label: 'Documents du pôle',
                          child: PoleDocumentsSection(data: data),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PoleOverviewSection extends StatelessWidget {
  final PolePortfolioItem item;
  const PoleOverviewSection({super.key, required this.item});

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Résumé',
    icon: Icons.dashboard_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(item.pole.displayShortName)),
            Chip(label: Text(PoleTypePresentation.label(item.pole.type))),
            Chip(label: Text(item.teamLabel)),
          ],
        ),
        const SizedBox(height: 14),
        _LabelValue(label: 'Description', value: _value(item.pole.description)),
        _LabelValue(label: 'Objectifs', value: _value(item.pole.objectives)),
        _LabelValue(label: 'Chef de pôle', value: item.leadLabel),
        _LabelValue(label: 'Adjoint du pôle', value: item.deputyLabel),
        _LabelValue(
          label: 'Prochaine action',
          value: item.tasksUnavailable
              ? 'Information indisponible'
              : item.nextAction?.task.title ??
                    'Aucune prochaine action planifiée',
        ),
        _LabelValue(
          label: 'Blocages',
          value: item.tasksUnavailable
              ? 'Information indisponible'
              : _countLabel(item.alerts.blockedCount, 'bloquée'),
        ),
        _LabelValue(
          label: 'Retards',
          value: item.tasksUnavailable
              ? 'Information indisponible'
              : _countLabel(item.alerts.overdueCount, 'en retard'),
        ),
      ],
    ),
  );
}

class PoleTeamSection extends StatelessWidget {
  final PolePortfolioItem item;
  const PoleTeamSection({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (item.membersUnavailable) {
      content = const _InlineState(
        icon: Icons.cloud_off_rounded,
        text: 'Équipe indisponible',
      );
    } else if (item.activeMembers.isEmpty) {
      content = const _InlineState(
        icon: Icons.group_off_outlined,
        text: 'Aucune équipe affectée',
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelValue(label: 'Chef de pôle', value: item.leadLabel),
          _LabelValue(label: 'Adjoint du pôle', value: item.deputyLabel),
          const SizedBox(height: 6),
          Text('Membres', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: item.activeMembers
                .map((member) => Chip(label: Text(member.displayName)))
                .toList(),
          ),
        ],
      );
    }
    return _SectionCard(
      title: 'Équipe',
      icon: Icons.groups_2_outlined,
      child: content,
    );
  }
}

class PoleWorkSection extends StatelessWidget {
  final PolePortfolioItem item;
  final Map<String, List<PoleAssignee>> taskAssignees;

  const PoleWorkSection({
    super.key,
    required this.item,
    required this.taskAssignees,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (item.tasksUnavailable) {
      content = const _InlineState(
        icon: Icons.cloud_off_rounded,
        text: 'Travail indisponible',
      );
    } else if ((item.tasks ?? const []).isEmpty) {
      content = const _InlineState(
        icon: Icons.task_alt_rounded,
        text: 'Aucune tâche pour ce pôle',
      );
    } else {
      content = Column(
        children: item.tasks!.map((task) {
          final due = DateTime.tryParse(task.dueDate ?? '');
          final overdue =
              due != null &&
              due.isBefore(DateTime.now()) &&
              !PoleTaskPresentation.isTerminal(task.status);
          final assignees = taskAssignees[task.id] ?? const [];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              task.status == 'bloque'
                  ? Icons.block_rounded
                  : Icons.task_alt_rounded,
            ),
            title: Text(task.title),
            subtitle: Text(
              '${PoleTaskPresentation.statusLabel(task.status)} · '
              '${PoleTaskPresentation.priorityLabel(task.priority)} · '
              '${task.dueDateLabel}\n'
              '${assignees.isEmpty ? 'Assigné non renseigné' : assignees.map((e) => e.displayName).join(', ')}'
              '${overdue ? ' · En retard' : ''}',
            ),
            isThreeLine: true,
          );
        }).toList(),
      );
    }
    return _SectionCard(
      title: 'Travail',
      icon: Icons.checklist_rounded,
      child: content,
    );
  }
}

class PoleActivitySection extends StatelessWidget {
  final PoleDetailData data;
  const PoleActivitySection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final events = data.events ?? const [];
    final posts = data.posts ?? const [];
    Widget content;
    if (data.activityUnavailable) {
      content = const _InlineState(
        icon: Icons.cloud_off_rounded,
        text: 'Activité indisponible',
      );
    } else if (events.isEmpty && posts.isEmpty) {
      content = const _InlineState(
        icon: Icons.event_busy_outlined,
        text: 'Aucune activité récente',
      );
    } else {
      final children = <Widget>[
        ...events.map(
          (event) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(event.title),
            subtitle: Text(
              '${event.typeLabel} · ${_date(event.startTime)}'
              '${_nonEmpty(event.location) == null ? '' : ' · ${event.location}'}',
            ),
          ),
        ),
        ...posts.map(
          (post) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.campaign_outlined),
            title: Text(post.displayTitle),
            subtitle: Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ];
      content = Column(children: children);
    }
    return _SectionCard(
      title: 'Activité',
      icon: Icons.timeline_rounded,
      child: content,
    );
  }
}

class PoleDocumentsSection extends StatelessWidget {
  final PoleDetailData data;
  const PoleDocumentsSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final documents = data.documents ?? const [];
    Widget content;
    if (data.documentsUnavailable) {
      content = const _InlineState(
        icon: Icons.cloud_off_rounded,
        text: 'Documents indisponibles',
      );
    } else if (documents.isEmpty) {
      content = const _InlineState(
        icon: Icons.folder_off_outlined,
        text: 'Aucun document pour ce pôle',
      );
    } else {
      content = Column(
        children: documents
            .map(
              (document) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(document.title),
                subtitle: Text(
                  '${document.categoryLabel} · ${document.statusLabel} · ${document.createdAtLabel}',
                ),
                trailing: TextButton(
                  onPressed: _documentUri(document.fileUrl) == null
                      ? null
                      : () async {
                          final uri = _documentUri(document.fileUrl);
                          if (uri != null) await launchUrl(uri);
                        },
                  child: const Text('Consulter'),
                ),
              ),
            )
            .toList(),
      );
    }
    return _SectionCard(
      title: 'Documents',
      icon: Icons.folder_outlined,
      child: content,
    );
  }
}

class PoleDetailLoadingState extends StatelessWidget {
  const PoleDetailLoadingState({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: 'Chargement de la fiche du pôle',
      child: const CircularProgressIndicator(),
    ),
  );
}

class PoleDetailErrorState extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRetry;
  const PoleDetailErrorState({
    super.key,
    required this.onBack,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48),
          const SizedBox(height: 12),
          const Text('Impossible de charger ce pôle'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: onBack, child: const Text('Retour')),
              FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 9),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  const _LabelValue({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(value),
      ],
    ),
  );
}

class _InlineState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlineState({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon),
      const SizedBox(width: 9),
      Expanded(child: Text(text)),
    ],
  );
}

String _value(String? value) => _nonEmpty(value) ?? 'Non renseigné';

String? _nonEmpty(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

String _countLabel(int count, String suffix) =>
    '$count tâche${count > 1 ? 's' : ''} $suffix${count > 1 && suffix == 'bloquée' ? 's' : ''}';

String _date(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

Uri? _documentUri(String? value) {
  final path = _nonEmpty(value);
  if (path == null) return null;
  return Uri.tryParse(
    path.startsWith('http://') || path.startsWith('https://')
        ? path
        : '${ApiClient.serverUrl}$path',
  );
}
