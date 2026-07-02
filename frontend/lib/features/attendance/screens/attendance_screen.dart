import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../models/attendance_record_model.dart';
import '../models/attendance_session_model.dart';
import '../services/attendance_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import 'attendance_session_detail_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AuthService _authService = AuthService();
  final AttendanceService _attendanceService = AttendanceService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  UserExperience? _user;
  List<AttendanceSessionModel> _sessions = [];
  List<AttendanceRecordModel> _myRecords = [];
  Map<String, dynamic>? _stats;
  String _view = 'personal';
  bool _viewInitialized = false;
  String _statusFilter = 'all';
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _authService.getCurrentUser(),
        _attendanceService.getSessions(),
        _attendanceService.getMyRecords(),
      ]);

      if (!mounted) return;

      final user = UserExperience.fromJson(results[0] as Map<String, dynamic>);
      Map<String, dynamic>? stats;
      if (user.canManageAttendance) {
        try {
          stats = await _attendanceService.getStats();
        } catch (_) {
          stats = null;
        }
      }

      setState(() {
        _user = user;
        _sessions = results[1] as List<AttendanceSessionModel>;
        _myRecords = results[2] as List<AttendanceRecordModel>;
        _stats = stats;
        if (!_viewInitialized) {
          _view = user.canManageAttendance ? 'management' : 'personal';
          _viewInitialized = true;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCreateSessionDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CreateAttendanceSessionDialog(
          attendanceService: _attendanceService,
        );
      },
    );

    if (created == true) {
      await _loadSessions();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session de présence créée avec succès.')),
      );
    }
  }

  Future<void> _submitJustification(AttendanceRecordModel record) async {
    final controller = TextEditingController(
      text: record.justificationReason ?? record.justification ?? '',
    );
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Justifier l absence'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Motif',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (reason == null || reason.trim().isEmpty) return;

    try {
      await _attendanceService.submitJustification(
        recordId: record.id,
        reason: reason,
      );
      await _loadSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Justification envoyee.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  int get _openCount {
    return _sessions.where((s) => s.status == 'open').length;
  }

  int get _closedCount {
    return _sessions.where((s) => s.status == 'closed').length;
  }

  int get _scheduledSoonCount {
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 7));

    return _sessions.where((session) {
      final date = _sessionDate(session);
      if (date == null) return false;
      return date.isAfter(now.subtract(const Duration(hours: 2))) &&
          date.isBefore(limit);
    }).length;
  }

  List<AttendanceSessionModel> get _filteredSessions {
    final query = _searchController.text.trim().toLowerCase();

    return _sessions.where((session) {
      final matchesQuery =
          query.isEmpty ||
          session.title.toLowerCase().contains(query) ||
          (session.description ?? '').toLowerCase().contains(query) ||
          session.typeLabel.toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == 'all' || session.status == _statusFilter;
      final matchesType =
          _typeFilter == 'all' || session.sessionType == _typeFilter;

      return matchesQuery && matchesStatus && matchesType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _user?.canManageAttendance == true;

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 560 ? 14 : 24,
        ),
        children: [
          if (canManage) ...[
            _AttendanceViewSwitch(
              value: _view,
              onChanged: (value) => setState(() => _view = value),
            ),
            const SizedBox(height: 18),
          ],
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _loadSessions)
          else if (_view == 'personal')
            _PersonalAttendanceView(
              records: _myRecords,
              sessions: _sessions,
              onRefresh: _loadSessions,
              onSubmitJustification: _submitJustification,
            )
          else
            ..._buildManagementView(),
        ],
      ),
    );
  }

  List<Widget> _buildManagementView() {
    return [
      _AttendanceHeader(
        total: _sessions.length,
        open: _openCount,
        closed: _closedCount,
        scheduledSoon: _scheduledSoonCount,
        onRefresh: _loadSessions,
        onCreate: _openCreateSessionDialog,
      ),
      const SizedBox(height: 22),
      if (_stats != null) ...[
        _AttendanceStatsOverview(stats: _stats!),
        const SizedBox(height: 18),
      ],
      _AttendanceFiltersCard(
        controller: _searchController,
        statusFilter: _statusFilter,
        typeFilter: _typeFilter,
        onChanged: () => setState(() {}),
        onStatusChanged: (value) => setState(() => _statusFilter = value),
        onTypeChanged: (value) => setState(() => _typeFilter = value),
      ),
      const SizedBox(height: 18),
      if (_sessions.isEmpty)
        const _EmptySessionsCard()
      else if (_filteredSessions.isEmpty)
        const _NoSessionMatchCard()
      else
        _SessionsList(sessions: _filteredSessions),
    ];
  }
}

