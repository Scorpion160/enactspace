import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Column(
            children: [
              Icon(Icons.task_alt_rounded, size: 48, color: Colors.black38),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  if (task.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.secondaryText),
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
                  ? const Text(
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
                    const SizedBox(height: 10),
                    metadata,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, size: 18),
                        const SizedBox(width: 6),
                        Expanded(child: people),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Ouvrir'),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 4, child: title),
                  const SizedBox(width: 18),
                  Expanded(flex: 4, child: metadata),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: people),
                  IconButton(
                    onPressed: onOpen,
                    tooltip: 'Ouvrir',
                    icon: const Icon(Icons.chevron_right_rounded),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: danger
            ? Colors.red.shade50
            : Colors.black.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: danger ? Colors.red.shade700 : null),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: danger ? Colors.red.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }
}
