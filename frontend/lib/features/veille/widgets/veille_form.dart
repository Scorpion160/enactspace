import 'package:flutter/material.dart';

import '../services/veille_gateway.dart';
import 'veille_ui.dart';

Future<bool> showVeilleForm(
  BuildContext context, {
  required String kind,
  required VeilleGateway gateway,
  required VeilleJson data,
  VeilleJson? initial,
  String? action,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VeilleForm(
        kind: kind,
        gateway: gateway,
        data: data,
        initial: initial ?? {},
        action: action,
      ),
    ) ??
    false;

class VeilleForm extends StatefulWidget {
  final String kind;
  final VeilleGateway gateway;
  final VeilleJson data;
  final VeilleJson initial;
  final String? action;
  const VeilleForm({
    super.key,
    required this.kind,
    required this.gateway,
    required this.data,
    required this.initial,
    this.action,
  });
  @override
  State<VeilleForm> createState() => _VeilleFormState();
}

class _VeilleFormState extends State<VeilleForm> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  late VeilleJson _context;
  String? _owner, _pole, _project, _season, _bureau, _rule, _task, _plan;
  late DateTime _date, _start, _end;
  String _status = 'active',
      _cause = 'dependance',
      _reportKind = 'weekly',
      _verdict = 'accepted',
      _outcome = 'accompagnement',
      _priority = 'normale';
  final Set<String> _courses = {},
      _allowed = {'accompagnement', 'clarification'};
  bool _busy = false,
      _proofRequired = true,
      _reminders = true,
      _autoReports = true;
  int? _quality;
  String? _error;
  bool get _planRestricted =>
      _kind == 'plan' && _editing && _context['can_coordinate'] != true;
  bool get _editing => widget.initial['id'] != null;
  String get _kind => widget.kind;
  String get _uid => _context['user_id'].toString();
  bool get _proposal => {'propose', 'propose_review'}.contains(widget.action);
  bool get _decision => {'decide', 'review_decide'}.contains(widget.action);
  VeilleJson get _initial => widget.initial;

  @override
  void initState() {
    super.initState();
    _context = Map<String, dynamic>.from(widget.data['context'] as Map);
    DateTime parsed(dynamic value, DateTime fallback) =>
        DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? fallback;
    final now = DateTime.now();
    _date = parsed(
      _initial['due_date'] ??
          _initial['review_at'] ??
          _initial['effective_from'] ??
          _initial['observed_at'],
      now.add(const Duration(days: 7)),
    );
    _start = parsed(
      _initial['period_start'] ?? _initial['start_date'],
      DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1)),
    );
    _end = parsed(_initial['period_end'] ?? _initial['end_date'], now);
    if (_kind == 'case' || _kind == 'rule') {
      _date = parsed(
        _initial['observed_at'] ?? _initial['effective_from'],
        now,
      );
    }
    if (_kind == 'blocker' && !_editing) {
      _date = now.add(const Duration(days: 1));
    }
    _owner = (_initial['owner_id'] ?? _initial['member_id'] ?? _uid).toString();
    _pole = _initial['pole_id']?.toString();
    _project = _initial['project_id']?.toString();
    _season = _initial['season_id']?.toString();
    _bureau = _initial['bureau_reviewer_id']?.toString();
    _rule = _initial['rule_id']?.toString();
    _task = _initial['task_id']?.toString();
    _plan = _initial['plan_id']?.toString();
    _status = _initial['status']?.toString() ?? 'active';
    _outcome = _initial['proposed_action']?.toString() ?? 'accompagnement';
    _courses.addAll(
      (_initial['course_ids'] as List? ?? []).map((v) => v.toString()),
    );
    for (final key in [
      'title',
      'expected_result',
      'availability',
      'description',
      'requested_help',
      'next_action',
      'resolution',
      'observations',
      'next_actions',
      'reason',
      'facts',
      'content',
      'feedback',
      'message',
      'amount',
      'maximum_amount',
      'quiet_start_hour',
      'quiet_end_hour',
      'escalation_days',
      'response_days',
      'appeal_days',
      'weekly_day',
      'report_hour',
    ]) {
      _fields[key] = TextEditingController(
        text: _initial[key]?.toString() ?? '',
      );
    }
    _fields['amount']!.text = (_initial['amount'] as num? ?? 0)
        .toInt()
        .toString();
    _fields['maximum_amount']!.text = (_initial['maximum_amount'] as num? ?? 0)
        .toInt()
        .toString();
    if (widget.action == 'accept') {
      _fields['message']!.text =
          'Je confirme accepter la décision communiquée.';
    }
    if (widget.action == 'close') {
      _fields['message']!.text =
          'Le suivi est terminé et le dossier peut être clôturé.';
    }
    if (_kind == 'settings') {
      for (final key in [
        'quiet_start_hour',
        'quiet_end_hour',
        'escalation_days',
        'response_days',
        'appeal_days',
        'weekly_day',
        'report_hour',
      ]) {
        _fields[key]!.text = _initial[key].toString();
      }
      _reminders = _initial['reminders_enabled'] == true;
      _autoReports = _initial['auto_reports'] == true;
    }
    if (_kind == 'case' && _owner == _uid) {
      _owner = _members
          .where((m) => m['id'] != _uid)
          .firstOrNull?['id']
          ?.toString();
    }
    if (_kind == 'blocker' && _task == null) {
      _task = _tasks.firstOrNull?['id']?.toString();
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<VeilleJson> get _members => veilleRows(_context['members'])
      .where(
        (m) =>
            (_pole == null || (m['pole_ids'] as List? ?? []).contains(_pole)) &&
            (_project == null ||
                (m['project_ids'] as List? ?? []).contains(_project)),
      )
      .toList();
  List<VeilleJson> get _tasks =>
      veilleRows((widget.data['summary'] as Map?)?['tasks']);
  List<VeilleJson> get _plans =>
      veilleRows((widget.data['records'] as Map?)?['plans'])
          .where(
            (p) =>
                p['status'] == 'active' &&
                p['owner_id'] == _owner &&
                p['pole_id'] == _pole &&
                p['project_id'] == _project &&
                p['season_id'] == _season,
          )
          .toList();

  Widget _text(
    String key,
    String label, {
    String? help,
    bool required = true,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _fields[key],
      enabled:
          !_busy &&
          !(_planRestricted && {'title', 'expected_result'}.contains(key)),
      minLines: lines,
      maxLines: lines == 1 ? 1 : 8,
      decoration: InputDecoration(
        labelText: label,
        helperText: help,
        helperMaxLines: 5,
        alignLabelWithHint: lines > 1,
      ),
      validator: required
          ? (v) => (v?.trim().length ?? 0) < (key == 'title' ? 3 : 6)
                ? 'Précisez ce point avec une phrase complète.'
                : null
          : null,
    ),
  );

  Widget _number(
    String key,
    String label, {
    int minimum = 0,
    int maximum = 10000000,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_busy && !(key == 'amount' && _decision),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final n = int.tryParse(v ?? '');
        return n == null || n < minimum || n > maximum
            ? 'Choisissez une valeur entre $minimum et $maximum.'
            : null;
      },
    ),
  );

  Widget _choice(
    String label,
    String? value,
    List<VeilleJson> items,
    ValueChanged<String?> changed, {
    bool optional = false,
    String emptyLabel = 'Aucun',
    bool enabled = true,
  }) {
    final ids = items.map((e) => e['id'].toString()).toSet();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label:$value:${ids.join()}'),
        initialValue: value != null && ids.contains(value)
            ? value
            : optional
            ? ''
            : null,
        isExpanded: true,
        itemHeight: null,
        decoration: InputDecoration(labelText: label),
        items: [
          if (optional) DropdownMenuItem(value: '', child: Text(emptyLabel)),
          for (final item in items)
            DropdownMenuItem(
              value: item['id'].toString(),
              child: Text(
                (item['name'] ?? item['title']).toString(),
                softWrap: true,
              ),
            ),
        ],
        onChanged:
            _busy ||
                !enabled ||
                (_planRestricted &&
                    {'Pôle', 'Projet', 'Année', 'Responsable'}.contains(label))
            ? null
            : (v) => changed(v == '' ? null : v),
        validator: optional
            ? null
            : (v) => v == null || v.isEmpty
                  ? 'Choisissez une personne ou un élément.'
                  : null,
      ),
    );
  }

  Widget _enum(
    String label,
    String value,
    Iterable<String> values,
    ValueChanged<String> changed, {
    bool enabled = true,
  }) => _choice(
    label,
    value,
    [
      for (final v in values) {'id': v, 'name': veilleLabel(v)},
    ],
    (v) {
      if (v != null) changed(v);
    },
    enabled: enabled,
  );

  Future<void> _pick(String target, {bool withTime = false}) async {
    final current = target == 'date'
        ? _date
        : target == 'start'
        ? _start
        : _end;
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    TimeOfDay? clock;
    if (withTime) {
      clock = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (clock == null || !mounted) return;
    }
    final value = DateTime(
      day.year,
      day.month,
      day.day,
      clock?.hour ?? 0,
      clock?.minute ?? 0,
    );
    setState(() {
      if (target == 'date') {
        _date = value;
      } else if (target == 'start') {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Widget _dateButton(
    String label,
    String target,
    DateTime value, {
    bool withTime = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: OutlinedButton.icon(
      onPressed: _busy || _planRestricted
          ? null
          : () => _pick(target, withTime: withTime),
      icon: const Icon(Icons.event_rounded),
      label: Text(
        '$label : ${veilleDate(value, withTime: withTime)}',
        softWrap: true,
      ),
    ),
  );

  bool get _mustManageScope =>
      {'action', 'report'}.contains(_kind) ||
      (_kind == 'plan' && _owner != _uid);
  List<VeilleJson> _scopeOptions(String kind) {
    final all = veilleRows(_context[kind]);
    if (!_mustManageScope || _context['global_scope'] == true) return all;
    final ids =
        _context[kind == 'poles' ? 'managed_pole_ids' : 'managed_project_ids']
            as List? ??
        [];
    return all.where((v) => ids.contains(v['id'])).toList();
  }

  List<Widget> _scope() => [
    _choice(
      'Pôle',
      _pole,
      _scopeOptions('poles'),
      (v) => setState(() {
        _pole = v;
        _project = null;
        _plan = null;
        if (!_members.any((m) => m['id'] == _owner)) _owner = null;
      }),
      optional: true,
      emptyLabel: 'Sans pôle',
    ),
    _choice(
      'Projet',
      _project,
      _scopeOptions('projects'),
      (v) => setState(() {
        _project = v;
        _pole = null;
        _plan = null;
        if (!_members.any((m) => m['id'] == _owner)) _owner = null;
      }),
      optional: true,
      emptyLabel: 'Sans projet',
    ),
    _choice(
      'Année',
      _season,
      veilleRows(_context['seasons']),
      (v) => setState(() => _season = v),
      optional: true,
      emptyLabel: 'Sans année',
    ),
  ];

  String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final texts = {
        for (final e in _fields.entries) e.key: e.value.text.trim(),
      };
      final scope = {
        'pole_id': _pole,
        'project_id': _project,
        'season_id': _season,
      };
      VeilleJson payload;
      String path;
      String method = 'POST';
      switch (_kind) {
        case 'plan':
          payload = {
            ...scope,
            'owner_id': _owner,
            'title': texts['title'],
            'expected_result': texts['expected_result'],
            'availability': texts['availability'],
            'due_date': _date.toUtc().toIso8601String(),
            'course_ids': _courses.toList(),
          };
          path = '/plans';
          if (_editing) {
            path += '/${_initial['id']}';
            method = 'PATCH';
            payload.addAll({
              'version': _initial['version'],
              'reason': texts['reason'],
              'status': _status,
            });
          }
        case 'action':
          payload = {
            ...scope,
            'owner_id': _owner,
            'plan_id': _plan,
            'title': texts['title'],
            'description': texts['description'],
            'due_date': _date.toUtc().toIso8601String(),
            'priority': _priority,
            'proof_required': _proofRequired,
          };
          path = '/tasks';
        case 'blocker':
          if (_editing) {
            payload = {
              'version': _initial['version'],
              'owner_id': _owner,
              'next_action': texts['next_action'],
              'review_at': _date.toUtc().toIso8601String(),
              'status': _status,
              'resolution': _status == 'resolved' ? texts['resolution'] : null,
            };
            path = '/blockers/${_initial['id']}';
            method = 'PATCH';
          } else {
            payload = {
              'task_id': _task,
              'owner_id': _owner,
              'title': texts['title'],
              'cause': _cause,
              'description': texts['description'],
              'requested_help': texts['requested_help'],
              'next_action': texts['next_action'],
              'review_at': _date.toUtc().toIso8601String(),
            };
            path = '/blockers';
          }
        case 'review':
          payload = {
            'verdict': _verdict,
            'feedback': texts['feedback'],
            'quality': _quality,
            'expected_updated_at': _initial['updated_at'],
          };
          path = '/tasks/${_initial['id']}/reviews';
        case 'deadline':
          payload = {
            'due_date': _date.toUtc().toIso8601String(),
            'reason': texts['reason'],
            'expected_updated_at': _initial['updated_at'],
          };
          path = '/tasks/${_initial['id']}/deadline';
        case 'report':
          payload = {
            ...scope,
            'title': texts['title'],
            'kind': _reportKind,
            'period_start': _day(_start),
            'period_end': _day(_end),
            'observations': texts['observations'],
            'next_actions': texts['next_actions'],
          };
          path = '/reports';
        case 'leave':
          payload = {
            'member_id': _owner,
            'start_date': _day(_start),
            'end_date': _day(_end),
            'reason': texts['reason'],
          };
          path = '/leaves';
        case 'leave_action':
          payload = {
            'version': _initial['version'],
            'status': widget.action,
            'response': texts['message'],
          };
          path = '/leaves/${_initial['id']}';
          method = 'PATCH';
        case 'case':
          payload = {
            'member_id': _owner,
            'bureau_reviewer_id': _bureau,
            'task_id': _task,
            'rule_id': _rule,
            'title': texts['title'],
            'facts': texts['facts'],
            'observed_at': _day(_date),
            'attendance_id': _initial['attendance_id'],
          };
          path = '/cases';
        case 'case_action':
          payload = {
            'version': _initial['version'],
            'action': widget.action,
            'message': texts['message'],
            'outcome': _proposal || _decision ? _outcome : null,
            'amount':
                (_proposal || _decision) && _outcome == 'penalite_financiere'
                ? int.parse(texts['amount']!)
                : 0,
          };
          path = '/cases/${_initial['id']}/actions';
        case 'rule':
          payload = {
            'title': texts['title'],
            'content': texts['content'],
            'effective_from': _day(_date),
            'allowed_actions': _allowed.toList(),
            'maximum_amount': _allowed.contains('penalite_financiere')
                ? int.parse(texts['maximum_amount']!)
                : 0,
          };
          path = '/rules';
        case 'settings':
          payload = {
            'version': _initial['version'],
            'reminders_enabled': _reminders,
            'auto_reports': _autoReports,
            for (final k in [
              'quiet_start_hour',
              'quiet_end_hour',
              'escalation_days',
              'response_days',
              'appeal_days',
              'weekly_day',
              'report_hour',
            ])
              k: int.parse(texts[k]!),
          };
          path = '/settings';
          method = 'PUT';
        default:
          throw StateError('Formulaire inconnu.');
      }
      await widget.gateway.save(path, payload, method: method);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = {
      'plan': _editing ? 'Mettre à jour l’engagement' : 'Définir un engagement',
      'action': 'Confier une action',
      'blocker': _editing ? 'Faire avancer le blocage' : 'Partager un blocage',
      'review': 'Relire le livrable',
      'deadline': 'Convenir d’une nouvelle échéance',
      'report': 'Préparer un bilan',
      'leave': 'Signaler une indisponibilité',
      'case': 'Préparer un dossier de suivi',
      'rule': 'Renseigner une règle adoptée',
      'settings': 'Organiser les rappels et bilans',
      'case_action': veilleLabel(widget.action),
      'leave_action': veilleLabel(widget.action),
    };
    return AlertDialog(
      title: Text(titles[_kind] ?? 'Suivi Veille'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ({'plan', 'action', 'report'}.contains(_kind)) ..._scope(),
                if ({
                  'plan',
                  'action',
                  'blocker',
                  'leave',
                  'case',
                }.contains(_kind))
                  _choice(
                    _kind == 'case'
                        ? 'Membre concerné'
                        : _kind == 'leave'
                        ? 'Membre'
                        : 'Responsable',
                    _owner,
                    _members
                        .where((m) => _kind != 'case' || m['id'] != _uid)
                        .toList(),
                    (v) => setState(() {
                      _owner = v;
                      _plan = null;
                      if (_bureau == v) _bureau = null;
                      if (_mustManageScope &&
                          _context['global_scope'] != true) {
                        if (!_scopeOptions(
                          'poles',
                        ).any((p) => p['id'] == _pole)) {
                          _pole = null;
                        }
                        if (!_scopeOptions(
                          'projects',
                        ).any((p) => p['id'] == _project)) {
                          _project = null;
                        }
                      }
                      if (_kind == 'case') _task = null;
                    }),
                  ),
                if ({
                      'plan',
                      'action',
                      'report',
                      'case',
                      'rule',
                    }.contains(_kind) ||
                    (_kind == 'blocker' && !_editing))
                  _text('title', 'Titre'),
                if (_kind == 'plan') ...[
                  _text(
                    'expected_result',
                    'Quel résultat souhaitons-nous obtenir ?',
                    lines: 3,
                  ),
                  _text(
                    'availability',
                    'Quelle disponibilité avons-nous convenue ?',
                    lines: 2,
                  ),
                  _dateButton('Échéance', 'date', _date, withTime: true),
                  const Text(
                    'Formations utiles à cet engagement',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Les prérequis Academy restent applicables. Les formations choisies doivent être réussies pour terminer l’engagement.',
                  ),
                  for (final course in veilleRows(_context['courses']))
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(course['name'].toString()),
                      value: _courses.contains(course['id']),
                      onChanged: _busy || _planRestricted
                          ? null
                          : (v) => setState(() {
                              if (v == true) {
                                _courses.add(course['id'].toString());
                              } else {
                                _courses.remove(course['id']);
                              }
                            }),
                    ),
                  if (_editing) ...[
                    _enum('État de l’engagement', _status, [
                      'active',
                      'completed',
                      if (!_planRestricted) 'cancelled',
                    ], (v) => setState(() => _status = v)),
                    _text('reason', 'Pourquoi cette mise à jour ?', lines: 2),
                  ],
                ],
                if (_kind == 'action') ...[
                  _text(
                    'description',
                    'Résultat attendu et consignes',
                    lines: 3,
                  ),
                  _choice(
                    'Engagement lié',
                    _plan,
                    _plans,
                    (v) => setState(() => _plan = v),
                    optional: true,
                    emptyLabel: 'Action indépendante',
                  ),
                  _enum('Priorité', _priority, [
                    'basse',
                    'normale',
                    'haute',
                    'urgente',
                  ], (v) => setState(() => _priority = v)),
                  _dateButton('Échéance', 'date', _date, withTime: true),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _proofRequired,
                    title: const Text('Demander un justificatif à la remise'),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _proofRequired = v),
                  ),
                ],
                if (_kind == 'blocker') ...[
                  if (!_editing) ...[
                    _choice(
                      'Tâche concernée',
                      _task,
                      _tasks
                          .where(
                            (t) => !{
                              'termine',
                              'valide',
                              'annule',
                            }.contains(t['status']),
                          )
                          .map((t) => {'id': t['id'], 'name': t['title']})
                          .toList(),
                      (v) => setState(() => _task = v),
                    ),
                    _enum('Origine de la difficulté', _cause, [
                      'dependance',
                      'ressources',
                      'clarification',
                      'technique',
                      'disponibilite',
                      'autre',
                    ], (v) => setState(() => _cause = v)),
                    _text('description', 'Que se passe-t-il ?', lines: 3),
                    _text(
                      'requested_help',
                      'Quelle aide est nécessaire ?',
                      lines: 2,
                    ),
                  ],
                  _text(
                    'next_action',
                    'Quelle est la prochaine action ?',
                    lines: 2,
                  ),
                  _dateButton('Prochain point', 'date', _date, withTime: true),
                  if (_editing) ...[
                    _enum('État', _status == 'resolved' ? 'resolved' : 'open', [
                      'open',
                      'resolved',
                    ], (v) => setState(() => _status = v)),
                    if (_status == 'resolved')
                      _text(
                        'resolution',
                        'Comment avons-nous résolu la difficulté ?',
                        lines: 3,
                      ),
                  ],
                ],
                if (_kind == 'review') ...[
                  _choice('Retour sur le livrable', _verdict, [
                    {'id': 'accepted', 'name': 'Accepter le livrable'},
                    {'id': 'rework', 'name': 'Demander une reprise'},
                  ], (v) => setState(() => _verdict = v!)),
                  _text(
                    'feedback',
                    'Expliquer le retour et les prochaines étapes',
                    lines: 4,
                  ),
                  _choice(
                    'Appréciation de la qualité',
                    _quality?.toString(),
                    [
                      {'id': '1', 'name': '1 — Points essentiels à reprendre'},
                      {
                        'id': '2',
                        'name': '2 — Plusieurs précisions nécessaires',
                      },
                      {'id': '3', 'name': '3 — Attentes principales remplies'},
                      {
                        'id': '4',
                        'name': '4 — Travail solide et bien documenté',
                      },
                      {
                        'id': '5',
                        'name': '5 — Travail abouti et transmissible',
                      },
                    ],
                    (v) => setState(() => _quality = int.tryParse(v ?? '')),
                    optional: true,
                    emptyLabel: 'Sans appréciation chiffrée',
                  ),
                ],
                if (_kind == 'deadline') ...[
                  Text(
                    'Échéance actuelle : ${veilleDate(_initial['due_date'], withTime: true)}',
                  ),
                  const SizedBox(height: 12),
                  _dateButton(
                    'Nouvelle échéance',
                    'date',
                    _date,
                    withTime: true,
                  ),
                  _text(
                    'reason',
                    'Pourquoi ajuster cette échéance ?',
                    lines: 3,
                  ),
                ],
                if (_kind == 'report') ...[
                  _enum('Type de bilan', _reportKind, [
                    'weekly',
                    'monthly',
                    'handover',
                  ], (v) => setState(() => _reportKind = v)),
                  _dateButton('Début de la période', 'start', _start),
                  _dateButton('Fin de la période', 'end', _end),
                  _text(
                    'observations',
                    'Ce que nous retenons de cette période',
                    lines: 4,
                  ),
                  _text(
                    'next_actions',
                    'Décisions et prochaines actions',
                    lines: 4,
                  ),
                ],
                if (_kind == 'leave') ...[
                  _dateButton('À partir du', 'start', _start),
                  _dateButton('Jusqu’au', 'end', _end),
                  _text(
                    'reason',
                    'Ce que le responsable doit savoir',
                    help:
                        'Partagez seulement les informations utiles pour adapter les engagements.',
                    lines: 3,
                  ),
                ],
                if (_kind == 'case') ...[
                  _dateButton('Date des faits', 'date', _date),
                  _text(
                    'facts',
                    'Quels faits précis doivent être examinés ?',
                    lines: 4,
                  ),
                  _choice(
                    'Tâche concernée',
                    _task,
                    _tasks
                        .where(
                          (t) =>
                              t['can_change_deadline'] == true &&
                              veilleRows(
                                t['assignees'],
                              ).any((m) => m['id'] == _owner),
                        )
                        .map((t) => {'id': t['id'], 'name': t['title']})
                        .toList(),
                    (v) => setState(() => _task = v),
                    optional: true,
                    emptyLabel: 'Sans tâche liée',
                  ),
                  _choice(
                    'Règle applicable',
                    _rule,
                    veilleRows(
                      _context['rules'],
                    ).where((r) => r['retired'] != true).toList(),
                    (v) => setState(() => _rule = v),
                    optional: true,
                    emptyLabel: 'Accompagnement sans mesure disciplinaire',
                  ),
                  _choice(
                    'Membre d’EnacChef chargé de donner son avis',
                    _bureau,
                    veilleRows(
                      _context['bureau'],
                    ).where((m) => m['id'] != _owner).toList(),
                    (v) => setState(() => _bureau = v),
                  ),
                  const Text(
                    'Le dossier reste en préparation jusqu’à sa notification. Le membre pourra répondre avant la proposition et demander un réexamen après la décision. L’avis d’EnacChef et la décision doivent être portés par deux personnes distinctes.',
                  ),
                ],
                if (_kind == 'case_action') ...[
                  if (_proposal || _decision) ...[
                    _enum(
                      'Action proposée',
                      _outcome,
                      {
                        'accompagnement',
                        'clarification',
                        'classement_sans_suite',
                        ...((_initial['rule'] as Map?)?['allowed_actions']
                                    as List? ??
                                [])
                            .map((v) => v.toString()),
                      },
                      (v) => setState(() => _outcome = v),
                      enabled: !_decision,
                    ),
                    if (_outcome == 'penalite_financiere')
                      _number('amount', 'Montant en FCFA', minimum: 1),
                    if (_decision)
                      const Text(
                        'La décision porte sur la proposition examinée par EnacChef. Une modification demande un nouvel avis.',
                      ),
                  ],
                  if (widget.action == 'accept')
                    const Text(
                      'Cette acceptation permettra la clôture du dossier et, si une pénalité financière a été décidée, son rapprochement avec la Finance.',
                    ),
                  _text(
                    'message',
                    widget.action == 'respond'
                        ? 'Ma réponse et les éléments à prendre en compte'
                        : widget.action == 'appeal'
                        ? 'Pourquoi demander un réexamen ?'
                        : 'Motif, avis ou précision',
                    lines: 4,
                  ),
                ],
                if (_kind == 'leave_action')
                  _text(
                    'message',
                    'Expliquer la réponse et les adaptations convenues',
                    lines: 3,
                  ),
                if (_kind == 'rule') ...[
                  _text(
                    'content',
                    'Texte de la règle adoptée',
                    help:
                        'Précisez les obligations, les mesures possibles et les conditions d’application.',
                    lines: 6,
                  ),
                  _dateButton('Entrée en vigueur', 'date', _date),
                  const Text('Mesures expressément prévues par cette règle'),
                  for (final v in [
                    'accompagnement',
                    'clarification',
                    'avertissement',
                    'penalite_financiere',
                    'classement_sans_suite',
                  ])
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(veilleLabel(v)),
                      value: _allowed.contains(v),
                      onChanged: _busy || _planRestricted
                          ? null
                          : (b) => setState(() {
                              if (b == true) {
                                _allowed.add(v);
                              } else {
                                _allowed.remove(v);
                              }
                            }),
                    ),
                  if (_allowed.contains('penalite_financiere'))
                    _number(
                      'maximum_amount',
                      'Montant maximal prévu, en FCFA',
                      minimum: 1,
                    ),
                ],
                if (_kind == 'settings') ...[
                  const Text(
                    'Les heures utilisent UTC, qui correspond à l’heure du Sénégal. Une même heure de début et de fin désactive la plage silencieuse.',
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activer les rappels d’échéance'),
                    value: _reminders,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _reminders = v),
                  ),
                  const Text(
                    'Rappels à J−3, J−1 et le jour convenu ; suivi du retard puis remontée au responsable.',
                  ),
                  const SizedBox(height: 16),
                  _number(
                    'quiet_start_hour',
                    'Début des heures silencieuses',
                    maximum: 23,
                  ),
                  _number(
                    'quiet_end_hour',
                    'Fin des heures silencieuses',
                    maximum: 23,
                  ),
                  _number(
                    'escalation_days',
                    'Remonter un retard après combien de jours ?',
                    minimum: 1,
                    maximum: 30,
                  ),
                  _number(
                    'response_days',
                    'Délai de réponse à un dossier, en jours',
                    minimum: 1,
                    maximum: 30,
                  ),
                  _number(
                    'appeal_days',
                    'Délai de demande de réexamen, en jours',
                    minimum: 1,
                    maximum: 60,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Préparer les bilans automatiquement'),
                    value: _autoReports,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _autoReports = v),
                  ),
                  _choice(
                    'Jour du point hebdomadaire',
                    _fields['weekly_day']!.text,
                    [
                      for (var i = 0; i < 7; i++)
                        {
                          'id': '$i',
                          'name': [
                            'Lundi',
                            'Mardi',
                            'Mercredi',
                            'Jeudi',
                            'Vendredi',
                            'Samedi',
                            'Dimanche',
                          ][i],
                        },
                    ],
                    (v) => setState(() => _fields['weekly_day']!.text = v!),
                  ),
                  _number(
                    'report_hour',
                    'Heure de préparation des bilans',
                    maximum: 23,
                  ),
                  const Text(
                    'Le bilan mensuel est préparé le premier jour du mois. Les bilans enregistrés conservent leur contenu pour la passation.',
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('veille-form-submit'),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    );
  }
}
