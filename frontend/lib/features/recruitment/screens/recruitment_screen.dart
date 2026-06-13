import 'package:flutter/material.dart';
import '../../../shared/widgets/module_placeholder.dart';

class RecruitmentScreen extends StatelessWidget {
  const RecruitmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Recrutement',
      subtitle: 'Campagnes, candidatures, évaluations et conversion en membre.',
      icon: Icons.how_to_reg_rounded,
    );
  }
}
