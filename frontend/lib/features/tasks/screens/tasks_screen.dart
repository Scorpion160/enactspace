import 'package:flutter/material.dart';
import '../../../shared/widgets/module_placeholder.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Tâches',
      subtitle: 'Kanban, assignations, échéances, preuves et validation.',
      icon: Icons.task_alt_rounded,
    );
  }
}
