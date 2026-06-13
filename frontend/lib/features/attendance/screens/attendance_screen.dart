import 'package:flutter/material.dart';
import '../../../shared/widgets/module_placeholder.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Présences',
      subtitle:
          'Sessions de présence, retards, absences, justifications et pénalités.',
      icon: Icons.fact_check_rounded,
    );
  }
}
