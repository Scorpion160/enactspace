import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';

/// Nothing leaves EnactSpace until the organizer previews AND confirms.
Future<bool> showInterviewCommunicationDialog(
  BuildContext context, {
  required String campaignId,
  String? applicationId,
  String? candidateName,
  DateTime? proposedDay,
  String initialAction = 'reminder',
  bool candidateOnly = false,
}) async {
  final token = await AuthService().getToken();
  if (token == null || !context.mounted) return false;
  final api = ApiClient();
  final location = TextEditingController();
  final reason = TextEditingController();
  final fromTime = TextEditingController(text: '00:00');
  final untilTime = TextEditingController(text: '23:59');
  var action = const {'publish', 'venue', 'reminder'}.contains(initialAction)
      ? initialAction
      : 'reminder';
  var confirmUnrecordedAvailability = false;
  var dayMode = applicationId == null;
  var day = proposedDay ?? DateTime.now();
  var toCandidates = true;
  var toJurors = true;
  var loading = false;
  String? error;
  Map<String, dynamic>? preview;
  String? batchId;

  String dayText(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String endpoint(String suffix) =>
      '/recruitment/campaigns/$campaignId/interviews/communications/$suffix';
  Map<String, dynamic> payload() => {
    'action': action,
    'application_ids': dayMode ? <String>[] : [applicationId!],
    'interview_date': dayMode ? dayText(day) : null,
    'from_time': fromTime.text.trim(),
    'until_time': untilTime.text.trim(),
    'location': action == 'reminder' || location.text.trim().isEmpty
        ? null
        : location.text.trim(),
    'exception_reason': action != 'publish' || reason.text.trim().isEmpty
        ? null
        : reason.text.trim(),
    'confirm_unrecorded_jury_availability':
        action == 'publish' && confirmUnrecordedAvailability,
    'send_candidates': toCandidates,
    'send_jurors': toJurors,
  };
  String explain(Object e) => e is ApiException
      ? e.message
      : 'Opération indisponible. Vérifie ta connexion et réessaie.';

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, update) {
        void invalidate() => update(() {
          preview = null;
          batchId = null;
          error = null;
        });

        Future<void> inspect() async {
          update(() {
            loading = true;
            preview = null;
            error = null;
          });
          try {
            final result = Map<String, dynamic>.from(
              await api.postJson(
                    endpoint('preview'),
                    token: token,
                    data: payload(),
                  )
                  as Map,
            );
            if (dialog.mounted) {
              update(() {
                preview = result;
                batchId = const Uuid().v4();
              });
            }
          } catch (e) {
            if (dialog.mounted) update(() => error = explain(e));
          } finally {
            if (dialog.mounted) update(() => loading = false);
          }
        }

        Future<void> confirm() async {
          if (preview == null || batchId == null) return;
          update(() {
            loading = true;
            error = null;
          });
          try {
            final result = Map<String, dynamic>.from(
              await api.postJson(
                    endpoint('send'),
                    token: token,
                    data: {
                      ...payload(),
                      'batch_id': batchId,
                      'preview_signature': preview!['signature'],
                    },
                  )
                  as Map,
            );
            if (dialog.mounted) {
              final count = result['queued'] as num? ?? 0;
              ScaffoldMessenger.of(dialog).showSnackBar(
                SnackBar(
                  content: Text(
                    result['already_sent'] == true
                        ? 'Ce lot a déjà été enregistré.'
                        : '$count message(s) en file d’envoi.',
                  ),
                ),
              );
              Navigator.of(dialog).pop(true);
            }
          } catch (e) {
            if (dialog.mounted) update(() => error = explain(e));
          } finally {
            if (dialog.mounted) update(() => loading = false);
          }
        }

        Future<void> history() async {
          update(() {
            loading = true;
            error = null;
          });
          try {
            final result = Map<String, dynamic>.from(
              await api.get(endpoint('history'), token: token) as Map,
            );
            if (!dialog.mounted) return;
            final batches = (result['batches'] as List? ?? const [])
                .whereType<Map>()
                .toList();
            await showDialog<void>(
              context: dialog,
              builder: (inner) => AlertDialog(
                title: const Text('Historique des envois'),
                content: SizedBox(
                  width: 520,
                  height: 320,
                  child: batches.isEmpty
                      ? const Center(
                          child: Text('Aucun envoi pour cette campagne.'),
                        )
                      : ListView(
                          children: [
                            for (final item in batches)
                              ListTile(
                                title: Text(
                                  '${item['date'] ?? ''} · ${item['action'] ?? ''}',
                                ),
                                subtitle: Text(
                                  '${item['candidate_emails'] ?? 0} candidat(s), ${item['juror_emails'] ?? 0} juré(s)\n${item['statuses'] ?? {}}',
                                ),
                              ),
                          ],
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(inner),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            );
          } catch (e) {
            if (dialog.mounted) update(() => error = explain(e));
          } finally {
            if (dialog.mounted) update(() => loading = false);
          }
        }

        return AlertDialog(
          title: const Text('Communiquer les entretiens'),
          content: SizedBox(
            width: 660,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Prépare les messages, vérifie les destinataires et '
                    'confirme leur envoi depuis EnactSpace.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: action,
                    decoration: const InputDecoration(
                      labelText: 'Type de communication',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'publish',
                        child: Text('Publier les créneaux préparés'),
                      ),
                      DropdownMenuItem(
                        value: 'venue',
                        child: Text('Indiquer ou changer la salle'),
                      ),
                      DropdownMenuItem(
                        value: 'reminder',
                        child: Text('Rappeler les rendez-vous'),
                      ),
                    ],
                    onChanged: loading
                        ? null
                        : (value) {
                            if (value == null) return;
                            update(() => action = value);
                            invalidate();
                          },
                  ),
                  const SizedBox(height: 8),
                  if (applicationId != null && !candidateOnly)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: dayMode,
                      title: Text(
                        dayMode
                            ? 'Toute une journée'
                            : candidateName ?? 'Ce candidat seulement',
                      ),
                      onChanged: loading
                          ? null
                          : (value) {
                              update(() => dayMode = value);
                              invalidate();
                            },
                    ),
                  if (dayMode) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined),
                      label: Text('Journée : ${dayText(day)}'),
                      onPressed: loading
                          ? null
                          : () async {
                              final next = await showDatePicker(
                                context: dialog,
                                initialDate: day,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (next != null) {
                                update(() => day = next);
                                invalidate();
                              }
                            },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fromTime,
                            decoration: const InputDecoration(
                              labelText: 'Début HH:MM',
                            ),
                            onChanged: (_) => invalidate(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: untilTime,
                            decoration: const InputDecoration(
                              labelText: 'Fin HH:MM',
                            ),
                            onChanged: (_) => invalidate(),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (action != 'reminder') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: location,
                      enabled: !loading,
                      maxLength: 180,
                      decoration: InputDecoration(
                        labelText: action == 'venue'
                            ? 'Nouvelle salle'
                            : 'Lieu (facultatif)',
                        hintText: 'Salle CRENT, à côté du Grand Amphi',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => invalidate(),
                    ),
                  ],
                  if (action == 'publish') ...[
                    TextField(
                      controller: reason,
                      enabled: !loading,
                      decoration: const InputDecoration(
                        labelText: 'Motif d’exception de jury, si nécessaire',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => invalidate(),
                    ),
                    CheckboxListTile(
                      key: const Key('confirm-unrecorded-jury-availability-publication'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Je confirme la disponibilité des jurés sans calendrier renseigné',
                      ),
                      subtitle: const Text(
                        'Une indisponibilité déjà enregistrée reste bloquante.',
                      ),
                      value: confirmUnrecordedAvailability,
                      onChanged: loading
                          ? null
                          : (value) {
                              update(() =>
                                  confirmUnrecordedAvailability = value ?? false);
                              invalidate();
                            },
                    ),
                  ],
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Informer les candidats'),
                    value: toCandidates,
                    onChanged: loading
                        ? null
                        : (value) {
                            update(() => toCandidates = value ?? false);
                            invalidate();
                          },
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Informer les jurés concernés'),
                    value: toJurors,
                    onChanged: loading
                        ? null
                        : (value) {
                            update(() => toJurors = value ?? false);
                            invalidate();
                          },
                  ),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(dialog).colorScheme.error,
                      ),
                    ),
                  ],
                  if (preview != null) ...[
                    const Divider(height: 24),
                    Text(
                      '${preview!['candidates'] ?? 0} entretien(s) · ${preview!['candidate_emails'] ?? 0} message(s) aux candidats · ${preview!['juror_emails'] ?? 0} aux jurés',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Clique sur un destinataire pour lire son message.',
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final item
                              in (preview!['messages'] as List? ?? const []))
                            if (item is Map)
                              ExpansionTile(
                                title: Text((item['name'] ?? '').toString()),
                                subtitle: Text(
                                  (item['kind'] == 'juror'
                                          ? 'Juré · '
                                          : 'Candidat · ') +
                                      (item['email'] ?? '').toString(),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: SelectableText(
                                      '${item['subject'] ?? ''}\n\n${item['body'] ?? ''}',
                                    ),
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),
                    const Text(
                      'Les modifications et les envois seront validés ensemble. '
                      'Un e-mail déjà envoyé ne peut pas être rappelé.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.history),
              onPressed: loading ? null : history,
              label: const Text('Historique'),
            ),
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialog, false),
              child: const Text('Annuler'),
            ),
            if (loading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (preview == null)
              FilledButton.icon(
                onPressed: inspect,
                icon: const Icon(Icons.preview_outlined),
                label: const Text('Prévisualiser'),
              )
            else
              FilledButton.icon(
                onPressed: confirm,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Confirmer et envoyer'),
              ),
          ],
        );
      },
    ),
  );
  location.dispose();
  reason.dispose();
  fromTime.dispose();
  untilTime.dispose();
  return accepted == true;
}
