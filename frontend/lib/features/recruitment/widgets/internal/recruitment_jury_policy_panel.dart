import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';

/// Settings belong to the selected campaign. Editing never contacts candidates.
class RecruitmentJuryPolicyPanel extends StatefulWidget {
  const RecruitmentJuryPolicyPanel({
    super.key,
    required this.campaignId,
    required this.members,
  });
  final String campaignId;
  final List<Map<String, dynamic>> members;
  @override
  State<RecruitmentJuryPolicyPanel> createState() =>
      _RecruitmentJuryPolicyPanelState();
}

class _RecruitmentJuryPolicyPanelState
    extends State<RecruitmentJuryPolicyPanel> {
  final _api = ApiClient();
  final _auth = AuthService();
  Map<String, dynamic>? _policy;
  List<Map<String, dynamic>> _availability = [];
  String? _error;
  bool _loading = true;
  bool _showAll = false;
  String get _base => '/recruitment/campaigns/${widget.campaignId}';
  Future<String> _token() async {
    final token = await _auth.getToken();
    if (token == null) throw StateError('Connexion nécessaire');
    return token;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RecruitmentJuryPolicyPanel old) {
    super.didUpdateWidget(old);
    if (old.campaignId != widget.campaignId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _token();
      final results = await Future.wait([
        _api.get('$_base/interviews/policy', token: token),
        _api.get('$_base/jury/availability', token: token),
      ]);
      if (!mounted) return;
      setState(() {
        _policy = Map<String, dynamic>.from(results[0] as Map);
        _availability = (results[1] as List)
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Les paramètres sont temporairement indisponibles.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePolicy() async {
    final policy = _policy;
    if (policy == null) return;
    final duration = TextEditingController(
      text: policy['duration_minutes'].toString(),
    );
    final venue = TextEditingController(
      text: policy['default_location']?.toString() ?? '',
    );
    final allControllers = <TextEditingController>[duration, venue];
    final windows = <List<TextEditingController>>[];
    void addWindow(String start, String end) {
      final begin = TextEditingController(text: start);
      final finish = TextEditingController(text: end);
      allControllers.addAll([begin, finish]);
      windows.add([begin, finish]);
    }

    for (final row in (policy['daily_windows'] as List).whereType<Map>()) {
      addWindow(row['start']?.toString() ?? '', row['end']?.toString() ?? '');
    }
    if (windows.isEmpty) addWindow('09:00', '12:00');
    var mode = policy['default_mode']?.toString() ?? 'in_person';
    var editing = false;
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Règles de la campagne'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durée (minutes)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Plages horaires',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final pair in windows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: pair[0],
                                decoration: const InputDecoration(
                                  labelText: 'Début · HH:MM',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: pair[1],
                                decoration: const InputDecoration(
                                  labelText: 'Fin · HH:MM',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Retirer cette plage',
                              onPressed: editing || windows.length <= 1
                                  ? null
                                  : () => update(() => windows.remove(pair)),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: editing || windows.length >= 8
                            ? null
                            : () => update(() => addWindow('09:00', '12:00')),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une plage'),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration: const InputDecoration(
                        labelText: 'Format par défaut',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'in_person',
                          child: Text('Présentiel'),
                        ),
                        DropdownMenuItem(
                          value: 'online',
                          child: Text('En ligne'),
                        ),
                        DropdownMenuItem(value: 'hybrid', child: Text('Mixte')),
                      ],
                      onChanged: (v) => update(() => mode = v ?? mode),
                    ),
                    TextField(
                      controller: venue,
                      decoration: const InputDecoration(
                        labelText: 'Lieu (facultatif)',
                      ),
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
                onPressed: editing ? null : () => Navigator.pop(dialog),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: editing
                    ? null
                    : () async {
                        update(() {
                          editing = true;
                          error = null;
                        });
                        try {
                          final configuredWindows = [
                            for (final pair in windows)
                              {
                                'start': pair[0].text.trim(),
                                'end': pair[1].text.trim(),
                              },
                          ];
                          await _api.putJson(
                            '$_base/interviews/policy',
                            token: await _token(),
                            data: {
                              'duration_minutes': int.parse(
                                duration.text.trim(),
                              ),
                              'daily_windows': configuredWindows,
                              'default_mode': mode,
                              'default_location': venue.text.trim().isEmpty
                                  ? null
                                  : venue.text.trim(),
                              'respect_candidate_availability': false,
                            },
                          );
                          if (dialog.mounted) Navigator.pop(dialog);
                          await _load();
                        } catch (_) {
                          update(() {
                            editing = false;
                            error = 'Vérifie la durée et les horaires.';
                          });
                        }
                      },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      );
    } finally {
      for (final controller in allControllers) {
        controller.dispose();
      }
    }
  }

  Future<void> _editAvailability(Map<String, dynamic> person) async {
    final previous = _availability
        .where((a) => a['user_id'].toString() == person['user_id'].toString())
        .firstOrNull;
    final days = <int>{};
    final rows = (previous?['windows'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    for (final row in rows) {
      if (row['weekday'] is int) days.add(row['weekday'] as int);
    }
    final start = TextEditingController(
      text: rows.isEmpty ? '19:00' : rows.first['start'].toString(),
    );
    final end = TextEditingController(
      text: rows.isEmpty ? '21:00' : rows.first['end'].toString(),
    );
    const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    try {
      await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text('Disponibilités · ${person['name']}'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var i = 0; i < 7; i++)
                        FilterChip(
                          label: Text(labels[i]),
                          selected: days.contains(i),
                          onSelected: (yes) =>
                              update(() => yes ? days.add(i) : days.remove(i)),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: start,
                          decoration: const InputDecoration(
                            labelText: 'Début (HH:MM)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: end,
                          decoration: const InputDecoration(
                            labelText: 'Fin (HH:MM)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await _api.putJson(
                      '$_base/jury/availability/${person['user_id']}',
                      token: await _token(),
                      data: {
                        'windows': [
                          for (final day in days.toList()..sort())
                            {
                              'weekday': day,
                              'start': start.text.trim(),
                              'end': end.text.trim(),
                            },
                        ],
                      },
                    );
                    if (dialog.mounted) Navigator.pop(dialog);
                    await _load();
                  } catch (_) {
                    if (dialog.mounted) {
                      ScaffoldMessenger.of(dialog).showSnackBar(
                        const SnackBar(
                          content: Text('Vérifie les disponibilités.'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      );
    } finally {
      start.dispose();
      end.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final people =
        <String, Map<String, dynamic>>{
          for (final row in widget.members)
            if (row['user_id'] != null) row['user_id'].toString(): row,
          for (final row in _availability) row['user_id'].toString(): row,
        }.values.toList()..sort(
          (a, b) => a['name'].toString().toLowerCase().compareTo(
            b['name'].toString().toLowerCase(),
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Règles des entretiens',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null)
              Text(_error!)
            else if (_policy != null) ...[
              Text(
                '${_policy!['duration_minutes']} minutes · '
                '${_policy!['default_mode'] == 'in_person' ? 'Présentiel' : 'Format adaptable'}',
              ),
              Text(
                (_policy!['daily_windows'] as List)
                    .whereType<Map>()
                    .map((w) => '${w['start']}–${w['end']}')
                    .join(' · '),
              ),
              TextButton.icon(
                onPressed: _changePolicy,
                icon: const Icon(Icons.tune),
                label: const Text('Modifier les règles'),
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Disponibilités',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(_showAll ? 'Réduire' : 'Tout afficher'),
                ),
              ],
            ),
            for (final person in (_showAll ? people : people.take(5)))
              ListTile(
                dense: true,
                title: Text(person['name']?.toString() ?? 'Juré'),
                subtitle: Text(() {
                  final match = _availability
                      .where(
                        (a) =>
                            a['user_id'].toString() ==
                            person['user_id'].toString(),
                      )
                      .firstOrNull;
                  if (match == null) return 'Non renseignées';
                  const names = [
                    'lun',
                    'mar',
                    'mer',
                    'jeu',
                    'ven',
                    'sam',
                    'dim',
                  ];
                  return (match['windows'] as List? ?? const [])
                      .whereType<Map>()
                      .map(
                        (w) => w['weekday'] is int
                            ? '${names[w['weekday'] as int]} ${w['start']}–${w['end']}'
                            : '${w['date']} ${w['start']}–${w['end']}',
                      )
                      .join(' · ');
                }()),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_calendar_outlined),
                  tooltip: 'Modifier les disponibilités',
                  onPressed: () => _editAvailability(person),
                ),
              ),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
          ],
        ),
      ),
    );
  }
}
