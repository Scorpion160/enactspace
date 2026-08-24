import 'package:flutter/material.dart';

import '../models/project_portfolio_models.dart';

enum ProjectAlertFilter { all, blocked, overdue, noNextAction, incomplete }

class ProjectsPortfolioHeader extends StatelessWidget {
  final VoidCallback? onCreate;
  const ProjectsPortfolioHeader({super.key, this.onCreate});

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portefeuille Projets',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pilotez les priorités, les alertes et les prochaines actions.',
            ),
          ],
        );
        final action = onCreate == null
            ? null
            : FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nouveau projet'),
              );
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (action != null) ...[const SizedBox(height: 12), action],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: title),
            if (action != null) ...[const SizedBox(width: 12), action],
          ],
        );
      },
    ),
  );
}

class ProjectPortfolioFilters extends StatelessWidget {
  final bool compact;
  final TextEditingController searchController;
  final String selectedStatus;
  final String selectedResponsible;
  final ProjectAlertFilter selectedAlert;
  final Map<String, String> responsibleOptions;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onResponsibleChanged;
  final ValueChanged<ProjectAlertFilter> onAlertChanged;
  final VoidCallback onReset;

  const ProjectPortfolioFilters({
    super.key,
    required this.compact,
    required this.searchController,
    required this.selectedStatus,
    required this.selectedResponsible,
    required this.selectedAlert,
    required this.responsibleOptions,
    required this.onStatusChanged,
    required this.onResponsibleChanged,
    required this.onAlertChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final content = _FilterContent(
      searchController: searchController,
      selectedStatus: selectedStatus,
      selectedResponsible: selectedResponsible,
      selectedAlert: selectedAlert,
      responsibleOptions: responsibleOptions,
      onStatusChanged: onStatusChanged,
      onResponsibleChanged: onResponsibleChanged,
      onAlertChanged: onAlertChanged,
      onReset: onReset,
      vertical: compact,
    );
    if (!compact) return content;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        minTileHeight: 52,
        title: const Text('Filtres et recherche'),
        leading: const Icon(Icons.tune_rounded),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [content],
      ),
    );
  }
}

class _FilterContent extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedStatus;
  final String selectedResponsible;
  final ProjectAlertFilter selectedAlert;
  final Map<String, String> responsibleOptions;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onResponsibleChanged;
  final ValueChanged<ProjectAlertFilter> onAlertChanged;
  final VoidCallback onReset;
  final bool vertical;

  const _FilterContent({
    required this.searchController,
    required this.selectedStatus,
    required this.selectedResponsible,
    required this.selectedAlert,
    required this.responsibleOptions,
    required this.onStatusChanged,
    required this.onResponsibleChanged,
    required this.onAlertChanged,
    required this.onReset,
    required this.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      SizedBox(
        width: vertical ? double.infinity : 260,
        child: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Rechercher un projet',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
      _dropdown<String>(
        value: selectedStatus,
        label: 'Statut',
        items: {
          'all': 'Tous les statuts',
          for (final status in ProjectStatusPresentation.values)
            status: ProjectStatusPresentation.label(status),
        },
        onChanged: onStatusChanged,
      ),
      _dropdown<String>(
        value: selectedResponsible,
        label: 'Responsable',
        items: {'all': 'Tous les responsables', ...responsibleOptions},
        onChanged: onResponsibleChanged,
      ),
      _dropdown<ProjectAlertFilter>(
        value: selectedAlert,
        label: 'Alerte',
        items: const {
          ProjectAlertFilter.all: 'Toutes les situations',
          ProjectAlertFilter.blocked: 'Avec blocage',
          ProjectAlertFilter.overdue: 'En retard',
          ProjectAlertFilter.noNextAction: 'Sans prochaine action',
          ProjectAlertFilter.incomplete: 'Données incomplètes',
        },
        onChanged: onAlertChanged,
      ),
      TextButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.restart_alt_rounded),
        label: const Text('Réinitialiser'),
      ),
    ];
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
            fields.expand((item) => [item, const SizedBox(height: 10)]).toList()
              ..removeLast(),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 10, runSpacing: 10, children: fields),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required String label,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) => SizedBox(
    width: vertical ? double.infinity : 190,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map(
            (entry) => DropdownMenuItem<T>(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}

class ProjectPortfolioRow extends StatelessWidget {
  final ProjectPortfolioItem item;
  final VoidCallback onOpen;

  const ProjectPortfolioRow({
    super.key,
    required this.item,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => _ProjectSemantics(
    item: item,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(flex: 17, child: _ProjectIdentity(item: item)),
            Expanded(flex: 10, child: _ProjectLead(item: item)),
            Expanded(flex: 11, child: _ProjectProgress(item: item)),
            Expanded(flex: 18, child: _ProjectNextAction(item: item)),
            Expanded(flex: 12, child: _ProjectAlerts(item: item)),
            const SizedBox(width: 12),
            _OpenButton(item: item, onOpen: onOpen),
          ],
        ),
      ),
    ),
  );
}

class ProjectPortfolioCard extends StatelessWidget {
  final ProjectPortfolioItem item;
  final VoidCallback onOpen;

  const ProjectPortfolioCard({
    super.key,
    required this.item,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => _ProjectSemantics(
    item: item,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProjectIdentity(item: item),
            const SizedBox(height: 14),
            _ProjectLead(item: item),
            const SizedBox(height: 12),
            _ProjectProgress(item: item),
            const Divider(height: 26),
            _ProjectNextAction(item: item),
            const SizedBox(height: 12),
            _ProjectAlerts(item: item),
            const SizedBox(height: 14),
            _OpenButton(item: item, onOpen: onOpen, expanded: true),
          ],
        ),
      ),
    ),
  );
}

