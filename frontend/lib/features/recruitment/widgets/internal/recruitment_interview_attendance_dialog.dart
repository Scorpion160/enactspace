import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';

/// Records an actual outcome without rewriting a candidate's public convocation.
Future<bool> showInterviewAttendanceDialog(
  BuildContext context, {
  required String campaignId,
  required String applicationId,
  required String candidateName,
}) async {
  final api = ApiClient();
  final token = await AuthService().getToken();
  if (token == null) return false;
  final base = '/recruitment/applications/$applicationId/interview';
  late final Map<String, dynamic> record;
  late final List<Map<String, dynamic>> jury;
  try {
    final result = await Future.wait([
      api.get('$base/collective', token: token),
      api.get(
        '/recruitment/campaigns/$campaignId/interviews/jury-options',
        token: token,
      ),
    ]);
    record = Map<String, dynamic>.from(result[0] as Map);
    jury = (Map<String, dynamic>.from(result[1] as Map)['members']
                as List? ??
            const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger les informations du jury.')),
      );
    }
    return false;
  }
  final initialJury =
      (record['actual_jury_member_ids'] as List? ?? const [])
          .map((x) => x.toString())
          .toSet();
  final selected = Set<String>.from(initialJury);
  final canManage = record['can_manage_jury'] == true;
  var status = record['status']?.toString() ?? 'scheduled';
  final reason = TextEditingController();
  final actualDay = TextEditingController();
  var saving = false;
  String? error;
  const labels = <String, String>{
    'scheduled': 'À réaliser',
    'completed': 'Entretien réalisé',
    'postponed': 'Report à organiser',
    'no_show': 'Candidat absent',
  };
  try {
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text('Suivi de l’entretien · $candidateName'),
              content: SizedBox(
                width: 610,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: labels.containsKey(status)
                            ? status
                            : 'scheduled',
                        decoration: const InputDecoration(
                          labelText: 'Situation réelle',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final entry in labels.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => update(() => status = value ?? status),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: actualDay,
                        decoration: const InputDecoration(
                          labelText: 'Date réelle, si connue (AAAA-MM-JJ)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: reason,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Motif du report ou du remplacement',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (canManage) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Composition réellement présente',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          'En cas de remplacement, sélectionner les personnes '
                          'présentes puis indiquer une justification. '
                          'Une exception de département peut être consignée.',
                        ),
                        for (final member in jury)
                          CheckboxListTile(
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: selected.contains(member['id'].toString()),
                            title: Text(member['name']?.toString() ?? ''),
                            subtitle: Text(member['department']?.toString() ?? ''),
                            onChanged: saving
                                ? null
                                : (checked) => update(() {
                                    if (checked == true) {
                                      selected.add(member['id'].toString());
                                    } else {
                                      selected.remove(member['id'].toString());
                                    }
                                  }),
                          ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Ce suivi reste interne. Il ne change pas la date '
                        'publiée au candidat et n’envoie aucun e-mail.',
                      ),
                      if (error != null)
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialog, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: saving || selected.isEmpty
                      ? null
                      : () async {
                          update(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await api.putJson(
                              '$base/attendance',
                              token: token,
                              data: {
                                'status': status,
                                'actual_day': actualDay.text.trim().isEmpty
                                    ? null
                                    : actualDay.text.trim(),
                                'actual_jury_member_ids': selected.toList(),
                                'reason': reason.text.trim(),
                              },
                            );
                            if (dialog.mounted) Navigator.pop(dialog, true);
                          } catch (_) {
                            update(() {
                              saving = false;
                              error = 'Vérifie la date, le motif et la composition.';
                            });
                          }
                        },
                  child: const Text('Enregistrer le suivi'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  } finally {
    reason.dispose();
    actualDay.dispose();
  }
}
