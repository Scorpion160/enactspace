import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';

/// Records decisions, never infers absences from an elapsed appointment or
/// dispatches e-mail. Jurors report the absence in the attendance dialog first.
Future<bool> showInterviewOutcomeDialog(
  BuildContext context, {
  required String applicationId,
  required String candidateName,
}) async {
  final api = ApiClient();
  final token = await AuthService().getToken();
  if (token == null || !context.mounted) return false;
  final base = '/recruitment/applications/$applicationId/interview';
  Map<String, dynamic> summary;
  try {
    summary = Map<String, dynamic>.from(
      await api.get('$base/absence-summary', token: token) as Map,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de charger le suivi des absences.'),
        ),
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  final reason = TextEditingController();
  var busy = false;
  String? error;
  try {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (root) => StatefulBuilder(
            builder: (dialog, update) {
              Future<void> decide({
                required String label,
                required String endpoint,
              }) async {
                if (reason.text.trim().length < 12) {
                  update(
                    () => error =
                        'Indique un motif précis (12 caractères minimum).',
                  );
                  return;
                }
                final accepted = await showDialog<bool>(
                  context: root,
                  builder: (confirmation) => AlertDialog(
                    title: Text(label),
                    content: Text(
                      'Confirmer cette décision pour $candidateName ? '
                      'Elle sera enregistrée dans l’historique de recrutement. '
                      'Aucun e-mail ne sera envoyé automatiquement.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmation, false),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(confirmation, true),
                        child: const Text('Confirmer'),
                      ),
                    ],
                  ),
                );
                if (accepted != true || !root.mounted) return;
                update(() {
                  busy = true;
                  error = null;
                });
                try {
                  await api.postJson(
                    '$base/$endpoint',
                    token: token,
                    data: {'reason': reason.text.trim(), 'confirmed': true},
                  );
                  if (root.mounted) {
                    ScaffoldMessenger.of(root).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Décision enregistrée. Aucune notification envoyée.',
                        ),
                      ),
                    );
                    Navigator.pop(root, true);
                  }
                } catch (e) {
                  if (root.mounted) {
                    update(() {
                      error = e is ApiException
                          ? e.message
                          : 'Impossible de valider la décision. Réessaie.';
                    });
                  }
                } finally {
                  if (root.mounted) update(() => busy = false);
                }
              }

              final count = (summary['count'] as num?)?.toInt() ?? 0;
              final limit = (summary['limit'] as num?)?.toInt() ?? 3;
              final dates = (summary['dates'] as List? ?? const [])
                  .map((item) => item.toString())
                  .join(' · ');
              final excluded = summary['can_exclude'] == true;
              final isManager = summary['can_manage'] == true;
              final isActive =
                  summary['application_status'] == 'interview_scheduled';
              return AlertDialog(
                title: Text('Absences et désistement — $candidateName'),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$count absence(s) confirmée(s) sur $limit autorisées',
                          style: Theme.of(dialog).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (dates.isNotEmpty)
                          Text('Dates des absences : $dates'),
                        if (summary['last_chance'] == true) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Dernière chance : une nouvelle absence '
                            'confirmée devra faire l’objet d’une décision.',
                          ),
                        ],
                        if ((summary['requires_decision'] == true) && !excluded)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'La limite est atteinte. La coordination doit '
                              'vérifier le dossier avant toute exclusion.',
                            ),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          'Une absence n’est comptabilisée que lorsqu’un juré '
                          'ou un responsable l’a explicitement enregistrée. '
                          'La fin d’un créneau ne suffit pas.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: reason,
                          maxLines: 3,
                          maxLength: 1000,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Motif de la décision',
                            hintText: 'Précise la source de la confirmation',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            if (error != null) update(() => error = null);
                          },
                        ),
                        if (error != null)
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(dialog).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(root, false),
                    child: const Text('Fermer'),
                  ),
                  if (isManager && isActive)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('Confirmer le désistement'),
                      onPressed: busy
                          ? null
                          : () => decide(
                              label: 'Enregistrer un désistement',
                              endpoint: 'withdraw',
                            ),
                    ),
                  if (excluded)
                    FilledButton.icon(
                      icon: const Icon(Icons.rule_outlined),
                      label: const Text('Confirmer l’exclusion'),
                      onPressed: busy
                          ? null
                          : () => decide(
                              label: 'Exclure après les absences confirmées',
                              endpoint: 'exclude-no-show',
                            ),
                    ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              );
            },
          ),
        ) ??
        false;
  } finally {
    reason.dispose();
  }
}
