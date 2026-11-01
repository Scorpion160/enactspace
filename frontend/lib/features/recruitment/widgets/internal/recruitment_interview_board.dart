import 'package:flutter/material.dart';
import '../../models/application_model.dart';
import '../recruitment_workspace.dart';

class RecruitmentInterviewBoard extends StatelessWidget {
  final List<ApplicationModel> applications;
  final bool anonymized;
  final ValueChanged<ApplicationModel> onOpen;
  const RecruitmentInterviewBoard({
    super.key,
    required this.applications,
    required this.anonymized,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final scheduled = applications.where((a) => a.interviewAt != null).toList()
      ..sort((a, b) => a.interviewAt!.compareTo(b.interviewAt!));
    final pending = applications
        .where(
          (a) =>
              a.status == 'interview_scheduled' &&
              (a.interviewAt == null || a.interviewNeedsReassignment),
        )
        .toList();
    String name(ApplicationModel a) =>
        anonymized || a.isAnonymized ? a.anonymousCode : a.fullName;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RecruitmentNotice(
          'Les horaires sont affichés à Dakar. Ouvre un dossier pour planifier ou modifier le créneau, l’équipe et le format, selon tes droits.',
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'À planifier ou réattribuer',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final a in pending)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(Icons.event_busy_outlined, color: colors.error),
                title: Text(name(a)),
                subtitle: Text(
                  a.interviewNeedsReassignment
                      ? 'Composition du jury à actualiser'
                      : 'Date à confirmer',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpen(a),
              ),
            ),
        ],
        const SizedBox(height: 20),
        Text(
          'Planning des entretiens',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (scheduled.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucun entretien daté pour les filtres sélectionnés. Les dossiers restent accessibles depuis Candidatures.',
              ),
            ),
          ),
        for (final a in scheduled)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RecruitmentPageHeading(
                      title: name(a),
                      subtitle: '${a.interviewLabel} · Dakar',
                      actions: [
                        OutlinedButton.icon(
                          onPressed: () => onOpen(a),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Ouvrir le dossier'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(switch (a.interviewMode) {
                          'online' => 'En ligne',
                          'hybrid' => 'Mixte',
                          'in_person' => 'Présentiel',
                          _ => 'Format à confirmer',
                        }),
                        if (a.interviewLocation?.isNotEmpty == true)
                          Text(a.interviewLocation!),
                        if (a.interviewTeam?['name'] != null)
                          Text('Équipe : ${a.interviewTeam!['name']}'),
                      ],
                    ),
                    if (a.interviewNeedsReassignment)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Jury à réattribuer',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
