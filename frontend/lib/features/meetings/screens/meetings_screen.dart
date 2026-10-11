import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/meeting_model.dart';
import '../services/meetings_service.dart';

class MeetingsScreen extends StatefulWidget {
  final MeetingsService? service;

  const MeetingsScreen({super.key, this.service});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  late final MeetingsService _service;
  final AuthService _auth = AuthService();
  final MembersService _members = MembersService();
  final PolesService _poles = PolesService();
  final ProjectsService _projects = ProjectsService();

  List<MeetingModel> _meetings = const [];
  List<MemberModel> _memberOptions = const [];
  List<PoleModel> _poleOptions = const [];
  List<ProjectModel> _projectOptions = const [];
  UserExperience? _user;
  bool _loading = true;
  String? _error;
  String _filter = 'active';

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
        _service.listMeetings(),
        _auth.getCachedCurrentUser(),
      ]);
      final cached = results[1];
      final user = cached is Map<String, dynamic>
          ? UserExperience.fromJson(cached)
          : null;
      UserExperience? resolvedUser = user;
      if (resolvedUser == null) {
        try {
          resolvedUser = UserExperience.fromJson(await _auth.getCurrentUser());
        } catch (_) {
          resolvedUser = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _meetings = results[0] as List<MeetingModel>;
        _user = resolvedUser;
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

  Future<void> _ensureReferences() async {
    if (_memberOptions.isNotEmpty ||
        _poleOptions.isNotEmpty ||
        _projectOptions.isNotEmpty) {
      return;
    }
    final values = await Future.wait<dynamic>([
      _members.getMembers(),
      if (_user?.isEnacchef == true)
        _poles.getPoles()
      else
        Future.value(<PoleModel>[]),
      if (_user?.isEnacchef == true)
        _projects.getProjects()
      else
        Future.value(<ProjectModel>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _memberOptions = values[0] as List<MemberModel>;
      _poleOptions = values[1] as List<PoleModel>;
      _projectOptions = values[2] as List<ProjectModel>;
    });
  }

  Future<void> _createMeeting() async {
    try {
      await _ensureReferences();
    } catch (error) {
      if (!mounted) return;
      _showError(_message(error));
      return;
    }
    if (!mounted) return;
    final created = await showModalBottomSheet<MeetingModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CreateMeetingSheet(
        service: _service,
        user: _user,
        members: _memberOptions,
        poles: _poleOptions,
        projects: _projectOptions,
      ),
    );
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    context.go('/meetings/${created.id}');
  }

  List<MeetingModel> get _visibleMeetings {
    final rows = _meetings.where((meeting) {
      if (_filter == 'past') return meeting.isClosed;
      if (_filter == 'all') return true;
      return !meeting.isClosed;
    }).toList();
    rows.sort((a, b) {
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      final aDate = a.scheduledStart ?? a.createdAt ?? DateTime(2100);
      final bDate = b.scheduledStart ?? b.createdAt ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _MeetHero(onCreate: _createMeeting),
          const SizedBox(height: 20),
          _FilterBar(
            selected: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _InlineError(message: _error!, onRetry: _load)
          else if (_visibleMeetings.isEmpty)
            const _EmptyMeetings()
          else
            for (final meeting in _visibleMeetings) ...[
              _MeetingCard(
                meeting: meeting,
                onOpen: () => context.go('/meetings/${meeting.id}'),
                onJoin: meeting.isClosed
                    ? null
                    : () => context.go(
                        '/meetings/${meeting.id}/live',
                        extra: meeting.title,
                      ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();
}

class _MeetHero extends StatelessWidget {
  final VoidCallback onCreate;

  const _MeetHero({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.softBlack, const Color(0xFF25313A)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_call_rounded, color: colors.secondary),
                  const SizedBox(width: 8),
                  const Text(
                    'ENACTMEET',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Un espace simple pour se retrouver et avancer ensemble.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Créez une réunion, invitez les bonnes personnes et retrouvez immédiatement les rendez-vous à venir.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          );
          final action = FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.secondary,
              foregroundColor: colors.onSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nouvelle réunion'),
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [copy, const SizedBox(height: 18), action],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 24),
                    action,
                  ],
                );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('En direct & à venir'),
          selected: selected == 'active',
          onSelected: (_) => onChanged('active'),
        ),
        ChoiceChip(
          label: const Text('Historique'),
          selected: selected == 'past',
          onSelected: (_) => onChanged('past'),
        ),
        ChoiceChip(
          label: const Text('Toutes'),
          selected: selected == 'all',
          onSelected: (_) => onChanged('all'),
        ),
      ],
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback onOpen;
  final VoidCallback? onJoin;

  const _MeetingCard({
    required this.meeting,
    required this.onOpen,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = meeting.isLive
        ? Colors.red.shade700
        : meeting.status == 'cancelled'
        ? colors.error
        : meeting.status == 'ended'
        ? colors.outline
        : colors.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.video_call_rounded, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meeting.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${meeting.scheduleLabel} · ${meeting.scopeLabel}',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      meeting.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (meeting.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  meeting.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Meta(
                    icon: Icons.group_rounded,
                    label: '${meeting.invitedCount} invités',
                  ),
                  _Meta(
                    icon: Icons.login_rounded,
                    label: '${meeting.joinedCount} ont rejoint',
                  ),
                  _Meta(
                    icon: meeting.lobbyEnabled
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    label: meeting.lobbyEnabled
                        ? 'Contrôle lobby'
                        : 'Lobby masqué',
                  ),
                  if (meeting.canManage)
                    const _Meta(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Hôte',
                    ),
                ],
              ),
              if (onJoin != null) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onJoin,
                    icon: const Icon(Icons.video_call_rounded),
                    label: Text(
                      meeting.isLive ? 'Rejoindre en direct' : 'Rejoindre',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Meta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMeetings extends StatelessWidget {
  const _EmptyMeetings();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          Icon(Icons.video_call_outlined, size: 56),
          SizedBox(height: 12),
          Text(
            'Aucune réunion dans cette vue.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Créez une réunion instantanée ou planifiez la prochaine séance.',
          ),
        ],
      ),
    );
  }
}

class _CreateMeetingSheet extends StatefulWidget {
  final MeetingsService service;
  final UserExperience? user;
  final List<MemberModel> members;
  final List<PoleModel> poles;
  final List<ProjectModel> projects;

  const _CreateMeetingSheet({
    required this.service,
    required this.user,
    required this.members,
    required this.poles,
    required this.projects,
  });

  @override
  State<_CreateMeetingSheet> createState() => _CreateMeetingSheetState();
}

class _CreateMeetingSheetState extends State<_CreateMeetingSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final Set<String> _selectedUsers = {};
  String _scopeType = 'custom';
  String? _scopeId;
  bool _scheduled = false;
  DateTime? _start;
  DateTime? _end;
  bool _audioMuted = true;
  bool _videoMuted = true;
  bool _lobby = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  List<(String, String)> get _scopeChoices {
    if (widget.user?.isEnacchef != true) {
      return const [('custom', 'Sur invitation')];
    }
    return const [
      ('custom', 'Sur invitation'),
      ('club', 'Tout le club'),
      ('pole', 'Un pôle'),
      ('project', 'Un projet'),
    ];
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Nouvelle réunion EnactMeet',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Titre de la réunion',
              prefixIcon: Icon(Icons.video_call_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description / ordre du jour',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _scopeType,
            decoration: const InputDecoration(
              labelText: 'Qui peut rejoindre ?',
              prefixIcon: Icon(Icons.groups_rounded),
            ),
            items: [
              for (final scope in _scopeChoices)
                DropdownMenuItem(value: scope.$1, child: Text(scope.$2)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _scopeType = value;
                _scopeId = null;
              });
            },
          ),
          if (_scopeType == 'pole') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _scopeId,
              decoration: const InputDecoration(labelText: 'Pôle concerné'),
              items: [
                for (final pole in widget.poles)
                  DropdownMenuItem(value: pole.id, child: Text(pole.name)),
              ],
              onChanged: (value) => setState(() => _scopeId = value),
            ),
          ],
          if (_scopeType == 'project') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _scopeId,
              decoration: const InputDecoration(labelText: 'Projet concerné'),
              items: [
                for (final project in widget.projects)
                  DropdownMenuItem(
                    value: project.id,
                    child: Text(project.name),
                  ),
              ],
              onChanged: (value) => setState(() => _scopeId = value),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickMembers,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(
              _selectedUsers.isEmpty
                  ? 'Inviter des membres'
                  : '${_selectedUsers.length} membre(s) invité(s)',
            ),
          ),
          if (_scopeType != 'custom')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Les membres de la portée choisie seront inclus automatiquement. Vous pouvez ajouter des invités en plus.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Planifier pour plus tard'),
            subtitle: const Text('Sinon la salle peut démarrer immédiatement.'),
            value: _scheduled,
            onChanged: (value) => setState(() {
              _scheduled = value;
              if (!value) {
                _start = null;
                _end = null;
              }
            }),
          ),
          if (_scheduled) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(start: true),
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      _start == null ? 'Début' : _formatDateTime(_start!),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(start: false),
                    icon: const Icon(Icons.event_busy_rounded),
                    label: Text(
                      _end == null ? 'Fin (optionnel)' : _formatDateTime(_end!),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Divider(),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Micro coupé au démarrage'),
            subtitle: const Text(
              'Chaque participant peut le réactiver ensuite.',
            ),
            value: _audioMuted,
            onChanged: (value) => setState(() => _audioMuted = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Caméra coupée au démarrage'),
            value: _videoMuted,
            onChanged: (value) => setState(() => _videoMuted = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Autoriser le contrôle lobby'),
            subtitle: const Text(
              'L’hôte peut activer la salle d’attente depuis les options de sécurité Jitsi.',
            ),
            value: _lobby,
            onChanged: (value) => setState(() => _lobby = value),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.video_call_rounded),
            label: Text(
              _scheduled ? 'Planifier la réunion' : 'Créer la réunion',
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _pickMembers() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _MemberPickerSheet(
        members: widget.members,
        selected: _selectedUsers,
        currentUserId: widget.user?.id,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedUsers
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _pickDateTime({required bool start}) async {
    final initial = start
        ? (_start ?? DateTime.now().add(const Duration(minutes: 30)))
        : (_end ??
              _start?.add(const Duration(hours: 1)) ??
              DateTime.now().add(const Duration(hours: 1)));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
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
        if (_end != null && !_end!.isAfter(value)) {
          _end = value.add(const Duration(hours: 1));
        }
      } else {
        _end = value;
      }
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.length < 2) {
      _error('Donnez un titre à la réunion.');
      return;
    }
    if ((_scopeType == 'pole' || _scopeType == 'project') && _scopeId == null) {
      _error('Sélectionnez la portée de la réunion.');
      return;
    }
    if (_scheduled && _start == null) {
      _error('Choisissez la date et l’heure de début.');
      return;
    }
    if (_end != null && _start != null && !_end!.isAfter(_start!)) {
      _error('La fin doit être postérieure au début.');
      return;
    }
    setState(() => _saving = true);
    try {
      final meeting = await widget.service.createMeeting(
        title: title,
        description: _description.text,
        scopeType: _scopeType,
        scopeId: _scopeId,
        scheduledStart: _scheduled ? _start : null,
        scheduledEnd: _scheduled ? _end : null,
        inviteUserIds: _selectedUsers.toList(),
        startWithAudioMuted: _audioMuted,
        startWithVideoMuted: _videoMuted,
        lobbyEnabled: _lobby,
      );
      if (!mounted) return;
      Navigator.pop(context, meeting);
    } catch (error) {
      if (!mounted) return;
      _error(error.toString().replaceFirst('Exception: ', '').trim());
      setState(() => _saving = false);
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month ${value.year} · $hour:$minute';
  }
}

class _MemberPickerSheet extends StatefulWidget {
  final List<MemberModel> members;
  final Set<String> selected;
  final String? currentUserId;

  const _MemberPickerSheet({
    required this.members,
    required this.selected,
    required this.currentUserId,
  });

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  late final Set<String> _selected = {...widget.selected};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MemberModel> get _visible {
    final query = _search.text.trim().toLowerCase();
    return widget.members.where((member) {
      if (member.id == widget.currentUserId) return false;
      if (query.isEmpty) return true;
      return member.displayName.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query) ||
          member.primaryRoleLabel.toLowerCase().contains(query);
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
              Expanded(
                child: Text(
                  'Inviter des membres · ${_selected.length}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: const Text('Valider'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Rechercher un membre…',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _visible.isEmpty
                ? const Center(child: Text('Aucun membre trouvé.'))
                : ListView.builder(
                    itemCount: _visible.length,
                    itemBuilder: (context, index) {
                      final member = _visible[index];
                      final checked = _selected.contains(member.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected.add(member.id);
                          } else {
                            _selected.remove(member.id);
                          }
                        }),
                        secondary: CircleAvatar(
                          child: Text(
                            member.displayName.isEmpty
                                ? '?'
                                : member.displayName.characters.first
                                      .toUpperCase(),
                          ),
                        ),
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
