import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../models/attendance_expected_member_model.dart';
import '../models/attendance_record_model.dart';
import '../models/attendance_session_model.dart';
import '../services/attendance_service.dart';

class AttendanceSessionDetailScreen extends StatefulWidget {
  final AttendanceSessionModel session;

  const AttendanceSessionDetailScreen({super.key, required this.session});

  @override
  State<AttendanceSessionDetailScreen> createState() =>
      _AttendanceSessionDetailScreenState();
}

class _AttendanceSessionDetailScreenState
    extends State<AttendanceSessionDetailScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MembersService _membersService = MembersService();
  final TextEditingController _memberSearchController = TextEditingController();

  bool _loading = true;
  late bool _sessionClosed;
  late String _sessionStatus;
  String? _error;
  String _statusFilter = 'all';

  List<MemberModel> _members = [];
  List<AttendanceExpectedMemberModel> _expectedMembers = [];
  List<AttendanceRecordModel> _records = [];

  @override
  void initState() {
    super.initState();
    _sessionClosed = widget.session.status == 'closed';
    _sessionStatus = widget.session.status ?? 'draft';
    _loadDetails();
  }

  @override
  void dispose() {
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _membersService.getMembers(),
        _attendanceService.getExpectedMembers(widget.session.id),
        _attendanceService.getRecordsBySession(widget.session.id),
      ]);

      if (!mounted) return;

      setState(() {
        _members = results[0] as List<MemberModel>;
        _expectedMembers = results[1] as List<AttendanceExpectedMemberModel>;
        _records = results[2] as List<AttendanceRecordModel>;
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

  Set<String> get _expectedUserIds {
    return _expectedMembers.map((e) => e.userId).toSet();
  }

  Map<String, AttendanceRecordModel> get _recordByUserId {
    return {for (final record in _records) record.userId: record};
  }

  Future<void> _addExpectedMember(MemberModel member) async {
    try {
      await _attendanceService.addExpectedMember(
        sessionId: widget.session.id,
        userId: member.id,
      );

      await _loadDetails();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.displayName} ajouté aux attendus.')),
      );
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

  Future<void> _markAttendance({
    required MemberModel member,
    required String status,
  }) async {
    String? justification;

    if (status == 'excused' || status == 'justified_absence') {
      justification = await _askJustification(status: status);
      if (justification == null || justification.trim().isEmpty) {
        return;
      }
    }

    try {
      await _attendanceService.createManualAttendance(
        sessionId: widget.session.id,
        userId: member.id,
        status: status,
        justification: justification,
        justificationStatus: status == 'excused' ? 'approved' : null,
      );

      await _loadDetails();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Présence enregistrée pour ${member.displayName}.'),
        ),
      );
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

  Future<String?> _askJustification({required String status}) async {
    final controller = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Justification'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: status == 'excused'
                  ? 'Motif de l excuse'
                  : 'Commentaire optionnel',
              prefixIcon: const Icon(Icons.edit_note_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _closeSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clôturer la session'),
          content: const Text(
            'Voulez-vous clôturer cette session ?\n\n'
            'Tous les membres attendus qui n’ont pas encore été saisis seront marqués comme absents non justifiés.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Clôturer'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _attendanceService.closeSession(widget.session.id);
      await _loadDetails();

      if (!mounted) return;
      setState(() {
        _sessionClosed = true;
        _sessionStatus = 'closed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session clôturée avec succès.')),
      );
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

  Future<void> _openSession() async {
    try {
      final opened = await _attendanceService.openSession(widget.session.id);
      await _loadDetails();

      if (!mounted) return;
      setState(() {
        _sessionClosed = false;
        _sessionStatus = opened.status ?? 'open';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appel ouvert avec succes.')),
      );
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

  @override
  Widget build(BuildContext context) {
    final expectedIds = _expectedUserIds;
    final recordByUserId = _recordByUserId;

    final expectedMembers = _members
        .where((member) => expectedIds.contains(member.id))
        .toList();
    final filteredExpectedMembers = _filterExpectedMembers(
      expectedMembers,
      recordByUserId,
    );

    final availableMembers = _members
        .where((member) => !expectedIds.contains(member.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.session.title)),
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        child: ListView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 560 ? 14 : 24,
          ),
          children: [
            _SessionHeader(
              session: widget.session,
              isClosed: _sessionClosed,
              status: _sessionStatus,
              onOpen: _openSession,
              onClose: _closeSession,
            ),
            const SizedBox(height: 20),
            _AttendanceStatsCard(
              totalExpected: _expectedMembers.length,
              present: _presentCount,
              late: _lateCount,
              justifiedAbsence: _justifiedAbsenceCount,
              unjustifiedAbsence: _unjustifiedAbsenceCount,
              notFilled: _notFilledCount,
              totalPenaltyAmount: _totalPenaltyAmount,
            ),
            const SizedBox(height: 20),
            _SessionActionPanel(
              session: widget.session,
              expectedCount: _expectedMembers.length,
              recordedCount: _records.length,
              completionRate: _completionRate,
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _loadDetails)
            else ...[
              _AddExpectedMemberCard(
                availableMembers: availableMembers,
                onAdd: _addExpectedMember,
              ),
              const SizedBox(height: 18),
              _AttendanceMemberFiltersCard(
                controller: _memberSearchController,
                statusFilter: _statusFilter,
                onChanged: () => setState(() {}),
                onStatusChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                },
              ),
              const SizedBox(height: 18),
              _ExpectedMembersCard(
                members: filteredExpectedMembers,
                recordByUserId: recordByUserId,
                onMarkAttendance: _markAttendance,
                sessionClosed: _sessionClosed,
              ),
            ],
          ],
        ),
      ),
    );
  }

  int get _presentCount {
    return _records.where((r) => r.status == 'present').length;
  }

  int get _lateCount {
    return _records.where((r) => r.isLate).length;
  }

  int get _justifiedAbsenceCount {
    return _records.where((r) => r.isJustifiedAbsence || r.isExcused).length;
  }

  int get _unjustifiedAbsenceCount {
    return _records.where((r) => r.isAbsent).length;
  }

  int get _notFilledCount {
    return _expectedMembers.length - _records.length;
  }

  int get _totalPenaltyAmount {
    return _records.fold<int>(
      0,
      (sum, record) => sum + (record.penaltyAmount ?? 0),
    );
  }

  double get _completionRate {
    if (_expectedMembers.isEmpty) return 0;
    return (_records.length / _expectedMembers.length).clamp(0.0, 1.0);
  }

  List<MemberModel> _filterExpectedMembers(
    List<MemberModel> members,
    Map<String, AttendanceRecordModel> recordByUserId,
  ) {
    final query = _memberSearchController.text.trim().toLowerCase();

    return members.where((member) {
      final record = recordByUserId[member.id];
      final matchesQuery =
          query.isEmpty ||
          member.displayName.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query) ||
          member.rolesLabel.toLowerCase().contains(query) ||
          member.departmentLabel.toLowerCase().contains(query);

      final matchesStatus = switch (_statusFilter) {
        'all' => true,
        'not_filled' => record == null,
        'present' => record?.status == 'present',
        'late' => record?.isLate == true,
        'justified' =>
          record?.isJustifiedAbsence == true || record?.isExcused == true,
        'unjustified' => record?.isAbsent == true,
        _ => true,
      };

      return matchesQuery && matchesStatus;
    }).toList();
  }
}

