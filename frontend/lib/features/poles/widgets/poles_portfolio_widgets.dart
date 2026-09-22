import 'package:flutter/material.dart';

import '../models/pole_portfolio_models.dart';

class PolesPortfolioHeader extends StatelessWidget {
  final VoidCallback? onCreate;

  const PolesPortfolioHeader({super.key, this.onCreate});

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    runSpacing: 12,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portefeuille des pôles',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Gouvernance, alertes et prochaines actions réelles.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
      if (onCreate != null)
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Créer un pôle'),
        ),
    ],
  );
}

class PolePortfolioFilters extends StatelessWidget {
  final bool compact;
  final TextEditingController searchController;
  final String selectedType;
  final String selectedResponsible;
  final PoleAlertFilter selectedAlert;
  final Map<String, String> responsibleOptions;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onResponsibleChanged;
  final ValueChanged<PoleAlertFilter> onAlertChanged;
  final VoidCallback onReset;

  const PolePortfolioFilters({
    super.key,
    required this.compact,
    required this.searchController,
    required this.selectedType,
    required this.selectedResponsible,
    required this.selectedAlert,
    required this.responsibleOptions,
    required this.onTypeChanged,
    required this.onResponsibleChanged,
    required this.onAlertChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final fields = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: compact ? double.infinity : 280,
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Rechercher un pôle',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: compact ? double.infinity : 190,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: selectedType,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tous les types')),
              DropdownMenuItem(value: 'metier', child: Text('Pôle cœur')),
              DropdownMenuItem(value: 'support', child: Text('Pôle support')),
              DropdownMenuItem(
                value: 'unknown',
                child: Text('Type non reconnu'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onTypeChanged(value);
            },
          ),
        ),
        SizedBox(
          width: compact ? double.infinity : 220,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: selectedResponsible,
            decoration: const InputDecoration(
              labelText: 'Responsable',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('Tous les responsables'),
              ),
              ...responsibleOptions.entries.map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) onResponsibleChanged(value);
            },
          ),
        ),
        SizedBox(
          width: compact ? double.infinity : 220,
          child: DropdownButtonFormField<PoleAlertFilter>(
            isExpanded: true,
            initialValue: selectedAlert,
            decoration: const InputDecoration(
              labelText: 'Alertes',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: PoleAlertFilter.all,
                child: Text('Toutes les situations'),
              ),
              DropdownMenuItem(
                value: PoleAlertFilter.blocked,
                child: Text('Avec blocage'),
              ),
              DropdownMenuItem(
                value: PoleAlertFilter.overdue,
                child: Text('En retard'),
              ),
              DropdownMenuItem(
                value: PoleAlertFilter.noNextAction,
                child: Text('Sans prochaine action'),
              ),
              DropdownMenuItem(
                value: PoleAlertFilter.noLead,
                child: Text('Sans chef'),
              ),
              DropdownMenuItem(
                value: PoleAlertFilter.noDeputy,
                child: Text('Sans adjoint'),
              ),
              DropdownMenuItem(
                value: PoleAlertFilter.noTeam,
                child: Text('Sans équipe'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onAlertChanged(value);
            },
          ),
        ),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Réinitialiser'),
        ),
      ],
    );
    if (!compact) return fields;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('Filtres et recherche'),
        leading: const Icon(Icons.tune_rounded),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [fields],
      ),
    );
  }
}

class PolePortfolioRow extends StatelessWidget {
  final PolePortfolioItem item;
  final VoidCallback onOpen;

  const PolePortfolioRow({super.key, required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: _semanticLabel(item),
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(flex: 18, child: _PoleIdentity(item: item)),
            Expanded(flex: 18, child: _Leadership(item: item)),
            Expanded(flex: 13, child: _Team(item: item)),
            Expanded(flex: 18, child: _Alerts(item: item)),
            Expanded(flex: 24, child: _NextAction(item: item)),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: onOpen,
              child: const Text('Ouvrir le pôle'),
            ),
          ],
        ),
      ),
    ),
  );
}

