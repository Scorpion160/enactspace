import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/attendance_session_model.dart';
import '../services/attendance_service.dart';
import 'attendance_session_detail_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<AttendanceSessionModel> _sessions = [];
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
      final sessions = await _attendanceService.getSessions();

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
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
    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _AttendanceHeader(
            total: _sessions.length,
            open: _openCount,
            closed: _closedCount,
            scheduledSoon: _scheduledSoonCount,
            onRefresh: _loadSessions,
            onCreate: _openCreateSessionDialog,
          ),
          const SizedBox(height: 22),
          _AttendanceFiltersCard(
            controller: _searchController,
            statusFilter: _statusFilter,
            typeFilter: _typeFilter,
            onChanged: () => setState(() {}),
            onStatusChanged: (value) {
              setState(() {
                _statusFilter = value;
              });
            },
            onTypeChanged: (value) {
              setState(() {
                _typeFilter = value;
              });
            },
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _loadSessions)
          else if (_sessions.isEmpty)
            const _EmptySessionsCard()
          else if (_filteredSessions.isEmpty)
            const _NoSessionMatchCard()
          else
            _SessionsList(sessions: _filteredSessions),
        ],
      ),
    );
  }
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

  final _titleController = TextEditingController(text: 'Réunion générale');
  final _descriptionController = TextEditingController(
    text: 'Session de présence pour réunion générale.',
  );

  String _sessionType = 'general_meeting';
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 15, minute: 0);

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.attendanceService.createSession(
        title: _titleController.text,
        description: _descriptionController.text,
        sessionType: _sessionType,
        scheduledAt: _scheduledAt,
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