class _AttendanceViewSwitch extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _AttendanceViewSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'management',
            icon: Icon(Icons.groups_rounded),
            label: Text('Gestion'),
          ),
          ButtonSegment(
            value: 'personal',
            icon: Icon(Icons.person_rounded),
            label: Text('Mon suivi'),
          ),
        ],
        selected: {value},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }
}

class _AttendanceStatsOverview extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _AttendanceStatsOverview({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _OverviewItem(
        label: 'Seances',
        value: _value('sessions_count'),
        icon: Icons.event_available_rounded,
      ),
      _OverviewItem(
        label: 'Presents',
        value: _value('present'),
        icon: Icons.check_circle_rounded,
      ),
      _OverviewItem(
        label: 'Retards',
        value: _value('late'),
        icon: Icons.schedule_rounded,
      ),
      _OverviewItem(
        label: 'Absences',
        value: _value('unjustified_absences'),
        icon: Icons.warning_rounded,
      ),
      _OverviewItem(
        label: 'Taux',
        value: '${_value('attendance_rate')}%',
        icon: Icons.insights_rounded,
      ),
      _OverviewItem(
        label: 'Sanctions',
        value: '${_value('sanctions_potential')} FCFA',
        icon: Icons.payments_rounded,
      ),
    ];
    final watch = stats['members_to_watch'];
    final watchCount = watch is List ? watch.length : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.analytics_rounded),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Statistiques du mois',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final count = width >= 980
                    ? 6
                    : width >= 720
                    ? 3
                    : width >= 460
                    ? 2
                    : 1;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.4,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            if (watchCount > 0) ...[
              const SizedBox(height: 12),
              Chip(
                avatar: const Icon(Icons.visibility_rounded, size: 16),
                label: Text('$watchCount membre(s) a surveiller'),
                backgroundColor: Colors.orange.shade50,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _value(String key) {
    final value = stats[key];
    if (value is num) {
      return value % 1 == 0 ? value.toInt().toString() : value.toString();
    }
    return value?.toString() ?? '0';
  }
}

class _OverviewItem {
  final String label;
  final String value;
  final IconData icon;

  const _OverviewItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _PersonalAttendanceView extends StatelessWidget {
  final List<AttendanceRecordModel> records;
  final List<AttendanceSessionModel> sessions;
  final VoidCallback onRefresh;
  final ValueChanged<AttendanceRecordModel> onSubmitJustification;

  const _PersonalAttendanceView({
    required this.records,
    required this.sessions,
    required this.onRefresh,
    required this.onSubmitJustification,
  });

  @override
  Widget build(BuildContext context) {
    final present = records.where((record) => record.isPresent).length;
    final late = records.where((record) => record.isLate).length;
    final justified = records.where(_isJustifiedAbsence).length;
    final absent = records.where(_isUnjustifiedAbsence).length;
    final attended = present + late;
    final rate = records.isEmpty
        ? 0
        : ((attended / records.length) * 100).round();
    final sessionsById = {for (final session in sessions) session.id: session};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.softBlack,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppTheme.enactusYellow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      color: AppTheme.softBlack,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mon suivi de présence',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mes présences, retards et absences uniquement.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    tooltip: 'Actualiser',
                    color: Colors.white,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PersonalMetric(label: 'Assiduité', value: '$rate%'),
                  _PersonalMetric(label: 'Présences', value: '$present'),
                  _PersonalMetric(label: 'Retards', value: '$late'),
                  _PersonalMetric(label: 'Justifiées', value: '$justified'),
                  _PersonalMetric(label: 'Absences', value: '$absent'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Mon historique',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        if (records.isEmpty)
          const _EmptyPersonalAttendance()
        else
          ...records.map((record) {
            final session = sessionsById[record.sessionId];
            return _PersonalAttendanceTile(
              record: record,
              session: session,
              onSubmitJustification: onSubmitJustification,
            );
          }),
      ],
    );
  }
}

class _PersonalMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PersonalMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.enactusYellow,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _PersonalAttendanceTile extends StatelessWidget {
  final AttendanceRecordModel record;
  final AttendanceSessionModel? session;
  final ValueChanged<AttendanceRecordModel> onSubmitJustification;

  const _PersonalAttendanceTile({
    required this.record,
    required this.session,
    required this.onSubmitJustification,
  });

  @override
  Widget build(BuildContext context) {
    final color = _attendanceStatusColor(record.status);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session?.title ?? 'Session de présence',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 5),
        Text(
          session?.dateLabel ?? _recordDateLabel(record),
          style: const TextStyle(color: Colors.black54),
        ),
        if (record.justification?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            record.justification!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
    final status = Chip(
      label: Text(record.statusLabel),
      backgroundColor: color.withAlpha(24),
      side: BorderSide(color: color.withAlpha(70)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
    final canJustify =
        record.isAbsent &&
        record.justificationStatus != 'pending' &&
        record.justificationStatus != 'approved';
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        status,
        if (record.justificationStatus == 'pending')
          const Chip(label: Text('Justification en attente')),
        if (record.justificationStatus == 'rejected')
          const Chip(label: Text('Justification refusee')),
        if (canJustify)
          OutlinedButton.icon(
            onPressed: () => onSubmitJustification(record),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Justifier'),
          ),
      ],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final avatar = CircleAvatar(
              backgroundColor: color.withAlpha(28),
              foregroundColor: color,
              child: Icon(_attendanceStatusIcon(record.status)),
            );

            if (constraints.maxWidth >= 520) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(width: 14),
                  Expanded(child: details),
                  const SizedBox(width: 10),
                  Flexible(child: actions),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(width: 14),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: actions),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyPersonalAttendance extends StatelessWidget {
  const _EmptyPersonalAttendance();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_available_rounded, size: 42),
              SizedBox(height: 10),
              Text(
                'Aucun pointage enregistré pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isJustifiedAbsence(AttendanceRecordModel record) {
  return record.isJustifiedAbsence || record.isExcused;
}

bool _isUnjustifiedAbsence(AttendanceRecordModel record) {
  return record.isAbsent;
}

Color _attendanceStatusColor(String status) {
  if (status == 'present') return Colors.green.shade700;
  if (status == 'late') return Colors.orange.shade800;
  if (_isJustifiedStatus(status)) return Colors.blue.shade700;
  return Colors.red.shade700;
}

IconData _attendanceStatusIcon(String status) {
  if (status == 'present') return Icons.check_rounded;
  if (status == 'late') return Icons.schedule_rounded;
  if (_isJustifiedStatus(status)) return Icons.verified_rounded;
  return Icons.close_rounded;
}

bool _isJustifiedStatus(String status) {
  return status == 'justified_absence' || status == 'excused';
}

String _recordDateLabel(AttendanceRecordModel record) {
  final date = DateTime.tryParse(
    record.arrivalTime ?? record.checkinTime ?? '',
  );
  if (date == null) return 'Date non disponible';

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} à $hour:$minute';
}

class _AttendanceHeader extends StatelessWidget {
  final int total;
  final int open;
  final int closed;
  final int scheduledSoon;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  const _AttendanceHeader({
    required this.total,
    required this.open,
    required this.closed,
    required this.scheduledSoon,
    required this.onRefresh,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
        ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Créer session'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: isWide
          ? Row(
              children: [
                const _HeaderIcon(),
                const SizedBox(width: 18),
                Expanded(
                  child: _HeaderText(
                    total: total,
                    open: open,
                    closed: closed,
                    scheduledSoon: scheduledSoon,
                  ),
                ),
                actions,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _HeaderIcon(),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _HeaderText(
                        total: total,
                        open: open,
                        closed: closed,
                        scheduledSoon: scheduledSoon,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                actions,
              ],
            ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.fact_check_rounded,
        color: AppTheme.softBlack,
        size: 34,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final int total;
  final int open;
  final int closed;
  final int scheduledSoon;

  const _HeaderText({
    required this.total,
    required this.open,
    required this.closed,
    required this.scheduledSoon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Présences',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$total session(s) • $open ouverte(s) • $closed clôturée(s) • $scheduledSoon à venir',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }
}

class _AttendanceFiltersCard extends StatelessWidget {
  final TextEditingController controller;
  final String statusFilter;
  final String typeFilter;
  final VoidCallback onChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onTypeChanged;

  const _AttendanceFiltersCard({
    required this.controller,
    required this.statusFilter,
    required this.typeFilter,
    required this.onChanged,
    required this.onStatusChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final search = TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Rechercher une session',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            );
            final filters = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FilterChoice(
                  label: 'Toutes',
                  selected: statusFilter == 'all',
                  onSelected: () => onStatusChanged('all'),
                ),
                _FilterChoice(
                  label: 'Ouvertes',
                  selected: statusFilter == 'open',
                  onSelected: () => onStatusChanged('open'),
                ),
                _FilterChoice(
                  label: 'Clôturées',
                  selected: statusFilter == 'closed',
                  onSelected: () => onStatusChanged('closed'),
                ),
                _FilterChoice(
                  label: 'Planifiées',
                  selected: statusFilter == 'scheduled',
                  onSelected: () => onStatusChanged('scheduled'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Filtrer par type',
                  onSelected: onTypeChanged,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'all', child: Text('Tous les types')),
                    PopupMenuItem(
                      value: 'general_meeting',
                      child: Text('Réunions générales'),
                    ),
                    PopupMenuItem(
                      value: 'pole_meeting',
                      child: Text('Réunions pôle'),
                    ),
                    PopupMenuItem(
                      value: 'project_meeting',
                      child: Text('Réunions projet'),
                    ),
                    PopupMenuItem(value: 'training', child: Text('Formations')),
                    PopupMenuItem(value: 'activity', child: Text('Activités')),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(_typeFilterLabel(typeFilter)),
                  ),
                ),
              ],
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 14),
                  Flexible(child: filters),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [search, const SizedBox(height: 12), filters],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.enactusYellow.withAlpha(120),
    );
  }
}

class _SessionsList extends StatelessWidget {
  final List<AttendanceSessionModel> sessions;

  const _SessionsList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sessions.map((session) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AttendanceSessionDetailScreen(session: session),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  final leading = CircleAvatar(
                    backgroundColor: _sessionStatusColor(session).withAlpha(35),
                    foregroundColor: AppTheme.softBlack,
                    child: Icon(_sessionTypeIcon(session.sessionType)),
                  );
                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        session.description ?? 'Aucune description',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            label: session.typeLabel,
                            icon: Icons.category_rounded,
                          ),
                          _InfoChip(
                            label: session.statusLabel,
                            icon: Icons.circle_rounded,
                            color: _sessionStatusColor(session),
                          ),
                          _InfoChip(
                            label: session.dateLabel,
                            icon: Icons.schedule_rounded,
                          ),
                          _InfoChip(
                            label: _sessionReadinessLabel(session),
                            icon: Icons.insights_rounded,
                          ),
                        ],
                      ),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      children: [
                        leading,
                        const SizedBox(width: 14),
                        Expanded(child: content),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          leading,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              session.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
                      const SizedBox(height: 12),
                      content,
                    ],
                  );
                },
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _InfoChip({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      backgroundColor: color?.withAlpha(24),
      side: color == null ? null : BorderSide(color: color!.withAlpha(80)),
    );
  }
}