class _ProjectSemantics extends StatelessWidget {
  final ProjectPortfolioItem item;
  final Widget child;
  const _ProjectSemantics({required this.item, required this.child});
  @override
  Widget build(BuildContext context) =>
      Semantics(container: true, label: _semanticLabel(item), child: child);
}

class _OpenButton extends StatelessWidget {
  final ProjectPortfolioItem item;
  final VoidCallback onOpen;
  final bool expanded;
  const _OpenButton({
    required this.item,
    required this.onOpen,
    this.expanded = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Ouvrir le projet ${item.project.name}',
    child: FilledButton.tonal(
      onPressed: onOpen,
      style: expanded
          ? FilledButton.styleFrom(minimumSize: const Size(0, 48))
          : null,
      child: const Text('Ouvrir le projet'),
    ),
  );
}

class _ProjectIdentity extends StatelessWidget {
  final ProjectPortfolioItem item;
  const _ProjectIdentity({required this.item});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        item.project.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      const SizedBox(height: 6),
      Semantics(
        label: 'Statut ${ProjectStatusPresentation.label(item.project.status)}',
        child: Chip(
          visualDensity: VisualDensity.compact,
          label: Text(ProjectStatusPresentation.label(item.project.status)),
        ),
      ),
    ],
  );
}

class _ProjectLead extends StatelessWidget {
  final ProjectPortfolioItem item;
  const _ProjectLead({required this.item});
  @override
  Widget build(BuildContext context) => _LabelValue(
    label: 'Chef de projet',
    value: item.leadLabel,
    icon: Icons.person_outline_rounded,
  );
}

class _ProjectProgress extends StatelessWidget {
  final ProjectPortfolioItem item;
  const _ProjectProgress({required this.item});
  @override
  Widget build(BuildContext context) {
    final progress = item.impact?.progress;
    if (progress == null) {
      return const _LabelValue(
        label: 'Impact',
        value: 'Progression non disponible',
        icon: Icons.insights_rounded,
      );
    }
    return Semantics(
      label:
          'Progression opérationnelle ${progress.toStringAsFixed(0)} pour cent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progression opérationnelle',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: progress / 100),
          const SizedBox(height: 4),
          Text('${progress.toStringAsFixed(0)} %'),
        ],
      ),
    );
  }
}

class _ProjectNextAction extends StatelessWidget {
  final ProjectPortfolioItem item;
  const _ProjectNextAction({required this.item});
  @override
  Widget build(BuildContext context) {
    if (item.tasksUnavailable) {
      return const _LabelValue(
        label: 'Prochaine action',
        value: 'Prochaine action indisponible',
        icon: Icons.event_busy_rounded,
      );
    }
    final action = item.nextAction;
    if (action == null) {
      return const _LabelValue(
        label: 'Prochaine action',
        value: 'Aucune prochaine action planifiée',
        icon: Icons.event_available_rounded,
      );
    }
    return Semantics(
      label:
          'Prochaine action ${action.task.title}, échéance ${action.task.dueDateLabel}, responsable ${action.ownerLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prochaine action',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            action.task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text('Échéance ${action.task.dueDateLabel}'),
          Text(action.ownerLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ProjectAlerts extends StatelessWidget {
  final ProjectPortfolioItem item;
  const _ProjectAlerts({required this.item});
  @override
  Widget build(BuildContext context) {
    if (item.tasksUnavailable) {
      return const _LabelValue(
        label: 'Alertes',
        value: 'Alertes indisponibles',
        icon: Icons.warning_amber_rounded,
      );
    }
    final labels = item.alerts.labels;
    return Semantics(
      label: labels.isEmpty ? 'Aucune alerte' : labels.join(', '),
      child: _LabelValue(
        label: 'Alertes',
        value: labels.isEmpty ? 'Aucune alerte' : labels.join('\n'),
        icon: labels.isEmpty
            ? Icons.check_circle_outline_rounded
            : Icons.warning_amber_rounded,
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _LabelValue({
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(value, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  );
}

class ProjectPortfolioLoadingState extends StatelessWidget {
  const ProjectPortfolioLoadingState({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: 'Chargement du portefeuille Projets',
      child: const CircularProgressIndicator(),
    ),
  );
}

class ProjectPortfolioErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const ProjectPortfolioErrorState({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => _CenteredState(
    icon: Icons.cloud_off_rounded,
    title: 'Impossible de charger les projets',
    message: 'Le portefeuille est indisponible. Réessaie dans un instant.',
    action: FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
  );
}

class ProjectPortfolioEmptyState extends StatelessWidget {
  const ProjectPortfolioEmptyState({super.key});
  @override
  Widget build(BuildContext context) => const _CenteredState(
    icon: Icons.inventory_2_outlined,
    title: 'Aucun projet',
    message: 'Aucun projet n’est disponible dans le portefeuille.',
  );
}

class ProjectNoFilterResultsState extends StatelessWidget {
  const ProjectNoFilterResultsState({super.key});
  @override
  Widget build(BuildContext context) => const _CenteredState(
    icon: Icons.filter_alt_off_rounded,
    title: 'Aucun résultat',
    message: 'Aucun projet ne correspond aux filtres sélectionnés.',
  );
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Center(
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
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

String _semanticLabel(ProjectPortfolioItem item) {
  final progress = item.impact?.progress;
  final alerts = item.tasksUnavailable
      ? 'alertes indisponibles'
      : item.alerts.labels.isEmpty
      ? 'aucune alerte'
      : item.alerts.labels.join(', ');
  return '${item.project.name}, statut ${ProjectStatusPresentation.label(item.project.status)}, ${item.leadLabel}, ${progress == null ? 'progression non disponible' : 'progression opérationnelle ${progress.toStringAsFixed(0)} pour cent'}, $alerts';
}
