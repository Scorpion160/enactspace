import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';

/// A proposal only: no public appointment update or e-mail can occur here.
Future<DateTime?> showPrivateInterviewProposalDialog(
  BuildContext context, {
  required String campaignId,
  required String applicationId,
  required String candidateName,
  required String currentStart,
  required String currentMode,
  required String currentLocation,
  required List<String> currentJury,
  String? officialStart,
}) async {
  final api = ApiClient();
  final token = await AuthService().getToken();
  if (token == null) return null;
  late final List<Map<String, dynamic>> members;
  late final int durationMinutes;
  try {
    final data = Map<String, dynamic>.from(
      await api.get(
        '/recruitment/campaigns/$campaignId/interviews/jury-options',
        token: token,
      ) as Map,
    );
    final policy = Map<String, dynamic>.from(
      await api.get(
        '/recruitment/campaigns/$campaignId/interviews/policy',
        token: token,
      ) as Map,
    );
    durationMinutes = (policy['duration_minutes'] as num?)?.toInt() ?? 20;
    if (durationMinutes < 5 || durationMinutes > 180) {
      throw StateError('La durée de la campagne est invalide.');
    }
    members = (data['members'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger les jurés ou les règles de la campagne.')),
      );
    }
    return null;
  }
  if (!context.mounted) return null;

  final beginning = DateTime.tryParse(currentStart) ?? DateTime.now();
  var chosenDate = DateTime(beginning.year, beginning.month, beginning.day);
  var chosenTime = TimeOfDay(hour: beginning.hour, minute: beginning.minute);
  var mode = {'in_person', 'hybrid', 'online'}.contains(currentMode)
      ? currentMode
      : 'in_person';
  final selected = Set<String>.from(currentJury);
  // Existing assignments must be visible first, even in a long jury roster.
  members.sort((left, right) {
    final a = selected.contains(left['id']?.toString());
    final b = selected.contains(right['id']?.toString());
    if (a != b) return a ? -1 : 1;
    return (left['name']?.toString() ?? '').toLowerCase().compareTo(
      (right['name']?.toString() ?? '').toLowerCase(),
    );
  });
  final juryScroll = ScrollController();
  var juryFilter = '';
  final reason = TextEditingController();
  final location = TextEditingController(text: currentLocation);
  var saving = false;
  var confirmUnrecordedAvailability = false;
  String? error;
  String fmtDay(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}T${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
  try {
    return await showDialog<DateTime>(
          context: context,
          builder: (dialog) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text('Modifier le créneau · $candidateName'),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        officialStart == null
                            ? 'Cette modification reste interne. Aucun message '
                                'ne sera envoyé aux candidats ni aux jurés.'
                            : 'Une convocation a déjà été publiée pour cet '
                                'entretien. Les changements saisis ici restent '
                                'internes tant qu’une nouvelle convocation '
                                'n’est pas validée.',
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
                            label: Text(
                              '${chosenTime.hour.toString().padLeft(2, '0')} h '
                              '${chosenTime.minute.toString().padLeft(2, '0')}',
                            ),
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
                      Text('Durée prévue : $durationMinutes minutes.'),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: mode,
                        decoration: const InputDecoration(
                          labelText: 'Format',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'in_person',
                            child: Text('Candidat et jury sur place'),
                          ),
                          DropdownMenuItem(
                            value: 'hybrid',
                            child: Text('Candidat sur place, juré à distance'),
                          ),
                          DropdownMenuItem(
                            value: 'online',
                            child: Text('Candidat à distance (exception)'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => update(() => mode = v ?? mode),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mode == 'online'
                            ? 'Exception : le candidat ne peut pas se déplacer. '
                                'Précisez la contrainte dans le motif et confirmez '
                                'le lien avant tout envoi.'
                            : mode == 'hybrid'
                                ? 'Le candidat se présente à l’ESP ; seul un ou '
                                    'plusieurs jurés participent à distance.'
                                : 'Le candidat et les jurés sont présents à l’ESP.',
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
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Membres du jury',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('${selected.length} sélectionné(s)'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (selected.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final member in members.where(
                              (m) => selected.contains(m['id']?.toString()),
                            ))
                              InputChip(
                                label: Text(member['name']?.toString() ?? ''),
                                onDeleted: saving
                                    ? null
                                    : () => update(
                                        () => selected.remove(member['id'].toString()),
                                      ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        enabled: !saving,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Rechercher un juré ou un département',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => update(() => juryFilter = value),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 210,
                        child: Scrollbar(
                          controller: juryScroll,
                          thumbVisibility: true,
                          child: ListView(
                            controller: juryScroll,
                            children: [
                              for (final member in members.where((m) {
                                final query = juryFilter.trim().toLowerCase();
                                final label =
                                    '${m['name'] ?? ''} ${m['department'] ?? ''}'
                                        .toLowerCase();
                                return query.isEmpty || label.contains(query);
                              }))
                                CheckboxListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  title: Text(member['name']?.toString() ?? ''),
                                  subtitle: Text(
                                    member['department']?.toString() ?? '',
                                  ),
                                  value: selected.contains(
                                    member['id']?.toString(),
                                  ),
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
                              if (!members.any((m) {
                                final query = juryFilter.trim().toLowerCase();
                                return ('${m['name'] ?? ''} ${m['department'] ?? ''}')
                                    .toLowerCase()
                                    .contains(query);
                              }))
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('Aucun juré ne correspond à la recherche.'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      CheckboxListTile(
                        key: const Key('confirm-unrecorded-jury-availability'),
                        contentPadding: EdgeInsets.zero,
                        value: confirmUnrecordedAvailability,
                        onChanged: saving
                            ? null
                            : (value) => update(
                                () => confirmUnrecordedAvailability = value ?? false,
                              ),
                        title: const Text(
                          'Je confirme la disponibilité des jurés sans calendrier renseigné',
                        ),
                        subtitle: const Text(
                          'Cette confirmation ne remplace pas une indisponibilité déjà déclarée.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reason,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Motif de la modification',
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
                  onPressed: saving ? null : () => Navigator.pop(dialog),
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
                          final end = start.add(Duration(minutes: durationMinutes));
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
                                'confirm_unrecorded_jury_availability':
                                    confirmUnrecordedAvailability,
                              },
                            );
                            if (dialog.mounted) Navigator.pop(dialog, start);
                          } on ApiException catch (failure) {
                            if (dialog.mounted) {
                              update(() {
                                saving = false;
                                error = failure.message;
                              });
                            }
                          } catch (_) {
                            if (dialog.mounted) {
                              update(() {
                                saving = false;
                                error = 'Enregistrement impossible. Vérifiez '
                                    'votre connexion et réessayez.';
                              });
                            }
                          }
                        },
                  child: const Text('Enregistrer et préparer la convocation'),
                ),
              ],
            ),
          ),
        );
  } finally {
    reason.dispose();
    location.dispose();
    juryScroll.dispose();
  }
}