class CreateAttendanceSessionDialog extends StatefulWidget {
  final AttendanceService attendanceService;

  const CreateAttendanceSessionDialog({
    super.key,
    required this.attendanceService,
  });

  @override
  State<CreateAttendanceSessionDialog> createState() =>
      _CreateAttendanceSessionDialogState();
}

class _CreateAttendanceSessionDialogState
    extends State<CreateAttendanceSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final PolesService _polesService = PolesService();
  final ProjectsService _projectsService = ProjectsService();

  final _titleController = TextEditingController(text: 'Réunion générale');
  final _descriptionController = TextEditingController(
    text: 'Session de présence pour réunion générale.',
  );

  String _sessionType = 'general_meeting';
  String _scopeType = 'club';
  String? _selectedPoleId;
  String? _selectedProjectId;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 15, minute: 0);

  bool _loading = false;
  bool _loadingScopes = true;
  String? _error;
  List<PoleModel> _poles = [];
  List<ProjectModel> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadScopes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadScopes() async {
    try {
      final results = await Future.wait([
        _polesService.getPoles(),
        _projectsService.getProjects(),
      ]);
      if (!mounted) return;
      setState(() {
        _poles = results[0] as List<PoleModel>;
        _projects = results[1] as List<ProjectModel>;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _poles = [];
        _projects = [];
      });
    } finally {
      if (mounted) setState(() => _loadingScopes = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (selected == null) return;

    setState(() {
      _scheduledAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );

    if (selected == null) return;

    setState(() {
      _scheduledTime = selected;
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scopeType == 'pole' && _selectedPoleId == null) {
      setState(() => _error = 'Choisis le pole concerne.');
      return;
    }
    if (_scopeType == 'project' && _selectedProjectId == null) {
      setState(() => _error = 'Choisis le projet concerne.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.attendanceService.createSession(
        title: _titleController.text,
        description: _descriptionController.text,
        sessionType: _sessionType,
        scopeType: _scopeType,
        scheduledAt: _scheduledAt,
        poleId: _scopeType == 'pole' ? _selectedPoleId : null,
        projectId: _scopeType == 'project' ? _selectedProjectId : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String get _datePreview {
    final d = _scheduledAt;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');

    return '$day/$month/$year à $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Créer une session'),
      content: SizedBox(
        width: _dialogWidth(context, 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le titre est obligatoire.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _sessionType,
                  decoration: const InputDecoration(
                    labelText: 'Type de session',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'general_meeting',
                      child: Text('Réunion générale'),
                    ),
                    DropdownMenuItem(
                      value: 'pole_meeting',
                      child: Text('Réunion pôle'),
                    ),
                    DropdownMenuItem(
                      value: 'project_meeting',
                      child: Text('Réunion projet'),
                    ),
                    DropdownMenuItem(
                      value: 'training',
                      child: Text('Formation'),
                    ),
                    DropdownMenuItem(
                      value: 'activity',
                      child: Text('Activité'),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _sessionType = value;
                          });
                        },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _scopeType,
                  decoration: const InputDecoration(
                    labelText: 'Perimetre',
                    prefixIcon: Icon(Icons.groups_2_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'club',
                      child: Text('Tout le club'),
                    ),
                    DropdownMenuItem(value: 'pole', child: Text('Pole')),
                    DropdownMenuItem(value: 'project', child: Text('Projet')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _scopeType = value;
                            if (value == 'club') {
                              _sessionType = 'general_meeting';
                              _selectedPoleId = null;
                              _selectedProjectId = null;
                            } else if (value == 'pole') {
                              _sessionType = 'pole_meeting';
                              _selectedProjectId = null;
                            } else if (value == 'project') {
                              _sessionType = 'project_meeting';
                              _selectedPoleId = null;
                            }
                          });
                        },
                ),
                if (_scopeType == 'pole') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPoleId,
                    decoration: InputDecoration(
                      labelText: _loadingScopes
                          ? 'Chargement des poles...'
                          : 'Pole concerne',
                      prefixIcon: const Icon(Icons.hub_rounded),
                    ),
                    items: _poles
                        .map(
                          (pole) => DropdownMenuItem(
                            value: pole.id,
                            child: Text(
                              pole.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (value) => setState(() => _selectedPoleId = value),
                  ),
                ],
                if (_scopeType == 'project') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProjectId,
                    decoration: InputDecoration(
                      labelText: _loadingScopes
                          ? 'Chargement des projets...'
                          : 'Projet concerne',
                      prefixIcon: const Icon(Icons.rocket_launch_rounded),
                    ),
                    items: _projects
                        .map(
                          (project) => DropdownMenuItem(
                            value: project.id,
                            child: Text(
                              project.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (value) => setState(() => _selectedProjectId = value),
                  ),
                ],
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(Icons.schedule_rounded),
                        Text(
                          _datePreview,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _pickDate,
                          child: const Text('Date'),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _pickTime,
                          child: const Text('Heure'),
                        ),
                      ],
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
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_rounded),
          label: Text(_loading ? 'Création...' : 'Créer'),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

double _dialogWidth(BuildContext context, double maxWidth) {
  return (MediaQuery.sizeOf(context).width - 32).clamp(280.0, maxWidth);
}

class _EmptySessionsCard extends StatelessWidget {
  const _EmptySessionsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(26),
        child: Center(
          child: Text(
            'Aucune session de présence trouvée.',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoSessionMatchCard extends StatelessWidget {
  const _NoSessionMatchCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(26),
        child: Center(
          child: Text(
            'Aucune session ne correspond aux filtres.',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

String _typeFilterLabel(String value) {
  switch (value) {
    case 'general_meeting':
      return 'Réunions générales';
    case 'pole_meeting':
      return 'Réunions pôle';
    case 'project_meeting':
      return 'Réunions projet';
    case 'training':
      return 'Formations';
    case 'activity':
      return 'Activités';
    default:
      return 'Tous les types';
  }
}

IconData _sessionTypeIcon(String? type) {
  switch (type) {
    case 'training':
      return Icons.school_rounded;
    case 'activity':
      return Icons.volunteer_activism_rounded;
    case 'pole_meeting':
      return Icons.hub_rounded;
    case 'project_meeting':
      return Icons.rocket_launch_rounded;
    default:
      return Icons.event_available_rounded;
  }
}

Color _sessionStatusColor(AttendanceSessionModel session) {
  switch (session.status) {
    case 'open':
      return Colors.green.shade700;
    case 'closed':
      return Colors.blueGrey.shade600;
    case 'scheduled':
      return Colors.orange.shade700;
    default:
      return Colors.black45;
  }
}

String _sessionReadinessLabel(AttendanceSessionModel session) {
  final date = _sessionDate(session);
  if (session.status == 'closed') return 'Rapport prêt';
  if (session.status == 'open') return 'Pointage actif';
  if (date == null) return 'À planifier';

  final hours = date.difference(DateTime.now()).inHours;
  if (hours < 0) return 'En retard';
  if (hours <= 24) return 'Aujourd’hui';
  if (hours <= 168) return 'Cette semaine';
  return 'À venir';
}

DateTime? _sessionDate(AttendanceSessionModel session) {
  final raw = session.scheduledAt ?? session.startTime;
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
