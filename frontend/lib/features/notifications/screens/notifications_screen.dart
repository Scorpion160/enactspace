import 'package:flutter/material.dart';
import '../../../shared/widgets/module_placeholder.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Notifications',
      subtitle: 'Alertes, rappels, messages importants et suivi des lectures.',
      icon: Icons.notifications_rounded,
    );
  }
}
