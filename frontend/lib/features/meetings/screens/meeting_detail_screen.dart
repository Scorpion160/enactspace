import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../models/meeting_model.dart';
import '../services/meetings_service.dart';

class MeetingDetailScreen extends StatefulWidget {
  final String meetingId;
  final MeetingsService? service;

  const MeetingDetailScreen({super.key, required this.meetingId, this.service});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  late final MeetingsService _service;
  final MembersService _membersService = MembersService();
  MeetingModel? _meeting;
  List<MeetingMemberModel> _members = const [];
  bool _loading = true;
  String? _error;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MeetingsService();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _service.getMeeting(widget.meetingId),
        _service.listMembers(widget.meetingId),
      ]);
      if (!mounted) return;
      setState(() {
        _meeting = results[0] as MeetingModel;
        _members = results[1] as List<MeetingMemberModel>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final meeting = _meeting!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Header(meeting: meeting, onJoin: meeting.isClosed ? null : _join),
          const SizedBox(height: 16),
          _InfoCard(meeting: meeting),
          if (meeting.canManage) ...[
            const SizedBox(height: 16),
            _HostActions(
              busy: _actionBusy,
              closed: meeting.isClosed,
              live: meeting.isLive,
              canDelete: meeting.canDelete,
              onInvite: _invite,
              onSettings: _openSettings,
              onEnd: meeting.isLive ? _end : null,
              onCancel: meeting.isScheduled ? _cancel : null,
              onDelete: _delete,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Participants',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
              Text('${_members.length}'),
            ],
          ),
          const SizedBox(height: 10),
          if (_members.isEmpty)
            const Text('Aucun participant enregistré.')
          else
            for (final member in _members) _MemberTile(member: member),
        ],
      ),
    );
  }

  void _join() {
    final meeting = _meeting;
    if (meeting == null) return;
    context.go('/meetings/${meeting.id}/live', extra: meeting.title);
  }

  Future<void> _invite() async {
    try {
      final options = await _membersService.getMembers();
      if (!mounted) return;
      final existing = _members.map((member) => member.userId).toSet();
      final selection = await showModalBottomSheet<_InviteSelection>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => _InviteMembersSheet(
          members: options
              .where((member) => !existing.contains(member.id))
              .toList(),
        ),
      );
      if (selection == null || selection.userIds.isEmpty || !mounted) return;
      setState(() => _actionBusy = true);
      await _service.inviteMembers(
        widget.meetingId,
        selection.userIds.toList(),
        role: selection.role,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      _snack(_message(error));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openSettings() async {
    final meeting = _meeting;
    if (meeting == null) return;
    final updated = await showModalBottomSheet<MeetingModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _EditMeetingSheet(meeting: meeting, service: _service),
    );
    if (updated == null || !mounted) return;
    await _load();
  }

  Future<void> _end() async {
    if (!await _confirm(
      'Terminer la réunion ?',
      'Les participants verront la réunion comme terminée dans EnactSpace.',
      'Terminer',
    )) {
      return;
    }
    await _runAction(() => _service.endMeeting(widget.meetingId));
  }

  Future<void> _cancel() async {
    if (!await _confirm(
      'Annuler la réunion ?',
      'Tous les invités seront notifiés de l’annulation.',
      'Annuler la réunion',
    )) {
      return;
    }
    await _runAction(() => _service.cancelMeeting(widget.meetingId));
  }

  Future<void> _delete() async {
    final meeting = _meeting;
    if (meeting == null || !meeting.canDelete || meeting.isLive) return;
    final confirmed = await _confirmDelete(meeting.title);
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _actionBusy = true);
    try {
      await _service.deleteMeeting(widget.meetingId);
      if (!mounted) return;
      context.go('/meetings');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Réunion supprimée définitivement.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) _snack(_message(error));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _runAction(Future<MeetingModel> Function() action) async {
    setState(() => _actionBusy = true);
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) _snack(_message(error));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<bool> _confirmDelete(String meetingTitle) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer définitivement la réunion ?'),
        content: Text(
          '« $meetingTitle » sera supprimée de l’historique EnactMeet. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();
}

class _Header extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback? onJoin;

  const _Header({required this.meeting, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.softBlack, Color(0xFF25313A)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.video_call_rounded,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  meeting.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${meeting.statusLabel} · ${meeting.scheduleLabel} · ${meeting.scopeLabel}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (meeting.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              meeting.description!,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ],
          if (onJoin != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.secondary,
                foregroundColor: colors.onSecondary,
              ),
              onPressed: onJoin,
              icon: const Icon(Icons.video_call_rounded),
              label: Text(
                meeting.isLive ? 'Rejoindre en direct' : 'Entrer dans la salle',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final MeetingModel meeting;
  const _InfoCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = <(IconData, String, String)>[
      (Icons.schedule_rounded, 'Quand', meeting.scheduleLabel),
      (Icons.groups_2_rounded, 'Avec', meeting.scopeLabel),
      (
        Icons.people_alt_rounded,
        'Invités',
        '${meeting.invitedCount} personne${meeting.invitedCount > 1 ? 's' : ''}',
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'L’essentiel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              meeting.isClosed
                  ? 'Retrouvez ici les informations utiles de cette réunion.'
                  : 'Tout est prêt pour rejoindre la salle au bon moment.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.$1, size: 20),
                        const SizedBox(width: 9),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(item.$3),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HostActions extends StatelessWidget {
  final bool busy;
  final bool closed;
  final bool live;
  final bool canDelete;
  final VoidCallback onInvite;
  final VoidCallback onSettings;
  final VoidCallback? onEnd;
  final VoidCallback? onCancel;
  final VoidCallback onDelete;

  const _HostActions({
    required this.busy,
    required this.closed,
    required this.live,
    required this.canDelete,
    required this.onInvite,
    required this.onSettings,
    required this.onEnd,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestion de la réunion',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: busy || closed ? null : onInvite,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Inviter'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || closed ? null : onSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Paramètres de la réunion'),
                ),
                if (onEnd != null)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onEnd,
                    icon: const Icon(Icons.stop_circle_rounded),
                    label: const Text('Terminer'),
                  ),
                if (onCancel != null)
                  TextButton.icon(
                    onPressed: busy ? null : onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Annuler'),
                  ),
                if (canDelete)
                  Tooltip(
                    message: live
                        ? 'Terminez la réunion avant de la supprimer.'
                        : 'Supprimer définitivement cette réunion',
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: busy || live ? null : onDelete,
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Supprimer'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final MeetingMemberModel member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            member.displayName.isEmpty
                ? '?'
                : member.displayName.characters.first.toUpperCase(),
          ),
        ),
        title: Text(member.displayName),
        subtitle: Text(member.roleLabel),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              member.isConnected ? Icons.circle : Icons.circle_outlined,
              size: 12,
              color: member.isConnected ? Colors.green : null,
            ),
            const SizedBox(width: 6),
            Text(member.isConnected ? 'En ligne' : 'Invité'),
          ],
        ),
      ),
    );
  }
}

