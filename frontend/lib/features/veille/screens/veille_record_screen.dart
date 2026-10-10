import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../shared/attachments/attachment_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/ui/reading_blocks.dart';
import '../../tasks/models/task_model.dart';
import '../services/veille_gateway.dart';
import '../widgets/veille_form.dart';
import '../widgets/veille_ui.dart';

class VeilleRecordScreen extends StatefulWidget {
  final String kind, id;
  final VeilleGateway? gateway;
  const VeilleRecordScreen({
    super.key,
    required this.kind,
    required this.id,
    this.gateway,
  });
  @override
  State<VeilleRecordScreen> createState() => _VeilleRecordScreenState();
}

class _VeilleRecordScreenState extends State<VeilleRecordScreen> {
  late final VeilleGateway _gateway;
  VeilleJson? _record, _bundle;
  bool _loading = true, _busy = false;
  String? _error;
  final _comment = TextEditingController();
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  VeilleJson get _ctx =>
      Map<String, dynamic>.from(_bundle?['context'] as Map? ?? {});
  VeilleJson get _item => _record ?? {};
  bool get _coordinate => _ctx['can_coordinate'] == true;
  String get _uid => _ctx['user_id'].toString();

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiVeilleGateway();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    try {
      final results = await Future.wait([
        _gateway.detail(widget.kind, widget.id),
        _gateway.load(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: now.weekday - 1)),
          end: DateTime(now.year, now.month, now.day),
        ),
      ]);
      if (mounted) {
        setState(() {
          _record = results[0];
          _bundle = results[1];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _form(String kind, {String? action, VeilleJson? initial}) async {
    if (_busy || _bundle == null) return;
    final ok = await showVeilleForm(
      context,
      kind: kind,
      gateway: _gateway,
      data: _bundle!,
      initial: initial ?? _item,
      action: action,
    );
    if (ok && mounted) {
      _notice('Le suivi a été enregistré.');
      await _load();
    }
  }

  Future<void> _taskStatus(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _gateway.taskStatus(widget.id, status);
      if (mounted) {
        _notice('La tâche a été mise à jour.');
        await _load();
      }
    } catch (e) {
      _notice(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checklist(String id, bool done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _gateway.taskChecklist(id, done);
      if (mounted) await _load();
    } catch (e) {
      _notice(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareComment() async {
    final content = _comment.text.trim();
    if (_busy) return;
    if (content.length < 6) {
      _notice('Précisez votre retour avec une phrase complète.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _gateway.taskComment(widget.id, content);
      _comment.clear();
      if (mounted) {
        _notice('Votre retour a été partagé.');
        await _load();
      }
    } catch (e) {
      _notice(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _proofInput() async {
    if (_busy) return;
    try {
      final file = await pickAttachment();
      if (file == null || !mounted) return;
      setState(() => _busy = true);
      await AttachmentService().upload('/tasks/${widget.id}/proof-file', file);
      if (mounted) {
        _notice('Le justificatif a été joint.');
        await _load();
      }
    } catch (error) {
      _notice(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openProof() async {
    final raw = _item['proof_url']?.toString();
    if (raw == null || _busy) return;
    final uri = Uri.parse(ApiClient.serverUrl).resolve(raw);
    if (!{'http', 'https'}.contains(uri.scheme)) {
      _notice('Le lien du justificatif est invalide.');
      return;
    }
    if (uri.origin != Uri.parse(ApiClient.serverUrl).origin) {
      try {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          _notice('Le justificatif n’a pas pu être ouvert.');
        }
      } catch (e) {
        _notice(e.toString());
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _gateway.downloadProof(uri.toString());
      final image =
          bytes.length > 4 &&
          ((bytes[0] == 0x89 && bytes[1] == 0x50) ||
              (bytes[0] == 0xff && bytes[1] == 0xd8));
      if (!mounted) return;
      if (image) {
        await showDialog<void>(
          context: context,
          builder: (c) => Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(title: const Text('Justificatif du livrable')),
              body: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
          ),
        );
      } else {
        final extension =
            bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50
            ? 'pdf'
            : 'bin';
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Enregistrer le justificatif',
          fileName: 'justificatif-${widget.id}.$extension',
          bytes: bytes,
        );
        if (kIsWeb || path != null) {
          _notice('Le justificatif a été enregistré.');
        }
      }
    } catch (e) {
      _notice(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _gateway.exportReport(widget.id);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le bilan Veille',
        fileName: 'enactspace-veille-${widget.id}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
      if (kIsWeb || path != null) _notice('Le bilan a été enregistré.');
    } catch (e) {
      _notice(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, String? text, IconData icon) =>
      text == null || text.trim().isEmpty
      ? const SizedBox.shrink()
      : VeilleCard(title: title, icon: icon, child: ReadingBlocks(text));

  Widget _history() => VeilleCard(
    title: 'Ce qui a été partagé et décidé',
    icon: Icons.history_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final event in veilleRows(_item['events']))
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${event['actor_name']} · ${veilleDate(event['created_at'], withTime: true)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                ReadingBlocks(event['message']?.toString() ?? ''),
                if ((event['details'] as Map?)?['previous_due_date'] != null)
                  Text(
                    'Échéance précédente : ${veilleDate((event['details'] as Map)['previous_due_date'], withTime: true)}',
                  ),
                if ((event['details'] as Map?)?['due_date'] != null)
                  Text(
                    'Échéance convenue : ${veilleDate((event['details'] as Map)['due_date'], withTime: true)}',
                  ),
                if ((event['details'] as Map?)?['before'] is Map &&
                    ((event['details'] as Map)['before'] as Map)['status'] !=
                        null)
                  Text(
                    'État précédent : ${veilleLabel(((event['details'] as Map)['before'] as Map)['status']?.toString())}',
                  ),
                if ((event['details'] as Map?)?['after'] is Map &&
                    ((event['details'] as Map)['after'] as Map)['status'] !=
                        null)
                  Text(
                    'État retenu : ${veilleLabel(((event['details'] as Map)['after'] as Map)['status']?.toString())}',
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  List<Widget> _plan() => [
    _section(
      'Le résultat que nous préparons',
      _item['expected_result']?.toString(),
      Icons.flag_rounded,
    ),
    _section(
      'La disponibilité convenue',
      _item['availability']?.toString(),
      Icons.event_available_rounded,
    ),
    VeilleCard(
      title: 'Actions et formations liées',
      icon: Icons.route_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final task in veilleRows(_item['tasks']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(task['title'].toString()),
              subtitle: Text(veilleLabel(task['status'].toString())),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context
                  .push('/veille/records/task/${task['id']}', extra: _gateway)
                  .then((_) {
                    if (mounted) _load();
                  }),
            ),
          for (final course in veilleRows(_item['assigned_courses']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(course['title'].toString()),
              subtitle: Text(
                course['is_mastered'] == true
                    ? 'Formation réussie'
                    : course['is_locked'] == true
                    ? course['lock_reason'].toString()
                    : 'Formation à poursuivre',
                style: const TextStyle(height: 1.5),
              ),
              trailing: Icon(
                course['is_mastered'] == true
                    ? Icons.check_circle_rounded
                    : course['is_locked'] == true
                    ? Icons.lock_outline_rounded
                    : Icons.school_rounded,
              ),
              onTap: () =>
                  context.push('/academy/courses/${course['id']}?resume=true'),
            ),
          if (veilleRows(_item['tasks']).isEmpty &&
              veilleRows(_item['assigned_courses']).isEmpty)
            const Text(
              'Ajoutez des actions concrètes ou des formations pour préparer cet engagement.',
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (_coordinate)
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _form(
                          'action',
                          initial: {
                            'owner_id': _item['owner_id'],
                            'plan_id': widget.id,
                            'pole_id': _item['pole_id'],
                            'project_id': _item['project_id'],
                            'season_id': _item['season_id'],
                            'due_date': _item['due_date'],
                          },
                        ),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Confier une action liée'),
                ),
              if (_coordinate || _item['owner_id'] == _uid)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _form('plan'),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Mettre à jour l’engagement'),
                ),
            ],
          ),
        ],
      ),
    ),
  ];

  List<Widget> _blocker() => [
    _section(
      'La difficulté rencontrée',
      _item['description']?.toString(),
      Icons.help_outline_rounded,
    ),
    _section(
      'L’aide attendue',
      _item['requested_help']?.toString(),
      Icons.handshake_rounded,
    ),
    _section(
      'La prochaine action',
      _item['next_action']?.toString(),
      Icons.arrow_forward_rounded,
    ),
    if (_item['status'] == 'resolved')
      _section(
        'Ce qui a permis d’avancer',
        _item['resolution']?.toString(),
        Icons.check_circle_rounded,
      ),
    if (_item['status'] == 'open' &&
        (_coordinate ||
            {_item['owner_id'], _item['created_by_id']}.contains(_uid)))
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _form('blocker'),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text(
            'Préparer la prochaine étape ou résoudre le blocage',
          ),
        ),
      ),
    if (_item['task_id'] != null)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.push(
            '/veille/records/task/${_item['task_id']}',
            extra: _gateway,
          ),
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('Retrouver la tâche concernée'),
        ),
      ),
  ];

  List<Widget> _leave() => [
    _section(
      'Les éléments utiles pour adapter le travail',
      _item['reason']?.toString(),
      Icons.event_busy_rounded,
    ),
    _section(
      'La réponse et les adaptations convenues',
      _item['response']?.toString(),
      Icons.handshake_rounded,
    ),
    if (!{'rejected', 'cancelled'}.contains(_item['status']))
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (_coordinate &&
              _item['member_id'] != _uid &&
              _item['status'] == 'requested') ...[
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _form('leave_action', action: 'approved'),
              child: const Text('Approuver et adapter les engagements'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _form('leave_action', action: 'rejected'),
              child: const Text('Apporter une réponse différente'),
            ),
          ],
          if (_coordinate || _item['member_id'] == _uid)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _form('leave_action', action: 'cancelled'),
              child: const Text('Annuler cette indisponibilité'),
            ),
        ],
      ),
  ];

  List<Widget> _case() => [
    _section(
      'Les faits à examiner',
      _item['facts']?.toString(),
      Icons.find_in_page_rounded,
    ),
    VeilleCard(
      title: 'Le cadre de ce dossier',
      icon: Icons.balance_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Date des faits : ${veilleDate(_item['observed_at'])}',
            style: const TextStyle(height: 1.6),
          ),
          Text(
            'Avis d’EnacChef : ${_item['bureau_reviewer_name'] ?? 'À préciser'}',
            style: const TextStyle(height: 1.6),
          ),
          if (_item['response_deadline'] != null)
            Text(
              'Réponse attendue avant le ${veilleDate(_item['response_deadline'], withTime: true)}',
              style: const TextStyle(height: 1.6),
            ),
          if (_item['appeal_until'] != null)
            Text(
              'Demande de réexamen possible jusqu’au ${veilleDate(_item['appeal_until'], withTime: true)}',
              style: const TextStyle(height: 1.6),
            ),
          const SizedBox(height: 14),
          if (_item['rule'] is Map) ...[
            Text(
              (_item['rule'] as Map)['title'].toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ReadingBlocks((_item['rule'] as Map)['content'].toString()),
          ] else
            const Text(
              'Ce dossier permet un accompagnement ou une clarification. Une mesure disciplinaire exige une règle adoptée et applicable aux faits.',
            ),
        ],
      ),
    ),
    _section(
      'La proposition préparée',
      _item['proposal']?.toString(),
      Icons.edit_note_rounded,
    ),
    _section(
      'L’avis d’EnacChef',
      _item['endorsement']?.toString(),
      Icons.groups_rounded,
    ),
    _section(
      'La décision communiquée',
      _item['decision']?.toString(),
      Icons.gavel_rounded,
    ),
    if (_item['decision_action'] != null)
      VeilleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              veilleLabel(_item['decision_action'].toString()),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if ((_item['amount'] as num? ?? 0) > 0)
              Text(
                '${_item['amount']} FCFA',
                style: const TextStyle(height: 1.6),
              ),
            if (_item['decision_action'] == 'penalite_financiere')
              Text(
                _item['fee_id'] == null
                    ? 'Le rapprochement financier intervient après acceptation ou expiration du délai de réexamen, à la clôture du dossier.'
                    : 'La décision est rapprochée avec la Finance. Une pénalité déjà liée aux mêmes faits est prise en compte.',
                style: const TextStyle(height: 1.6),
              ),
          ],
        ),
      ),
    if ((_item['available_actions'] as List? ?? []).isNotEmpty)
      VeilleCard(
        title: 'La prochaine étape',
        icon: Icons.route_rounded,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in (_item['available_actions'] as List))
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _form('case_action', action: action.toString()),
                child: Text(veilleLabel(action.toString()), softWrap: true),
              ),
          ],
        ),
      ),
  ];

  List<Widget> _report() {
    final snapshot = Map<String, dynamic>.from(_item['snapshot'] as Map? ?? {});
    final totals = Map<String, dynamic>.from(snapshot['totals'] as Map? ?? {});
    return [
      _section(
        'Ce que nous retenons',
        _item['observations']?.toString(),
        Icons.auto_stories_rounded,
      ),
      _section(
        'Décisions et prochaines actions',
        _item['next_actions']?.toString(),
        Icons.flag_rounded,
      ),
      VeilleCard(
        title: 'Les résultats de la période',
        icon: Icons.insights_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${totals['due'] ?? 0} livrables dus · ${totals['accepted'] ?? 0} acceptés · ${totals['on_time'] ?? 0} remis à temps',
              style: const TextStyle(height: 1.7),
            ),
            Text(
              '${totals['late'] ?? 0} retards à examiner · ${totals['blockers'] ?? 0} blocages · ${totals['awaiting_review'] ?? 0} livrables à relire',
              style: const TextStyle(height: 1.7),
            ),
            const SizedBox(height: 18),
            for (final person in veilleRows(snapshot['members']))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person['name'].toString(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${person['accepted']} acceptés sur ${person['due']} dus · ${person['on_time']} remis à temps',
                      style: const TextStyle(height: 1.6),
                    ),
                  ],
                ),
              ),
            ReadingBlocks(snapshot['method']?.toString() ?? ''),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Exporter ce bilan en CSV'),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _task() {
    final task = TaskModel.fromJson(_item);
    final actor = task.canManage || task.currentUserAssigned;
    return [
      _section(
        'Ce que nous préparons',
        _item['description']?.toString(),
        Icons.flag_rounded,
      ),
      VeilleCard(
        title: 'Avancer et partager le résultat',
        icon: Icons.task_alt_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              veilleRows(_item['assignees']).map((m) => m['name']).join(', '),
              style: const TextStyle(height: 1.6),
            ),
            if (veilleRows(_item['checklist']).isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final step in veilleRows(_item['checklist']))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: step['is_done'] == true,
                    onChanged: actor && !task.isTerminal && !_busy
                        ? (value) =>
                              _checklist(step['id'].toString(), value == true)
                        : null,
                  ),
                  title: Text(step['title'].toString()),
                ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (_item['proof_url'] != null)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _openProof,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Ouvrir le justificatif'),
                  ),
                if (actor && !task.isTerminal)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _proofInput,
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Partager un justificatif'),
                  ),
                if (actor)
                  for (final status in task.allowedStatusTransitions.where(
                    (s) => s != 'valide' && s != 'bloque',
                  ))
                    OutlinedButton(
                      onPressed: _busy ? null : () => _taskStatus(status),
                      child: Text(
                        status == 'termine'
                            ? 'Remettre le livrable'
                            : veilleLabel(status),
                      ),
                    ),
                if (!{'termine', 'valide', 'annule'}.contains(task.status))
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _form(
                            'blocker',
                            initial: {'task_id': widget.id, 'owner_id': _uid},
                          ),
                    icon: const Icon(Icons.handshake_rounded),
                    label: const Text('Partager un blocage'),
                  ),
                if (_item['can_review'] == true)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _form('review'),
                    icon: const Icon(Icons.rate_review_rounded),
                    label: const Text('Relire ce livrable'),
                  ),
                if (_item['can_change_deadline'] == true)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _form('deadline'),
                    icon: const Icon(Icons.event_rounded),
                    label: const Text('Ajuster l’échéance avec un motif'),
                  ),
              ],
            ),
          ],
        ),
      ),
      VeilleCard(
        title: 'Échanger pour avancer',
        icon: Icons.forum_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (veilleRows(_item['comments']).isEmpty)
              const Text(
                'Un besoin de précision ou une aide à proposer ? Partagez votre retour avec les personnes qui suivent cette action.',
              ),
            for (final comment in veilleRows(_item['comments']))
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${comment['author_name']} · ${veilleDate(comment['created_at'], withTime: true)}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    ReadingBlocks(comment['content'].toString()),
                  ],
                ),
              ),
            if (actor || _ctx['global_scope'] == true) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _comment,
                enabled: !_busy,
                minLines: 2,
                maxLines: 6,
                maxLength: 12000,
                decoration: const InputDecoration(
                  labelText: 'Un retour ou une aide à partager',
                  helperText: 'Décrivez votre retour en une phrase complète.',
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _shareComment,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Partager mon retour'),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: LayoutBuilder(
      builder: (context, c) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(c.maxWidth < 600 ? 16 : 28),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/veille');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Retour au suivi Veille'),
                ),
              ),
              if (_loading || _busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
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
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              if (_record != null && _error == null) ...[
                VeilleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        (_item['title'] ??
                                _item['member_name'] ??
                                'Indisponibilité')
                            .toString(),
                        style: c.maxWidth < 600
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      if (_item['status'] != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: VeilleStatus(_item['status'].toString()),
                        ),
                      if (_item['member_name'] != null)
                        Text(
                          _item['member_name'].toString(),
                          style: const TextStyle(height: 1.6),
                        ),
                      if (_item['due_date'] != null)
                        Text(
                          'Échéance : ${veilleDate(_item['due_date'], withTime: true)}',
                          style: const TextStyle(height: 1.6),
                        ),
                      if (_item['review_at'] != null)
                        Text(
                          'Prochain point : ${veilleDate(_item['review_at'], withTime: true)}',
                          style: const TextStyle(height: 1.6),
                        ),
                      if (_item['start_date'] != null)
                        Text(
                          '${veilleDate(_item['start_date'])} — ${veilleDate(_item['end_date'])}',
                          style: const TextStyle(height: 1.6),
                        ),
                      if (_item['period_start'] != null)
                        Text(
                          '${veilleDate(_item['period_start'])} — ${veilleDate(_item['period_end'])}',
                          style: const TextStyle(height: 1.6),
                        ),
                    ],
                  ),
                ),
                ...switch (widget.kind) {
                  'plan' => _plan(),
                  'blocker' => _blocker(),
                  'leave' => _leave(),
                  'case' => _case(),
                  'report' => _report(),
                  'task' => _task(),
                  _ => [const VeilleEmpty('Ce dossier n’est pas disponible.')],
                },
                _history(),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