class PolePortfolioCard extends StatelessWidget {
  final PolePortfolioItem item;
  final VoidCallback onOpen;

  const PolePortfolioCard({
    super.key,
    required this.item,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: _semanticLabel(item),
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PoleIdentity(item: item),
            const Divider(height: 24),
            _Leadership(item: item),
            const SizedBox(height: 12),
            _Team(item: item),
            const SizedBox(height: 12),
            _Alerts(item: item),
            const SizedBox(height: 12),
            _NextAction(item: item),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onOpen,
              child: const Text('Ouvrir le pôle'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PoleIdentity extends StatelessWidget {
  final PolePortfolioItem item;
  const _PoleIdentity({required this.item});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        item.pole.name,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        '${item.pole.displayShortName} · ${PoleTypePresentation.label(item.pole.type)}',
      ),
    ],
  );
}

class _Leadership extends StatelessWidget {
  final PolePortfolioItem item;
  const _Leadership({required this.item});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Chef de pôle : ${item.leadLabel}'),
      const SizedBox(height: 4),
      Text('Adjoint du pôle : ${item.deputyLabel}'),
    ],
  );
}

class _Team extends StatelessWidget {
  final PolePortfolioItem item;
  const _Team({required this.item});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.groups_2_outlined, size: 20),
      const SizedBox(width: 7),
      Expanded(child: Text(item.teamLabel)),
    ],
  );
}

class _Alerts extends StatelessWidget {
  final PolePortfolioItem item;
  const _Alerts({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.tasksUnavailable) return const Text('Alertes indisponibles');
    if (!item.alerts.hasAlerts) return const Text('Aucune alerte active');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: item.alerts.labels
          .map(
            (label) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18),
                  const SizedBox(width: 5),
                  Expanded(child: Text(label)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _NextAction extends StatelessWidget {
  final PolePortfolioItem item;
  const _NextAction({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.tasksUnavailable) {
      return const Text('Prochaine action indisponible');
    }
    final action = item.nextAction;
    if (action == null) return const Text('Aucune prochaine action planifiée');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(action.task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text('${action.task.dueDateLabel} · ${action.ownerLabel}'),
      ],
    );
  }
}

String _semanticLabel(PolePortfolioItem item) {
  final alerts = item.tasksUnavailable
      ? 'alertes indisponibles'
      : item.alerts.labels.join(', ');
  return 'Pôle ${item.pole.name}, ${PoleTypePresentation.label(item.pole.type)}, '
      'chef ${item.leadLabel}, adjoint ${item.deputyLabel}, ${item.teamLabel}, '
      '${alerts.isEmpty ? 'aucune alerte' : alerts}, prochaine action '
      '${item.tasksUnavailable ? 'indisponible' : item.nextAction?.task.title ?? 'non planifiée'}';
}

class PolePortfolioLoadingState extends StatelessWidget {
  const PolePortfolioLoadingState({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: 'Chargement des pôles',
      child: const CircularProgressIndicator(),
    ),
  );
}

class PolePortfolioErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const PolePortfolioErrorState({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => _MessageState(
    icon: Icons.cloud_off_rounded,
    title: 'Impossible de charger les pôles',
    message: 'La liste est indisponible. Vérifiez la connexion puis réessayez.',
    action: FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
  );
}

class PolePortfolioEmptyState extends StatelessWidget {
  const PolePortfolioEmptyState({super.key});
  @override
  Widget build(BuildContext context) => const _MessageState(
    icon: Icons.account_tree_outlined,
    title: 'Aucun pôle',
    message: 'Aucun pôle n’est disponible pour le moment.',
  );
}

class PoleNoFilterResultsState extends StatelessWidget {
  const PoleNoFilterResultsState({super.key});
  @override
  Widget build(BuildContext context) => const _MessageState(
    icon: Icons.filter_alt_off_rounded,
    title: 'Aucun résultat',
    message: 'Aucun pôle ne correspond aux filtres sélectionnés.',
  );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const _MessageState({
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
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
