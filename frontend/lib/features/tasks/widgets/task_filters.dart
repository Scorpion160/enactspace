import 'package:flutter/material.dart';
import 'package:frontend/shared/ui/app_filter_toolbar.dart';

import '../../members/models/member_model.dart';
import '../../poles/models/pole_model.dart';
import '../../projects/models/project_model.dart';

class TaskFiltersBar extends StatelessWidget {
  final TextEditingController searchController;
  final String status;
  final String priority;
  final String? poleId;
  final String? projectId;
  final String? assigneeId;
  final List<PoleModel> poles;
  final List<ProjectModel> projects;
  final List<MemberModel> members;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String?> onPoleChanged;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String?> onAssigneeChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onReset;

  const TaskFiltersBar({
    super.key,
    required this.searchController,
    required this.status,
    required this.priority,
    required this.poleId,
    required this.projectId,
    required this.assigneeId,
    required this.poles,
    required this.projects,
    required this.members,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onPoleChanged,
    required this.onProjectChanged,
    required this.onAssigneeChanged,
    required this.onSearchChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return AppFilterToolbar(
      search: TextField(
        key: const Key('tasks-search'),
        controller: searchController,
        onChanged: (_) => onSearchChanged(),
        decoration: const InputDecoration(
          hintText: 'Rechercher',
          prefixIcon: Icon(Icons.search_rounded),
          isDense: true,
        ),
      ),
      quickFilters: const [],
      filters: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: const Key('tasks-status-filter'),
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Statut', isDense: true),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tous')),
            DropdownMenuItem(value: 'a_faire', child: Text('À faire')),
            DropdownMenuItem(value: 'en_cours', child: Text('En cours')),
            DropdownMenuItem(value: 'bloque', child: Text('Bloqué')),
            DropdownMenuItem(value: 'termine', child: Text('Terminé')),
            DropdownMenuItem(value: 'valide', child: Text('Validé')),
            DropdownMenuItem(value: 'annule', child: Text('Annulé')),
          ],
          onChanged: (value) => onStatusChanged(value ?? 'all'),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: const Key('tasks-priority-filter'),
          initialValue: priority,
          decoration: const InputDecoration(
            labelText: 'Priorité',
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Toutes')),
            DropdownMenuItem(value: 'basse', child: Text('Basse')),
            DropdownMenuItem(value: 'normale', child: Text('Normale')),
            DropdownMenuItem(value: 'haute', child: Text('Haute')),
            DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
          ],
          onChanged: (value) => onPriorityChanged(value ?? 'all'),
        ),
        if (poles.isNotEmpty)
          DropdownButtonFormField<String?>(
            isExpanded: true,
            key: const Key('tasks-pole-filter'),
            initialValue: poleId,
            decoration: const InputDecoration(labelText: 'Pôle', isDense: true),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tous les pôles'),
              ),
              ...poles.map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              ),
            ],
            onChanged: onPoleChanged,
          ),
        if (projects.isNotEmpty)
          DropdownButtonFormField<String?>(
            isExpanded: true,
            key: const Key('tasks-project-filter'),
            initialValue: projectId,
            decoration: const InputDecoration(
              labelText: 'Projet',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tous les projets'),
              ),
              ...projects.map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              ),
            ],
            onChanged: onProjectChanged,
          ),
        if (members.isNotEmpty)
          DropdownButtonFormField<String?>(
            isExpanded: true,
            key: const Key('tasks-assignee-filter'),
            initialValue: assigneeId,
            decoration: const InputDecoration(
              labelText: 'Assigné',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tous les assignés'),
              ),
              ...members.map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(item.displayName),
                ),
              ),
            ],
            onChanged: onAssigneeChanged,
          ),
      ],
      actions: [
        TextButton.icon(
          key: const Key('tasks-reset'),
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Réinitialiser'),
        ),
      ],
      activeFilterCount:
          [status, priority].where((v) => v != 'all').length +
          [poleId, projectId, assigneeId].where((v) => v != null).length,
    );
  }
}
