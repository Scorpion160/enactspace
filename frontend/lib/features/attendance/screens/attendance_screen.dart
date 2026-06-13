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

  bool _loading = true;
  String? _error;
  List<AttendanceSessionModel> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
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
            onRefresh: _loadSessions,
            onCreate: _openCreateSessionDialog,
          ),
          const SizedBox(height: 22),
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
          else
            _SessionsList(sessions: _sessions),
        ],
      ),
    );
  }
}

class _AttendanceHeader extends StatelessWidget {
  final int total;
  final int open;
  final int closed;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  const _AttendanceHeader({
    required this.total,
    required this.open,
    required this.closed,
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
                _HeaderIcon(),
                const SizedBox(width: 18),
                Expanded(
                  child: _HeaderText(total: total, open: open, closed: closed),
                ),
                actions,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderIcon(),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _HeaderText(
                        total: total,
                        open: open,
                        closed: closed,
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

  const _HeaderText({
    required this.total,
    required this.open,
    required this.closed,
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
          '$total session(s) • $open ouverte(s) • $closed clôturée(s)',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
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
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.enactusYellow,
                  foregroundColor: AppTheme.softBlack,
                  child: const Icon(Icons.event_available_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
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
                          ),
                          _InfoChip(
                            label: session.dateLabel,
                            icon: Icons.schedule_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AttendanceSessionDetailScreen(session: session),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: 'Ouvrir',
                ),
              ],
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

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
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
      title: const Text('Créer une session'),
      content: SizedBox(
        width: 520,
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
                  value: _sessionType,
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
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _datePreview,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
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
