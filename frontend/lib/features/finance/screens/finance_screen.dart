import 'package:flutter/material.dart';
import '../../../shared/widgets/module_placeholder.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Finance',
      subtitle: 'Cotisations, pénalités, paiements et suivi financier.',
      icon: Icons.payments_rounded,
    );
  }
}