class _SessionHeader extends StatelessWidget {
  final AttendanceSessionModel session;
  final bool isClosed;
  final String status;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const _SessionHeader({
    required this.session,
    required this.isClosed,
    required this.status,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 560 ? 18 : 26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 640;
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${session.typeLabel} • ${isClosed ? 'Clôturée' : session.statusLabel} • ${session.dateLabel}',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final closeButton = ElevatedButton.icon(
            onPressed: isClosed ? null : onClose,
            icon: const Icon(Icons.lock_rounded),
            label: Text(isClosed ? 'Clôturée' : 'Clôturer'),
          );

          final actionButtons = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: isClosed || status == 'open' ? null : onOpen,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Ouvrir'),
              ),
              closeButton,
            ],
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                actionButtons,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerRight, child: actionButtons),
            ],
          );
        },
      ),
    );
  }
}

class _SessionActionPanel extends StatelessWidget {
  final AttendanceSessionModel session;
  final int expectedCount;
  final int recordedCount;
  final double completionRate;

  const _SessionActionPanel({
    required this.session,
    required this.expectedCount,
    required this.recordedCount,
    required this.completionRate,
  });

  @override
  Widget build(BuildContext context) {
    final missing = (expectedCount - recordedCount).clamp(0, expectedCount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;
            final progress = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pilotage de la session',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${(completionRate * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: completionRate,
                    minHeight: 10,
                    color: AppTheme.enactusYellow,
                    backgroundColor: Colors.black12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$recordedCount/$expectedCount saisie(s) • $missing membre(s) à traiter',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ActionChip(
                  icon: Icons.qr_code_2_rounded,
                  label: session.qrToken == null || session.qrToken!.isEmpty
                      ? 'QR à générer'
                      : 'QR disponible',
                ),
                const _ActionChip(
                  icon: Icons.notifications_active_rounded,
                  label: 'Relancer absents',
                ),
                const _ActionChip(
                  icon: Icons.ios_share_rounded,
                  label: 'Exporter rapport',
                ),
                const _ActionChip(
                  icon: Icons.privacy_tip_rounded,
                  label: 'Visibilité SG',
                ),
              ],
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: progress),
                  const SizedBox(width: 18),
                  Flexible(child: actions),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [progress, const SizedBox(height: 16), actions],
            );
          },
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: AppTheme.enactusYellow.withAlpha(40),
      side: BorderSide(color: AppTheme.enactusYellow.withAlpha(120)),
    );
  }
}

