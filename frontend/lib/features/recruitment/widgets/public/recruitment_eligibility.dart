import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/academic/esp_academic_catalog.dart';

const recruitmentTerminalLevels = {'DIC3', 'DESCAF3', 'Master2', 'DIT2'};

List<String> get recruitmentAcademicLevels => espAcademicLevels
    .where((level) => !recruitmentTerminalLevels.contains(level))
    .toList();

class RecruitmentEligibilityCriteria extends StatelessWidget {
  const RecruitmentEligibilityCriteria({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Qui peut candidater ?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(
            'Tu peux candidater si tu étudies à l’ESP, que tu es engagé dans moins de trois clubs ou structures étudiantes et que ton niveau d’études est éligible.\n\n'
            'Les candidatures en DIC3, DESCAF3, Master2 et DIT2 ne sont pas acceptées. '
            'Un engagement dans trois clubs ou structures étudiantes ou plus rend également la candidature inéligible.',
            style: TextStyle(height: 1.55),
          ),
          const SizedBox(height: 10),
          const Text('Vérifie ces critères avant de préparer tes réponses et tes documents.'),
        ],
      ),
    ),
  );
}

class RecruitmentEligibilityCheck extends StatefulWidget {
  final void Function(String level, int clubsCount) onEligible;
  const RecruitmentEligibilityCheck({super.key, required this.onEligible});

  @override
  State<RecruitmentEligibilityCheck> createState() => _RecruitmentEligibilityCheckState();
}

class _RecruitmentEligibilityCheckState extends State<RecruitmentEligibilityCheck> {
  final _clubs = TextEditingController();
  String? _level;

  @override
  void dispose() {
    _clubs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = int.tryParse(_clubs.text);
    final terminal = recruitmentTerminalLevels.contains(_level);
    final tooManyClubs = count != null && count >= 3;
    final eligible = _level != null && !terminal && count != null && count >= 0 && count < 3;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Vérifie ton éligibilité', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const RecruitmentEligibilityCriteria(),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                key: const Key('eligibility-study-level'),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ton niveau d’études actuel'),
                items: [
                  for (final level in espAcademicLevels)
                    DropdownMenuItem(value: level, child: Text(level)),
                ],
                onChanged: (value) => setState(() => _level = value),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('eligibility-clubs-count'),
                controller: _clubs,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nombre de clubs et structures étudiantes déjà rejoints',
                  helperText: 'Indique 0 si tu n’en as rejoint aucun.',
                  helperMaxLines: 3,
                ),
              ),
              if (terminal || tooManyClubs) ...[
                const SizedBox(height: 18),
                Text(
                  terminal
                      ? 'Ton niveau d’études fait partie des années non éligibles pour cette campagne.'
                      : 'Un engagement dans trois clubs ou structures étudiantes ou plus est un critère d’inéligibilité.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, height: 1.5),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('eligibility-continue'),
                onPressed: eligible ? () => widget.onEligible(_level ?? '', int.parse(_clubs.text)) : null,
                child: const Text('Continuer vers le formulaire'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