class _InviteSelection {
  final Set<String> userIds;
  final String role;
  const _InviteSelection(this.userIds, this.role);
}

class _InviteMembersSheet extends StatefulWidget {
  final List<MemberModel> members;
  const _InviteMembersSheet({required this.members});

  @override
  State<_InviteMembersSheet> createState() => _InviteMembersSheetState();
}

class _InviteMembersSheetState extends State<_InviteMembersSheet> {
  final Set<String> _selected = {};
  final _search = TextEditingController();
  String _role = 'participant';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MemberModel> get _visible {
    final q = _search.text.trim().toLowerCase();
    return widget.members.where((member) {
      if (q.isEmpty) return true;
      return member.displayName.toLowerCase().contains(q) ||
          member.email.toLowerCase().contains(q);
    }).toList()..sort(MemberModel.compareAlphabetically);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ajouter des participants',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        _InviteSelection({..._selected}, _role),
                      ),
                child: const Text('Inviter'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'participant', label: Text('Participant')),
              ButtonSegment(value: 'cohost', label: Text('Co-hôte')),
            ],
            selected: {_role},
            onSelectionChanged: (value) => setState(() => _role = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Rechercher…',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _visible.isEmpty
                ? const Center(child: Text('Aucun membre disponible.'))
                : ListView.builder(
                    itemCount: _visible.length,
                    itemBuilder: (context, index) {
                      final member = _visible[index];
                      return CheckboxListTile(
                        value: _selected.contains(member.id),
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _selected.add(member.id);
                          } else {
                            _selected.remove(member.id);
                          }
                        }),
                        title: Text(member.displayName),
                        subtitle: Text(member.primaryRoleLabel),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SettingsSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _EditMeetingSheet extends StatefulWidget {
  final MeetingModel meeting;
  final MeetingsService service;

  const _EditMeetingSheet({required this.meeting, required this.service});

  @override
  State<_EditMeetingSheet> createState() => _EditMeetingSheetState();
}

class _EditMeetingSheetState extends State<_EditMeetingSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late DateTime? _start = widget.meeting.scheduledStart?.toLocal();
  late DateTime? _end = widget.meeting.scheduledEnd?.toLocal();
  late bool _scheduled = widget.meeting.scheduledStart != null;
  late bool _audioMuted = widget.meeting.startWithAudioMuted;
  late bool _videoMuted = widget.meeting.startWithVideoMuted;
  late bool _lobby = widget.meeting.lobbyEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.meeting.title);
    _description = TextEditingController(
      text: widget.meeting.description ?? '',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text(
            'Paramètres de la réunion',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Réglez ici les informations, la planification et les options EnactMeet.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          const _SettingsSectionTitle(
            icon: Icons.description_outlined,
            title: 'Informations',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Titre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description / ordre du jour',
            ),
          ),
          const SizedBox(height: 18),
          const _SettingsSectionTitle(
            icon: Icons.schedule_rounded,
            title: 'Planification',
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Planifier pour plus tard'),
            subtitle: const Text(
              'Désactivez pour transformer la réunion en salle à démarrage libre.',
            ),
            value: _scheduled,
            onChanged: (value) => setState(() {
              _scheduled = value;
              if (value) {
                _start ??= DateTime.now().add(const Duration(minutes: 30));
              } else {
                _start = null;
                _end = null;
              }
            }),
          ),
          if (_scheduled) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(start: true),
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_start == null ? 'Début' : _format(_start!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(start: false),
                    icon: const Icon(Icons.event_busy_rounded),
                    label: Text(
                      _end == null ? 'Fin (optionnel)' : _format(_end!),
                    ),
                  ),
                ),
              ],
            ),
            if (_end != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _end = null),
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Retirer l’heure de fin'),
                ),
              ),
          ],
          const SizedBox(height: 18),
          const _SettingsSectionTitle(
            icon: Icons.tune_rounded,
            title: 'Audio, vidéo et accès',
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.mic_off_rounded),
            title: const Text('Micro coupé au démarrage'),
            value: _audioMuted,
            onChanged: (value) => setState(() => _audioMuted = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.videocam_off_rounded),
            title: const Text('Caméra coupée au démarrage'),
            value: _videoMuted,
            onChanged: (value) => setState(() => _videoMuted = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.meeting_room_outlined),
            title: const Text('Autoriser le contrôle lobby'),
            subtitle: const Text(
              'L’hôte peut activer la salle d’attente depuis les options de sécurité Jitsi.',
            ),
            value: _lobby,
            onChanged: (value) => setState(() => _lobby = value),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fiber_manual_record_rounded),
            title: const Text('Enregistrement serveur'),
            subtitle: Text(
              widget.meeting.recordingEnabled
                  ? 'Disponible pour cette réunion.'
                  : 'Non activé sur cette réunion.',
            ),
            trailing: Icon(
              widget.meeting.recordingEnabled
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: widget.meeting.recordingEnabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime({required bool start}) async {
    final initial = start
        ? (_start ?? DateTime.now())
        : (_end ?? _start?.add(const Duration(hours: 1)) ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2) {
      _snack('Donnez un titre à la réunion.');
      return;
    }
    if (_scheduled && _start == null) {
      _snack('Choisissez la date et l’heure de début.');
      return;
    }
    if (_start != null && _end != null && !_end!.isAfter(_start!)) {
      _snack('La fin doit être postérieure au début.');
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await widget.service.updateMeeting(
        widget.meeting.id,
        title: _title.text,
        description: _description.text,
        scheduledStart: _scheduled ? _start : null,
        scheduledEnd: _scheduled ? _end : null,
        clearScheduledStart:
            !_scheduled && widget.meeting.scheduledStart != null,
        clearScheduledEnd:
            (!_scheduled || _end == null) &&
            widget.meeting.scheduledEnd != null,
        startWithAudioMuted: _audioMuted,
        startWithVideoMuted: _videoMuted,
        lobbyEnabled: _lobby,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      _snack(error.toString().replaceFirst('Exception: ', '').trim());
      setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _format(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month · $hour:$minute';
  }
}
