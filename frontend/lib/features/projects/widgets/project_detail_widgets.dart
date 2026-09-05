import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../documents/models/document_model.dart';
import '../../events/models/event_model.dart';
import '../../tasks/models/task_model.dart';
import '../models/project_portfolio_models.dart';

class ProjectDetailView extends StatelessWidget {
  final ProjectDetailData data;
  final VoidCallback onBack;
  final Widget? management;
  final Widget? teamSection;

  const ProjectDetailView({
    super.key,
    required this.data,
    required this.onBack,
    this.management,
    this.teamSection,
  });

  @override
  Widget build(BuildContext context) {
    final project = data.item.project;
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          Material(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Retour au portefeuille',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(ProjectStatusPresentation.label(project.status)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Material(
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Résumé'),
                Tab(text: 'Équipe'),
                Tab(text: 'Travail'),
                Tab(text: 'Activité'),
                Tab(text: 'Documents'),
                Tab(text: 'Impact'),
              ],
            ),
          ),
          ?management,
          Expanded(
            child: TabBarView(
              children: [
                ProjectOverviewSection(item: data.item),
                teamSection ?? ProjectTeamSection(item: data.item),
                ProjectWorkSection(
                  item: data.item,
                  taskAssignees: data.taskAssignees,
                ),
                ProjectActivitySection(
                  events: data.events,
                  unavailable: data.eventsUnavailable,
                ),
                ProjectDocumentsSection(
                  documents: data.documents,
                  unavailable: data.documentsUnavailable,
                ),
                ProjectImpactSection(item: data.item),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectOverviewSection extends StatelessWidget {
  final ProjectPortfolioItem item;
  const ProjectOverviewSection({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final project = item.project;
    return _SectionPage(
      semanticsLabel: 'Section Résumé du projet',
      title: 'Résumé',
      children: [
        _OverviewGrid(
          children: [
            _InfoCard(
              label: 'Statut',
              value: ProjectStatusPresentation.label(project.status),
            ),
            _InfoCard(label: 'Chef de projet', value: item.leadLabel),
            _InfoCard(
              label: 'Adjoint chef de projet',
              value: item.teamUnavailable
                  ? 'Équipe indisponible'
                  : item.deputy?.displayName ?? 'Adjoint non affecté',
            ),
            _InfoCard(
              label: 'Progression opérationnelle',
              value: item.impact?.progress == null
                  ? 'Progression non disponible'
                  : '${item.impact!.progress!.toStringAsFixed(0)} %',
            ),
            _InfoCard(label: 'Début', value: _date(project.startedAt)),
            _InfoCard(label: 'Fin', value: _date(project.endedAt)),
          ],
        ),
        _NarrativeCard(label: 'Problème', value: project.problemStatement),
        _NarrativeCard(label: 'Solution', value: project.solution),
        _NarrativeCard(label: 'Objectifs', value: project.objectives),
        _NextActionCard(item: item),
        _AlertsCard(item: item),
      ],
    );
  }
}

class ProjectTeamSection extends StatelessWidget {
  final ProjectPortfolioItem item;
  const ProjectTeamSection({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    if (item.teamUnavailable) {
      return const _SectionMessage(
        semanticsLabel: 'Section Équipe indisponible',
        icon: Icons.groups_2_outlined,
        title: 'Équipe indisponible',
        message: 'Les affectations n’ont pas pu être chargées.',
      );
    }
    if (item.activeMembers.isEmpty) {
      return const _SectionMessage(
        semanticsLabel: 'Section Équipe, aucune équipe affectée',
        icon: Icons.group_off_rounded,
        title: 'Aucune équipe affectée',
        message: 'Ce projet ne possède actuellement aucune affectation active.',
      );
    }
    final members = item.activeMembers.where(
      (member) =>
          member.position != 'chef_projet' &&
          member.position != 'adjoint_chef_projet',
    );
    return _SectionPage(
      semanticsLabel: 'Section Équipe du projet',
      title: 'Équipe',
      children: [
        _MemberCard(
          role: 'Chef de projet',
          name: item.lead?.displayName ?? 'Non affecté',
        ),
        _MemberCard(
          role: 'Adjoint chef de projet',
          name: item.deputy?.displayName ?? 'Non affecté',
        ),
        const Padding(
          padding: EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            'Membres',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        if (members.isEmpty)
          const Text('Aucun autre membre affecté')
        else
          ...members.map(
            (member) => _MemberCard(role: 'Membre', name: member.displayName),
          ),
      ],
    );
  }
}

class ProjectWorkSection extends StatelessWidget {
  final ProjectPortfolioItem item;
  final Map<String, List<ProjectAssignee>> taskAssignees;
  const ProjectWorkSection({
    super.key,
    required this.item,
    required this.taskAssignees,
  });
  @override
  Widget build(BuildContext context) {
    if (item.tasksUnavailable) {
      return const _SectionMessage(
        semanticsLabel: 'Section Travail indisponible',
        icon: Icons.task_alt_rounded,
        title: 'Travail indisponible',
        message: 'Les tâches de ce projet n’ont pas pu être chargées.',
      );
    }
    final tasks = item.tasks ?? const <TaskModel>[];
    if (tasks.isEmpty) {
      return const _SectionMessage(
        semanticsLabel: 'Section Travail sans tâche',
        icon: Icons.checklist_rounded,
        title: 'Aucune tâche',
        message: 'Aucun travail n’est encore planifié pour ce projet.',
      );
    }
    const order = [
      'a_faire',
      'en_cours',
      'bloque',
      'termine',
      'valide',
      'annule',
    ];
    return _SectionPage(
      semanticsLabel: 'Section Travail du projet',
      title: 'Travail',
      children: [
        for (final status in order)
          if (tasks.any((task) => task.status == status)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                ProjectTaskPresentation.statusLabel(status),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ...tasks
                .where((task) => task.status == status)
                .map(
                  (task) => _TaskCard(
                    task: task,
                    assignees: taskAssignees[task.id] ?? const [],
                  ),
                ),
          ],
      ],
    );
  }
}

class ProjectActivitySection extends StatelessWidget {
  final List<EventModel>? events;
  final bool unavailable;
  const ProjectActivitySection({
    super.key,
    required this.events,
    required this.unavailable,
  });
  @override
  Widget build(BuildContext context) {
    if (unavailable) {
      return const _SectionMessage(
        semanticsLabel: 'Section Activité indisponible',
        icon: Icons.event_busy_rounded,
        title: 'Activité indisponible',
        message: 'Les événements liés n’ont pas pu être chargés.',
      );
    }
    if (events == null || events!.isEmpty) {
      return const _SectionMessage(
        semanticsLabel: 'Section Activité vide',
        icon: Icons.event_note_rounded,
        title: 'Aucune activité récente',
        message: 'Aucun événement réel n’est lié à ce projet.',
      );
    }
    final sorted = [...events!]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return _SectionPage(
      semanticsLabel: 'Section Activité du projet',
      title: 'Activité',
      children: sorted
          .map<Widget>(
            (event) => Card(
              child: ListTile(
                leading: const Icon(Icons.event_rounded),
                title: Text(event.title),
                subtitle: Text(
                  '${_dateTime(event.startTime)}${event.location == null || event.location!.isEmpty ? '' : ' · ${event.location}'}',
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class ProjectDocumentsSection extends StatelessWidget {
  final List<DocumentModel>? documents;
  final bool unavailable;
  const ProjectDocumentsSection({
    super.key,
    required this.documents,
    required this.unavailable,
  });
  @override
  Widget build(BuildContext context) {
    if (unavailable) {
      return const _SectionMessage(
        semanticsLabel: 'Section Documents indisponible',
        icon: Icons.folder_off_rounded,
        title: 'Documents indisponibles',
        message: 'Les documents liés n’ont pas pu être chargés.',
      );
    }
    if (documents == null || documents!.isEmpty) {
      return const _SectionMessage(
        semanticsLabel: 'Section Documents vide',
        icon: Icons.folder_open_rounded,
        title: 'Aucun document',
        message: 'Aucun document n’est lié à ce projet.',
      );
    }
    return _SectionPage(
      semanticsLabel: 'Section Documents du projet',
      title: 'Documents',
      children: documents!
          .map<Widget>(
            (document) => Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(document.title),
                subtitle: Text(
                  '${document.statusLabel} · ${document.createdAtLabel}',
                ),
                trailing: TextButton(
                  onPressed:
                      document.fileUrl == null || document.fileUrl!.isEmpty
                      ? null
                      : () async {
                          final uri = Uri.tryParse(document.fileUrl!);
                          if (uri != null) await launchUrl(uri);
                        },
                  child: const Text('Consulter'),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class ProjectImpactSection extends StatelessWidget {
  final ProjectPortfolioItem item;
  const ProjectImpactSection({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    if (item.impactUnavailable) {
      return const _SectionMessage(
        semanticsLabel: 'Section Impact indisponible',
        icon: Icons.insights_rounded,
        title: 'Impact indisponible',
        message: 'La source Impact n’a pas pu être chargée.',
      );
    }
    final impact = item.impact;
    if (impact == null || !impact.hasContractualData) {
      return const _SectionMessage(
        semanticsLabel: 'Section Impact à compléter',
        icon: Icons.insights_rounded,
        title: 'Informations d’impact à compléter',
        message:
            'Aucune métrique contractuelle n’est disponible pour ce projet.',
      );
    }
    final metrics = <MapEntry<String, String>>[
      if (impact.progress != null)
        MapEntry(
          'Progression opérationnelle',
          '${impact.progress!.toStringAsFixed(0)} %',
        ),
      if (impact.directBeneficiaries != null)
        MapEntry('Bénéficiaires directs', '${impact.directBeneficiaries}'),
      if (impact.indirectBeneficiaries != null)
        MapEntry('Bénéficiaires indirects', '${impact.indirectBeneficiaries}'),
      if (impact.reach != null) MapEntry('Portée', '${impact.reach}'),
      if (impact.jobsCreated != null)
        MapEntry('Emplois créés', '${impact.jobsCreated}'),
      if (impact.livesImpacted != null)
        MapEntry('Vies impactées', '${impact.livesImpacted}'),
      if (impact.treesPlanted != null)
        MapEntry('Arbres plantés', '${impact.treesPlanted}'),
      if (impact.wasteReduced != null)
        MapEntry('Déchets réduits', '${impact.wasteReduced}'),
      if (impact.waterSaved != null)
        MapEntry('Eau économisée', '${impact.waterSaved}'),
      if (impact.co2Reduced != null)
        MapEntry('CO₂ réduit', '${impact.co2Reduced}'),
    ];
    return _SectionPage(
      semanticsLabel: 'Section Impact du projet',
      title: 'Impact',
      children: [
        _OverviewGrid(
          children: metrics
              .map((entry) => _InfoCard(label: entry.key, value: entry.value))
              .toList(),
        ),
        if (item.hasIncompleteImpactContext) const _ImpactContextWarning(),
        if (impact.sdgs.isNotEmpty)
          _NarrativeCard(
            label: 'ODD documentés',
            value: impact.sdgs.join(', '),
          ),
        if (impact.methodology != null)
          _NarrativeCard(label: 'Méthodologie', value: impact.methodology),
      ],
    );
  }
}

class _ImpactContextWarning extends StatelessWidget {
  const _ImpactContextWarning();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Informations d’impact à compléter',
    child: Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: const ListTile(
        leading: Icon(Icons.info_outline_rounded),
        title: Text(
          'Informations d’impact à compléter',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Certaines informations de contexte du projet ne sont pas encore renseignées.',
        ),
      ),
    ),
  );
}

class _NextActionCard extends StatelessWidget {
  final ProjectPortfolioItem item;
  const _NextActionCard({required this.item});
  @override
  Widget build(BuildContext context) {
    if (item.tasksUnavailable) {
      return const _NarrativeCard(
        label: 'Prochaine action',
        value: 'Prochaine action indisponible',
      );
    }
    final action = item.nextAction;
    if (action == null) {
      return const _NarrativeCard(
        label: 'Prochaine action',
        value: 'Aucune prochaine action planifiée',
      );
    }
    return _NarrativeCard(
      label: 'Prochaine action',
      value:
          '${action.task.title}\nÉchéance ${action.task.dueDateLabel}\n${action.ownerLabel}',
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final ProjectPortfolioItem item;
  const _AlertsCard({required this.item});
  @override
  Widget build(BuildContext context) => _NarrativeCard(
    label: 'Alertes',
    value: item.tasksUnavailable
        ? 'Alertes indisponibles'
        : item.alerts.labels.isEmpty
        ? 'Aucune alerte'
        : item.alerts.labels.join('\n'),
  );
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final List<ProjectAssignee> assignees;
  const _TaskCard({required this.task, required this.assignees});
  @override
  Widget build(BuildContext context) {
    final due = DateTime.tryParse(task.dueDate ?? '');
    final overdue =
        due != null &&
        due.isBefore(DateTime.now()) &&
        !ProjectTaskPresentation.isTerminal(task.status);
    return Semantics(
      label:
          '${task.title}, ${ProjectTaskPresentation.statusLabel(task.status)}, ${ProjectTaskPresentation.priorityLabel(task.priority)}${overdue ? ', en retard' : ''}',
      child: Card(
        child: ListTile(
          title: Text(task.title),
          subtitle: Text(
            '${ProjectTaskPresentation.statusLabel(task.status)} · ${ProjectTaskPresentation.priorityLabel(task.priority)}\n'
            '${task.dueDateLabel} · ${assignees.isEmpty ? 'Responsable non renseigné' : assignees.map((item) => item.displayName).join(', ')}${overdue ? '\nEn retard' : ''}',
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final String role;
  final String name;
  const _MemberCard({required this.role, required this.name});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
      title: Text(name),
      subtitle: Text(role),
    ),
  );
}

class _OverviewGrid extends StatelessWidget {
  final List<Widget> children;
  const _OverviewGrid({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GridView.count(
      crossAxisCount: constraints.maxWidth >= 800
          ? 3
          : constraints.maxWidth >= 520
          ? 2
          : 1,
      childAspectRatio: constraints.maxWidth >= 800 ? 2.6 : 3.1,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _NarrativeCard extends StatelessWidget {
  final String label;
  final String? value;
  const _NarrativeCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text(
            value == null || value!.trim().isEmpty ? 'Non renseigné' : value!,
          ),
        ],
      ),
    ),
  );
}

class _SectionPage extends StatelessWidget {
  final String semanticsLabel;
  final String title;
  final List<Widget> children;
  const _SectionPage({
    required this.semanticsLabel,
    required this.title,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticsLabel,
    child: ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width >= 900 ? 28 : 16,
        vertical: 20,
      ),
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _SectionMessage extends StatelessWidget {
  final String semanticsLabel;
  final IconData icon;
  final String title;
  final String message;
  const _SectionMessage({
    required this.semanticsLabel,
    required this.icon,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticsLabel,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class ProjectDetailLoadingState extends StatelessWidget {
  const ProjectDetailLoadingState({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class ProjectDetailErrorState extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRetry;
  const ProjectDetailErrorState({
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
          const Icon(Icons.search_off_rounded, size: 52),
          const SizedBox(height: 14),
          const Text(
            'Projet introuvable ou indisponible',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton(
                onPressed: onBack,
                child: const Text('Retour au portefeuille'),
              ),
              FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ),
        ],
      ),
    ),
  );
}

String _date(DateTime? value) {
  if (value == null) return 'Non renseigné';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  return '${_date(local)} à ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
