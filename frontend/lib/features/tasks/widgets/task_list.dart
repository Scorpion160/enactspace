import 'package:flutter/material.dart';

import '../models/task_center_models.dart';
import '../models/task_model.dart';

class TaskCenterList extends StatelessWidget {
  final List<TaskModel> tasks;
  final TaskCenterData data;
  final DateTime now;
  final ValueChanged<TaskModel> onOpen;

  const TaskCenterList({
    super.key,
    required this.tasks,
    required this.data,
    required this.now,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Column(
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 12),
              Text(
                'Aucune tâche',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text('Aucune tâche ne correspond à cette vue et à ces filtres.'),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TaskRow(
              task: task,
              data: data,
              now: now,
              onOpen: () => onOpen(task),
            ),
          ),
      ],
    );
  }
}

class TaskBoard extends StatelessWidget {
  const TaskBoard({
    super.key,
    required this.tasks,
    required this.data,
    required this.now,
    required this.onOpen,
  });

  final List<TaskModel> tasks;
  final TaskCenterData data;
  final DateTime now;
  final ValueChanged<TaskModel> onOpen;

  @override
  Widget build(BuildContext context) {
    final toDo = <TaskModel>[];
    final inProgress = <TaskModel>[];
    final finished = <TaskModel>[];
    final other = <TaskModel>[];
    for (final task in tasks) {
      switch (task.status) {
        case 'a_faire':
          toDo.add(task);
        case 'en_cours':
        case 'bloque':
        case 'termine':
          inProgress.add(task);
        case 'valide':
          finished.add(task);
        default:
          other.add(task);
      }
    }

    final colors = Theme.of(context).colorScheme;
    final lanes = [
      _lane(
        context,
        'À faire',
        Icons.radio_button_unchecked,
        colors.secondaryContainer,
        toDo,
      ),
      _lane(
        context,
        'En cours',
        Icons.timelapse_rounded,
        colors.tertiaryContainer,
        inProgress,
      ),
      _lane(
        context,
        'Terminées',
        Icons.task_alt_rounded,
        colors.primaryContainer,
        finished,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: lanes,
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [for (final lane in lanes) Expanded(child: lane)],
            );
          },
        ),
        if (other.isNotEmpty) ...[
          const SizedBox(height: 12),
          _lane(
            context,
            'Hors tableau',
            Icons.inventory_2_outlined,
            colors.surfaceContainerHighest,
            other,
          ),
        ],
      ],
    );
  }

  Widget _lane(
    BuildContext context,
    String title,
    IconData icon,
    Color accent,
    List<TaskModel> laneTasks,
  ) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('task-lane-$title'),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Semantics(
                header: true,
                child: Row(
                  spacing: 8,
                  children: [
                    Icon(icon, size: 20, color: theme.colorScheme.onSurface),
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleSmall),
                    ),
                    Text(
                      '${laneTasks.length}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
            if (laneTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Aucune tâche', style: theme.textTheme.bodySmall),
              )
            else
              for (final task in laneTasks)
                _TaskRow(
                  task: task,
                  data: data,
                  now: now,
                  onOpen: () => onOpen(task),
                ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final TaskModel task;
  final TaskCenterData data;
  final DateTime now;
  final VoidCallback onOpen;

  const _TaskRow({
    required this.task,
    required this.data,
    required this.now,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final assignees = data.assigneesByTaskId[task.id] ?? const [];
    final names = assignees
        .map((item) => data.member(item.userId)?.displayName ?? 'Membre')
        .toList();
    final pole = data.pole(task.poleId)?.name;
    final project = data.project(task.projectId)?.name;
    final late = task.isLateAt(now);
    return Card(
      key: Key('task-${task.id}'),
      elevation: 0,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  if (task.description?.trim().isNotEmpty == true) ...[
                    SizedBox(height: 4),
                    Text(
                      task.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              );
              final metadata = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(task.statusLabel, Icons.radio_button_checked_rounded),
                  _Badge(task.priorityLabel, Icons.flag_rounded),
                  _Badge(task.dueDateLabel, Icons.event_rounded, danger: late),
                  if (late)
                    const _Badge(
                      'En retard',
                      Icons.warning_rounded,
                      danger: true,
                    ),
                  if (task.proofRequired)
                    const _Badge('Preuve requise', Icons.link_rounded),
                  if (pole != null) _Badge(pole, Icons.hub_rounded),
                  if (project != null)
                    _Badge(project, Icons.rocket_launch_rounded),
                ],
              );
              final people = data.assigneeErrorTaskIds.contains(task.id)
                  ? Text(
                      'Assignés indisponibles',
                      style: TextStyle(color: Colors.orange),
                    )
                  : Text(
                      names.isEmpty ? 'Aucun assigné' : names.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    SizedBox(height: 10),
                    metadata,
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.people_alt_rounded, size: 18),
                        SizedBox(width: 6),
                        Expanded(child: people),
                      ],
                    ),
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onOpen,
                        icon: Icon(Icons.open_in_new_rounded),
                        label: Text('Ouvrir'),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 4, child: title),
                  SizedBox(width: 18),
                  Expanded(flex: 4, child: metadata),
                  SizedBox(width: 18),
                  Expanded(flex: 2, child: people),
                  IconButton(
                    onPressed: onOpen,
                    tooltip: 'Ouvrir',
                    icon: Icon(Icons.chevron_right_rounded),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool danger;
  const _Badge(this.label, this.icon, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: danger ? colors.errorContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: danger ? colors.onErrorContainer : colors.onSurfaceVariant,
          ),
          SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: danger
                    ? colors.onErrorContainer
                    : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
