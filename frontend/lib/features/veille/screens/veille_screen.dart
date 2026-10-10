import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/ui/reading_blocks.dart';
import '../services/veille_gateway.dart';
import '../widgets/veille_form.dart';
import '../widgets/veille_ui.dart';

class VeilleScreen extends StatefulWidget {
  final VeilleGateway? gateway;
  final String? initialPoleId, initialProjectId;
  final String initialTab;
  const VeilleScreen({
    super.key,
    this.gateway,
    this.initialPoleId,
    this.initialProjectId,
    this.initialTab = 'overview',
  });
  @override
  State<VeilleScreen> createState() => _VeilleScreenState();
}

class _VeilleScreenState extends State<VeilleScreen> {
  late final VeilleGateway _gateway;
  final ScrollController _scroll = ScrollController();
  late DateTime _start, _end;
  VeilleJson? _data;
  String? _error, _pole, _project, _member, _season;
  String _tab = 'overview', _taskFilter = 'all';
  bool _loading = true;
  int _generation = 0;
  VeilleJson get _ctx =>
      Map<String, dynamic>.from(_data?['context'] as Map? ?? {});
  VeilleJson get _summary =>
      Map<String, dynamic>.from(_data?['summary'] as Map? ?? {});
  VeilleJson get _totals =>
      Map<String, dynamic>.from(_summary['totals'] as Map? ?? {});
  bool get _coordinate => _ctx['can_coordinate'] == true;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiVeilleGateway();
    _pole = widget.initialPoleId;
    _project = widget.initialProjectId;
    _tab =
        {
          'overview',
          'members',
          'groups',
          'plans',
          'blockers',
          'reports',
          'leaves',
          'cases',
        }.contains(widget.initialTab)
        ? widget.initialTab
        : 'overview';
    final now = DateTime.now();
    _end = DateTime(now.year, now.month, now.day);
    _start = _end.subtract(Duration(days: now.weekday - 1));
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _gateway.load(
        start: _start,
        end: _end,
        poleId: _pole,
        projectId: _project,
        memberId: _member,
        seasonId: _season,
      );
      if (mounted && generation == _generation) setState(() => _data = data);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _form(String kind, {VeilleJson? initial}) async {
    if (_data == null || _loading) return;
    final success = await showVeilleForm(
      context,
      kind: kind,
      gateway: _gateway,
      data: _data!,
      initial:
          initial ??
          {
            'owner_id': _member ?? _ctx['user_id'],
            'member_id': _member ?? _ctx['user_id'],
            'pole_id': _pole,
            'project_id': _project,
            'season_id': _season,
            'period_start': _start.toIso8601String(),
            'period_end': _end.toIso8601String(),
          },
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le suivi a été enregistré.')),
      );
      await _load();
    }
  }

  Future<void> _open(String kind, String id) async {
    await context.push('/veille/records/$kind/$id', extra: _gateway);
    if (mounted) await _load();
  }

  void _selectTab(String tab) {
    setState(() => _tab = tab);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _period() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _start, end: _end),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Période des indicateurs et des bilans',
    );
    if (range == null || !mounted) return;
    setState(() {
      _start = range.start;
      _end = range.end;
    });
    await _load();
  }

  Widget _filter(
    String label,
    String? value,
    List<VeilleJson> values,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value'),
    initialValue: values.any((v) => v['id'] == value) ? value : '',
    isExpanded: true,
    itemHeight: null,
    decoration: InputDecoration(labelText: label),
    items: [
      DropdownMenuItem(
        value: '',
        child: Text(label == 'Année' ? 'Toutes' : 'Tous'),
      ),
      for (final item in values)
        DropdownMenuItem(
          value: item['id'].toString(),
          child: Text(item['name'].toString(), softWrap: true),
        ),
    ],
    onChanged: _loading
        ? null
        : (v) {
            changed(v == '' ? null : v);
            _load();
          },
  );

  List<VeilleJson> _records(String kind) {
    final rows = veilleRows((_data?['records'] as Map?)?[kind]);
    final taskIds = veilleRows(_summary['tasks']).map((t) => t['id']).toSet();
    final scopeMembers = veilleRows(_ctx['members'])
        .where(
          (m) =>
              (_pole == null ||
                  (m['pole_ids'] as List? ?? []).contains(_pole)) &&
              (_project == null ||
                  (m['project_ids'] as List? ?? []).contains(_project)),
        )
        .map((m) => m['id'])
        .toSet();
    return rows.where((r) {
      final owner = r['owner_id'] ?? r['member_id'];
      if (_member != null && owner != null && owner != _member) return false;
      if (_pole != null || _project != null) {
        if (kind == 'plans' || kind == 'reports') {
          if (_pole != null && r['pole_id'] != _pole) return false;
          if (_project != null && r['project_id'] != _project) return false;
        } else if (kind == 'blockers' || kind == 'cases') {
          if (r['task_id'] != null && !taskIds.contains(r['task_id'])) {
            return false;
          }
          if (r['task_id'] == null &&
              owner != null &&
              !scopeMembers.contains(owner)) {
            return false;
          }
        } else if (owner != null && !scopeMembers.contains(owner)) {
          return false;
        }
      }
      if (_season != null &&
          (kind == 'plans' || kind == 'reports') &&
          r['season_id'] != _season) {
        return false;
      }
      if (kind == 'reports') {
        final start = DateTime.tryParse(r['period_start'].toString()),
            end = DateTime.tryParse(r['period_end'].toString());
        if (start != null &&
            end != null &&
            (start.isAfter(_end) || end.isBefore(_start))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _metrics() => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns = constraints.maxWidth < 520 || scale > 1.4
          ? 1
          : constraints.maxWidth < 1050
          ? 2
          : 3;
      final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
      final entries = [
        ('due', 'Livrables dus', Icons.event_available_rounded),
        ('accepted', 'Livrables acceptés', Icons.verified_rounded),
        ('awaiting_review', 'À relire', Icons.rate_review_rounded),
        ('late', 'Retards à examiner', Icons.schedule_rounded),
        ('blockers', 'Blocages ouverts', Icons.handshake_rounded),
        ('attendance_due', 'Présences attendues', Icons.groups_rounded),
      ];
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final entry in entries)
            SizedBox(
              width: width,
              child: Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: entry.$1 == 'attendance_due'
                      ? null
                      : () => setState(() {
                          _tab = entry.$1 == 'blockers'
                              ? 'blockers'
                              : 'overview';
                          _taskFilter = entry.$1 == 'awaiting_review'
                              ? 'termine'
                              : {'late', 'due', 'accepted'}.contains(entry.$1)
                              ? entry.$1
                              : 'all';
                        }),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          entry.$3,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_totals[entry.$1] ?? 0}',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        Text(
                          entry.$2,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _tasks() {
    final tasks = veilleRows(_summary['tasks'])
        .where(
          (t) =>
              _taskFilter == 'all' ||
              (_taskFilter == 'late'
                  ? t['late'] == true
                  : _taskFilter == 'due'
                  ? t['due_in_period'] == true
                  : _taskFilter == 'accepted'
                  ? t['accepted_in_period'] == true
                  : t['status'] == _taskFilter),
        )
        .toList();
    return VeilleCard(
      title: 'Tâches et prochaines actions',
      icon: Icons.task_alt_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in {
                'all': 'Toutes',
                'due': 'Dues sur cette période',
                'accepted': 'Acceptées sur cette période',
                'late': 'En retard',
                'termine': 'À relire',
                'bloque': 'Bloquées',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _taskFilter == entry.key,
                  onSelected: (_) => setState(() => _taskFilter = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            const VeilleEmpty(
              'Aucune tâche ne correspond à cette sélection. Les nouvelles actions apparaîtront ici dès leur affectation.',
            ),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        task['title'].toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          VeilleStatus(task['status'].toString()),
                          if (task['late'] == true)
                            const VeilleStatus('Retard à examiner'),
                          if (task['leave_exempt'] == true)
                            const VeilleStatus('Indisponibilité approuvée'),
                        ],
                      ),
                      Text(
                        veilleRows(
                          task['assignees'],
                        ).map((m) => m['name']).join(', '),
                        style: const TextStyle(height: 1.5),
                      ),
                      Text(
                        'Échéance : ${veilleDate(task['due_date'], withTime: true)}',
                        style: const TextStyle(height: 1.5),
                      ),
                      if (task['pole_name'] != null ||
                          task['project_name'] != null)
                        Text(
                          (task['pole_name'] ?? task['project_name'])
                              .toString(),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _open('task', task['id'].toString()),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Ouvrir le suivi de la tâche'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _members() {
    final people = veilleRows(_summary['members']);
    return VeilleCard(
      title: _ctx['global_scope'] == true
          ? 'Chaque contribution compte'
          : 'Les engagements de mon périmètre',
      icon: Icons.people_alt_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Les résultats se lisent avec la charge confiée, les difficultés rencontrées et les retours reçus. Un taux seul ne résume pas l’engagement d’une personne.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 18),
          for (final person in people)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        person['name'].toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${person['assigned']} tâches affectées · ${person['due']} dues · ${person['accepted']} acceptées · ${person['on_time']} remises à temps',
                        style: const TextStyle(height: 1.6),
                      ),
                      const SizedBox(height: 10),
                      if (person['rate'] == null)
                        const Text(
                          'Aucun livrable dû sur cette période : taux non évaluable.',
                        )
                      else ...[
                        LinearProgressIndicator(
                          value:
                              (person['rate'] as num).toDouble().clamp(0, 100) /
                              100,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${person['rate']} % des livrables dus sont acceptés.',
                        ),
                      ],
                      if (person['limited_sample'] == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Peu d’engagements sur cette période : interprétation prudente.',
                            style: TextStyle(height: 1.5),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            _member = person['id'].toString();
                            _tab = 'overview';
                            _load();
                          }),
                          icon: const Icon(Icons.person_search_rounded),
                          label: const Text(
                            'Voir ses engagements et ses actions',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _groups() => VeilleCard(
    title: 'Pôles et projets',
    icon: Icons.hub_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (veilleRows(_summary['groups']).isEmpty)
          const VeilleEmpty(
            'Les actions rattachées à un pôle ou à un projet permettront de suivre leur avancement ici.',
          ),
        for (final group in veilleRows(_summary['groups']))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(group['name'].toString()),
            subtitle: Text(
              '${group['tasks']} actions · ${group['accepted']} livrables acceptés · ${group['late']} retards · ${group['blocked']} blocages',
              style: const TextStyle(height: 1.6),
            ),
            onTap: () {
              setState(() {
                if (group['kind'] == 'pole') {
                  _pole = group['id'].toString();
                  _project = null;
                } else {
                  _project = group['id'].toString();
                  _pole = null;
                }
                _member = null;
                _tab = 'overview';
              });
              _load();
            },
          ),
      ],
    ),
  );

  Widget _recordList(
    String plural,
    String singular,
    String title,
    String empty,
    IconData icon,
  ) {
    final rows = _records(plural);
    return VeilleCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rows.isEmpty) VeilleEmpty(empty),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        (row['title'] ??
                                row['member_name'] ??
                                'Indisponibilité')
                            .toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (row['status'] != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: VeilleStatus(row['status'].toString()),
                        ),
                      if (row['member_name'] != null)
                        Text(
                          row['member_name'].toString(),
                          style: const TextStyle(height: 1.6),
                        ),
                      if (row['due_date'] != null)
                        Text(
                          'Échéance : ${veilleDate(row['due_date'], withTime: true)}',
                        ),
                      if (row['review_at'] != null)
                        Text(
                          'Prochain point : ${veilleDate(row['review_at'], withTime: true)}',
                        ),
                      if (row['task_title'] != null)
                        Text(row['task_title'].toString()),
                      if (row['period_start'] != null)
                        Text(
                          '${veilleDate(row['period_start'])} — ${veilleDate(row['period_end'])}',
                        ),
                      if (row['start_date'] != null)
                        Text(
                          '${veilleDate(row['start_date'])} — ${veilleDate(row['end_date'])}',
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              _open(singular, row['id'].toString()),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Ouvrir le dossier'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rules() => VeilleCard(
    title: 'Règles et organisation du suivi',
    icon: Icons.rule_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ReadingBlocks(
          '### Des repères partagés\nUne règle précise les engagements attendus, les mesures possibles et sa date d’entrée en vigueur. Les décisions se prennent après écoute du membre et avis d’EnacChef.\n\n### Des rappels utiles\nLes échéances donnent lieu à des rappels espacés. Les indisponibilités approuvées sont prises en compte, et les tâches remises ou clôturées ne sont plus relancées.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : () => _form('rule'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Renseigner une règle adoptée'),
            ),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _form(
                      'settings',
                      initial: Map<String, dynamic>.from(
                        _ctx['settings'] as Map,
                      ),
                    ),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Régler les rappels et bilans'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (veilleRows(_ctx['rules']).isEmpty)
          const VeilleEmpty(
            'Aucune règle disciplinaire n’est renseignée. Le suivi et l’accompagnement restent disponibles.',
          ),
        for (final rule in veilleRows(_ctx['rules']))
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    rule['title'].toString(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Entrée en vigueur : ${veilleDate(rule['effective_from'])}',
                    style: const TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  ReadingBlocks(rule['content'].toString()),
                  Text(
                    (rule['allowed_actions'] as List? ?? [])
                        .map((v) => veilleLabel(v.toString()))
                        .join(' · '),
                    style: const TextStyle(height: 1.6),
                  ),
                  if ((rule['maximum_amount'] as num? ?? 0) > 0)
                    Text('Montant maximal : ${rule['maximum_amount']} FCFA'),
                  if (rule['retired'] == true)
                    const VeilleStatus('Remplacée pour les nouveaux dossiers')
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _retire(rule),
                        child: const Text(
                          'Remplacer cette règle pour les nouveaux dossiers',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _retire(VeilleJson rule) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remplacer cette règle ?'),
        content: const Text(
          'Les dossiers existants conserveront leur règle. Les nouveaux dossiers utiliseront une autre règle adoptée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await _gateway.save('/rules/${rule['id']}/retire', {});
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      'overview': 'Vue d’ensemble',
      'members': 'Enacteurs',
      'groups': 'Pôles et projets',
      'plans': 'Engagements',
      'blockers': 'Blocages',
      'reports': 'Bilans',
      'leaves': 'Indisponibilités',
      'cases': 'Dossiers',
      if (_ctx['can_manage_settings'] == true) 'rules': 'Règles et réglages',
    };
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 28),
              children: [
                VeilleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            Icons.travel_explore_rounded,
                            size: 38,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            _coordinate ? 'Pôle Veille' : 'Mon suivi',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Comprendre, accompagner et transmettre. Un engagement clair, une difficulté partagée et une prochaine action : c’est ainsi que nous avançons ensemble.',
                        style: TextStyle(height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Actualiser le suivi'),
                          ),
                          TextButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text(
                                  'Un suivi qui aide à avancer',
                                ),
                                content: const SingleChildScrollView(
                                  child: ReadingBlocks(
                                    '### Chaque enacteur\nRetrouve tes engagements, partage les blocages tôt et explique les éléments utiles pour adapter le travail. Les livrables sont remis puis relus par une autre personne.\n\n### Les responsables et Veille\nClarifiez les attentes, apportez une aide, relisez les résultats et convenez des prochaines étapes. L’appréciation tient compte des engagements confiés et des contraintes connues.\n\n### Les décisions\nUn dossier rassemble les faits et la réponse du membre. Veille formule une proposition, un membre d’EnacChef donne son avis et le Team Leader ou l’administration décide. Le membre peut demander un réexamen dans le délai communiqué.',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('J’ai compris'),
                                  ),
                                ],
                              ),
                            ),
                            icon: const Icon(Icons.info_outline_rounded),
                            label: const Text('Comment utiliser ce suivi ?'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null)
                  VeilleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Une connexion est nécessaire pour actualiser le suivi et enregistrer une décision.',
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            onPressed: _load,
                            child: const Text('Réessayer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_data != null) ...[
                  VeilleCard(
                    title: 'Période des indicateurs et des bilans',
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final width =
                            c.maxWidth < 700 ||
                                MediaQuery.textScalerOf(context).scale(16) > 22
                            ? c.maxWidth
                            : (c.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: width,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _period,
                                icon: const Icon(Icons.date_range_rounded),
                                label: Text(
                                  '${veilleDate(_start)} — ${veilleDate(_end)}',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _filter(
                                'Enacteur / Enactrice',
                                _member,
                                veilleRows(_ctx['members']),
                                (v) => setState(() => _member = v),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _filter(
                                'Pôle',
                                _pole,
                                veilleRows(_ctx['poles']),
                                (v) => setState(() {
                                  _pole = v;
                                  _project = null;
                                  _member = null;
                                }),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _filter(
                                'Projet',
                                _project,
                                veilleRows(_ctx['projects']),
                                (v) => setState(() {
                                  _project = v;
                                  _pole = null;
                                  _member = null;
                                }),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _filter(
                                'Année',
                                _season,
                                veilleRows(_ctx['seasons']),
                                (v) => setState(() => _season = v),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: [
                        for (final t in tabs.entries)
                          ChoiceChip(
                            key: ValueKey('veille-tab-${t.key}'),
                            label: Text(t.value),
                            selected: _tab == t.key,
                            onSelected: (_) => _selectTab(t.key),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (_tab == 'plans')
                          FilledButton.icon(
                            onPressed: _loading ? null : () => _form('plan'),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Définir un engagement'),
                          ),
                        if (_tab == 'overview' && _coordinate)
                          FilledButton.icon(
                            onPressed: _loading ? null : () => _form('action'),
                            icon: const Icon(Icons.add_task_rounded),
                            label: const Text('Confier une action'),
                          ),
                        if (_tab == 'blockers')
                          FilledButton.icon(
                            onPressed: _loading ? null : () => _form('blocker'),
                            icon: const Icon(Icons.handshake_rounded),
                            label: const Text('Partager un blocage'),
                          ),
                        if (_tab == 'reports' && _coordinate)
                          FilledButton.icon(
                            onPressed: _loading ? null : () => _form('report'),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Préparer un bilan'),
                          ),
                        if (_tab == 'leaves')
                          FilledButton.icon(
                            onPressed: _loading ? null : () => _form('leave'),
                            icon: const Icon(Icons.event_busy_rounded),
                            label: const Text('Signaler une indisponibilité'),
                          ),
                        if (_tab == 'cases' && _coordinate)
                          FilledButton.icon(
                            onPressed: _loading ? null : () => _form('case'),
                            icon: const Icon(Icons.folder_open_rounded),
                            label: const Text('Préparer un dossier de suivi'),
                          ),
                      ],
                    ),
                  ),
                  if (_tab == 'overview') ...[
                    _metrics(),
                    const SizedBox(height: 20),
                    _tasks(),
                    VeilleCard(
                      title: 'Lire les résultats avec leur contexte',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Qualité des livrables : ${_totals['quality'] == null ? 'non évaluée' : '${_totals['quality']} / 5, sur ${_totals['quality_samples']} retours'}',
                            style: const TextStyle(height: 1.6),
                          ),
                          Text(
                            'Présences : ${_totals['attendance_present'] ?? 0} sur ${_totals['attendance_due'] ?? 0} attendues, ${_totals['attendance_excused'] ?? 0} justifiées.',
                            style: const TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 16),
                          ReadingBlocks(_summary['method']?.toString() ?? ''),
                        ],
                      ),
                    ),
                  ],
                  if (_tab == 'members') _members(),
                  if (_tab == 'groups') _groups(),
                  if (_tab == 'plans')
                    _recordList(
                      'plans',
                      'plan',
                      'Des engagements clairs',
                      'Définissez le résultat attendu, la disponibilité et l’échéance. Les actions et formations liées permettront de suivre sa réalisation.',
                      Icons.flag_rounded,
                    ),
                  if (_tab == 'blockers')
                    _recordList(
                      'blockers',
                      'blocker',
                      'Les difficultés que nous pouvons résoudre ensemble',
                      'Aucun blocage partagé dans cette sélection. Signalez une difficulté dès qu’une aide devient nécessaire.',
                      Icons.handshake_rounded,
                    ),
                  if (_tab == 'reports')
                    _recordList(
                      'reports',
                      'report',
                      'Ce que nous apprenons de chaque période',
                      'Aucun bilan enregistré sur cette période. Les responsables peuvent préparer un point de suivi ou une passation.',
                      Icons.summarize_rounded,
                    ),
                  if (_tab == 'leaves')
                    _recordList(
                      'leaves',
                      'leave',
                      'Adapter le travail aux disponibilités',
                      'Les indisponibilités signalées apparaîtront ici pour préparer les adaptations avec le responsable.',
                      Icons.event_busy_rounded,
                    ),
                  if (_tab == 'cases')
                    _recordList(
                      'cases',
                      'case',
                      'Des faits, une réponse et une décision',
                      'Aucun dossier accessible dans cette sélection. Les dossiers restent privés et chaque membre peut répondre à ceux qui le concernent.',
                      Icons.balance_rounded,
                    ),
                  if (_tab == 'rules' && _ctx['can_manage_settings'] == true)
                    _rules(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