class _AddExpectedMemberCard extends StatelessWidget {
  final List<MemberModel> availableMembers;
  final ValueChanged<MemberModel> onAdd;

  const _AddExpectedMemberCard({
    required this.availableMembers,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final button = ElevatedButton.icon(
              onPressed: availableMembers.isEmpty
                  ? null
                  : () async {
                      final selected = await showDialog<MemberModel>(
                        context: context,
                        builder: (context) {
                          return _SelectMemberDialog(members: availableMembers);
                        },
                      );

                      if (selected != null) onAdd(selected);
                    },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Ajouter attendu'),
            );

            if (constraints.maxWidth >= 560) {
              return Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Membres attendus',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  button,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Membres attendus',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

double _dialogWidth(BuildContext context, double maxWidth) {
  return (MediaQuery.sizeOf(context).width - 32).clamp(280.0, maxWidth);
}

class _SelectMemberDialog extends StatelessWidget {
  final List<MemberModel> members;

  const _SelectMemberDialog({required this.members});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Choisir un membre'),
      content: SizedBox(
        width: _dialogWidth(context, 480),
        height: (MediaQuery.sizeOf(context).height * 0.58)
            .clamp(280.0, 420.0)
            .toDouble(),
        child: ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.enactusYellow,
                foregroundColor: AppTheme.softBlack,
                child: Text(member.displayName[0].toUpperCase()),
              ),
              title: Text(member.displayName),
              subtitle: Text(member.email),
              onTap: () => Navigator.of(context).pop(member),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

class _AttendanceMemberFiltersCard extends StatelessWidget {
  final TextEditingController controller;
  final String statusFilter;
  final VoidCallback onChanged;
  final ValueChanged<String> onStatusChanged;

  const _AttendanceMemberFiltersCard({
    required this.controller,
    required this.statusFilter,
    required this.onChanged,
    required this.onStatusChanged,
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
                labelText: 'Rechercher un membre',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            );
            final filters = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusFilterChip(
                  label: 'Tous',
                  value: 'all',
                  current: statusFilter,
                  onSelected: onStatusChanged,
                ),
                _StatusFilterChip(
                  label: 'Présents',
                  value: 'present',
                  current: statusFilter,
                  onSelected: onStatusChanged,
                ),
                _StatusFilterChip(
                  label: 'Retards',
                  value: 'late',
                  current: statusFilter,
                  onSelected: onStatusChanged,
                ),
                _StatusFilterChip(
                  label: 'Justifiées',
                  value: 'justified',
                  current: statusFilter,
                  onSelected: onStatusChanged,
                ),
                _StatusFilterChip(
                  label: 'Non justifiées',
                  value: 'unjustified',
                  current: statusFilter,
                  onSelected: onStatusChanged,
                ),
                _StatusFilterChip(
                  label: 'Non saisis',
                  value: 'not_filled',
                  current: statusFilter,
                  onSelected: onStatusChanged,
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

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelected;

  const _StatusFilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      selectedColor: AppTheme.enactusYellow.withAlpha(120),
      onSelected: (_) => onSelected(value),
    );
  }
}

class _ExpectedMembersCard extends StatelessWidget {
  final List<MemberModel> members;
  final Map<String, AttendanceRecordModel> recordByUserId;
  final Future<void> Function({
    required MemberModel member,
    required String status,
  })
  onMarkAttendance;
  final bool sessionClosed;

  const _ExpectedMembersCard({
    required this.members,
    required this.recordByUserId,
    required this.onMarkAttendance,
    required this.sessionClosed,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucun membre attendu pour cette session.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return Column(
      children: members.map((member) {
        final record = recordByUserId[member.id];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;

                final identity = Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.enactusYellow,
                      foregroundColor: AppTheme.softBlack,
                      child: Text(member.displayName[0].toUpperCase()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            member.email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final statusChip = record == null
                    ? const Chip(label: Text('Non saisi'))
                    : Chip(
                        label: Text(record.statusLabel),
                        backgroundColor: Colors.green.shade50,
                      );
                final recordDetails = _RecordDetails(record: record);

                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: sessionClosed
                          ? null
                          : () => onMarkAttendance(
                              member: member,
                              status: 'present',
                            ),
                      child: const Text('Présent'),
                    ),
                    OutlinedButton(
                      onPressed: sessionClosed
                          ? null
                          : () => onMarkAttendance(
                              member: member,
                              status: 'late',
                            ),
                      child: const Text('Retard'),
                    ),
                    OutlinedButton(
                      onPressed: sessionClosed
                          ? null
                          : () => onMarkAttendance(
                              member: member,
                              status: 'absent',
                            ),
                      child: const Text('Absent'),
                    ),
                    OutlinedButton(
                      onPressed: sessionClosed
                          ? null
                          : () => onMarkAttendance(
                              member: member,
                              status: 'excused',
                            ),
                      child: const Text('Excuse'),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(flex: 2, child: identity),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [statusChip, recordDetails],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: actions),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 12),
                    statusChip,
                    recordDetails,
                    const SizedBox(height: 12),
                    actions,
                  ],
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecordDetails extends StatelessWidget {
  final AttendanceRecordModel? record;

  const _RecordDetails({required this.record});

  @override
  Widget build(BuildContext context) {
    if (record == null) return const SizedBox.shrink();

    final details = <Widget>[
      if ((record!.justification ?? '').trim().isNotEmpty)
        _RecordDetailLine(
          icon: Icons.edit_note_rounded,
          text: record!.justification!.trim(),
        ),
      if ((record!.penaltyAmount ?? 0) > 0)
        _RecordDetailLine(
          icon: Icons.payments_rounded,
          text: '${record!.penaltyAmount} FCFA',
        ),
    ];

    if (details.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details,
      ),
    );
  }
}

class _RecordDetailLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RecordDetailLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black45),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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

class _AttendanceStatsCard extends StatelessWidget {
  final int totalExpected;
  final int present;
  final int late;
  final int justifiedAbsence;
  final int unjustifiedAbsence;
  final int notFilled;
  final int totalPenaltyAmount;

  const _AttendanceStatsCard({
    required this.totalExpected,
    required this.present,
    required this.late,
    required this.justifiedAbsence,
    required this.unjustifiedAbsence,
    required this.notFilled,
    required this.totalPenaltyAmount,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _AttendanceStatItem(
        label: 'Attendus',
        value: totalExpected.toString(),
        icon: Icons.groups_rounded,
      ),
      _AttendanceStatItem(
        label: 'Présents',
        value: present.toString(),
        icon: Icons.check_circle_rounded,
      ),
      _AttendanceStatItem(
        label: 'Retards',
        value: late.toString(),
        icon: Icons.schedule_rounded,
      ),
      _AttendanceStatItem(
        label: 'Abs. justifiées',
        value: justifiedAbsence.toString(),
        icon: Icons.verified_rounded,
      ),
      _AttendanceStatItem(
        label: 'Abs. non justifiées',
        value: unjustifiedAbsence.toString(),
        icon: Icons.warning_rounded,
      ),
      _AttendanceStatItem(
        label: 'Non saisis',
        value: notFilled < 0 ? '0' : notFilled.toString(),
        icon: Icons.pending_actions_rounded,
      ),
      _AttendanceStatItem(
        label: 'Pénalités',
        value: '$totalPenaltyAmount FCFA',
        icon: Icons.payments_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 4
            : width >= 760
            ? 3
            : width >= 520
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.4,
          ),
          itemBuilder: (context, index) {
            final stat = stats[index];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.enactusYellow,
                      foregroundColor: AppTheme.softBlack,
                      child: Icon(stat.icon),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            stat.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AttendanceStatItem {
  final String label;
  final String value;
  final IconData icon;

  const _AttendanceStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}
