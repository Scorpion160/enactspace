import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';

/// A proposal only: no public appointment update or e-mail can occur here.
Future<bool> showPrivateInterviewProposalDialog(
  BuildContext context, {
  required String campaignId,
  required String applicationId,
  required String candidateName,
  required String currentStart,
  required String currentMode,
  required String currentLocation,
  required List<String> currentJury,
}) async {
  final api = ApiClient();
  final token = await AuthService().getToken();
  if (token == null) return false;
  late final List<Map<String, dynamic>> members;
  try {
    final data = Map<String, dynamic>.from(
      await api.get(
        '/recruitment/campaigns/$campaignId/interviews/jury-options',
        token: token,
      ) as Map,
    );
    members = (data['members'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger les jurés.')),
      );
    }
    return false;
  }
  if (!context.mounted) return false;

  final beginning = DateTime.tryParse(currentStart) ?? DateTime.now();
  var chosenDate = DateTime(beginning.year, beginning.month, beginning.day);
  var chosenTime = TimeOfDay(hour: beginning.hour, minute: beginning.minute);
  var mode = {'in_person', 'hybrid', 'online'}.contains(currentMode)
      ? currentMode
      : 'in_person';
  final selected = Set<String>.from(currentJury);
  final reason = TextEditingController();
  final location = TextEditingController(text: currentLocation);
  var saving = false;
  String? error;
  String fmtDay(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}T${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
  try {
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text('Réorganiser · $candidateName'),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Préparation interne uniquement. Une nouvelle convocation '
                        'ne sera ni publiée ni envoyée aux candidats ou aux jurés.',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.event),
                            label: Text(fmtDay(chosenDate)),
                            onPressed: saving
                                ? null
                                : () async {
                                    final value = await showDatePicker(
                                      context: context,
                                      initialDate: chosenDate,
                                      firstDate: DateTime(chosenDate.year - 2, 1, 1),
                                      lastDate: DateTime(chosenDate.year + 10, 12, 31),
                                    );
                                    if (value != null && context.mounted) {
                                      update(() => chosenDate = value);
                                    }
                                  },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.schedule),
                            label: Text(chosenTime.format(context)),
                            onPressed: saving
                                ? null
                                : () async {
                                    final value = await showTimePicker(
                                      context: context,
                                      initialTime: chosenTime,
                                    );
                                    if (value != null && context.mounted) {
                                      update(() => chosenTime = value);
                                    }
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: mode,
                        decoration: const InputDecoration(
                          labelText: 'Format',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'in_person', child: Text('Présentiel'),
                          ),
                          DropdownMenuItem(
                            value: 'hybrid', child: Text('Mixte'),
                          ),
                          DropdownMenuItem(
                            value: 'online', child: Text('En ligne'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => update(() => mode = v ?? mode),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: location,
                        decoration: const InputDecoration(
                          labelText: 'Lieu / lien à confirmer',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Membres du jury',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        'Les exceptions de composition sont permises avec '
                        'justification, sans déroger aux disponibilités et '
                        'aux règles d’accès.',
                      ),
                      for (final member in members)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(member['name']?.toString() ?? ''),
                          subtitle: Text(member['department']?.toString() ?? ''),
                          value: selected.contains(member['id']?.toString()),
                          onChanged: saving
                              ? null
                              : (checked) => update(() {
                                    final id = member['id'].toString();
                                    if (checked == true) {
                                      selected.add(id);
                                    } else {
                                      selected.remove(id);
                                    }
                                  }),
                        ),
                      TextField(
                        controller: reason,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Motif du changement (obligatoire)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialog, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: saving || selected.isEmpty
                      ? null
                      : () async {
                          final start = DateTime(
                            chosenDate.year, chosenDate.month, chosenDate.day,
                            chosenTime.hour, chosenTime.minute,
                          );
                          final end = start.add(const Duration(minutes: 20));
                          if (reason.text.trim().length < 3) {
                            update(() => error = 'Indiquez le motif de la modification.');
                            return;
                          }
                          update(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await api.putJson(
                              '/recruitment/applications/$applicationId/interview/private-proposal',
                              token: token,
                              data: {
                                'starts_at': iso(start),
                                'ends_at': iso(end),
                                'mode': mode,
                                'location': location.text.trim().isEmpty
                                    ? null
                                    : location.text.trim(),
                                'jury_member_ids': selected.toList(),
                                'reason': reason.text.trim(),
                              },
                            );
                            if (dialog.mounted) Navigator.pop(dialog, true);
                          } catch (_) {
                            if (dialog.mounted) {
                              update(() {
                                saving = false;
                                error = 'Vérifiez les horaires, les disponibilités '
                                    'et les éventuels conflits de jury.';
                              });
                            }
                          }
                        },
                  child: const Text('Enregistrer la proposition'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  } finally {
    reason.dispose();
    location.dispose();
  }
}
