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

  bool _loading = true;
  String? _error;

  List<MemberModel> _members = [];
  List<AttendanceExpectedMemberModel> _expectedMembers = [];
  List<AttendanceRecordModel> _records = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
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

    if (status.contains('absent')) {
      justification = await _askJustification(status: status);
      if (justification == null && status == 'absent_justifie') {
        return;
      }
    }

    try {
      await _attendanceService.createManualAttendance(
        sessionId: widget.session.id,
        userId: member.id,
        status: status,
        justification: justification,
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
              labelText: status == 'absent_justifie'
                  ? 'Motif de l’absence justifiée'
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

  @override
  Widget build(BuildContext context) {
    final expectedIds = _expectedUserIds;
    final recordByUserId = _recordByUserId;

    final expectedMembers = _members
        .where((member) => expectedIds.contains(member.id))
        .toList();

    final availableMembers = _members
        .where((member) => !expectedIds.contains(member.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.session.title)),
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _SessionHeader(session: widget.session, onClose: _closeSession),
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
              _ExpectedMembersCard(
                members: expectedMembers,
                recordByUserId: recordByUserId,
                onMarkAttendance: _markAttendance,
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
    return _records.where((r) => r.status == 'retard').length;
  }

  int get _justifiedAbsenceCount {
    return _records.where((r) {
      return r.status == 'absent_justifie' || r.status == 'absence_justifiee';
    }).length;
  }

  int get _unjustifiedAbsenceCount {
    return _records.where((r) {
      return r.status == 'absent_non_justifie' ||
          r.status == 'absence_non_justifiee';
    }).length;
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
}

class _SessionHeader extends StatelessWidget {
  final AttendanceSessionModel session;
  final VoidCallback onClose;

  const _SessionHeader({required this.session, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
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
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${session.typeLabel} • ${session.statusLabel} • ${session.dateLabel}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: session.status == 'closed' ? null : onClose,
            icon: const Icon(Icons.lock_rounded),
            label: Text(session.status == 'closed' ? 'Clôturée' : 'Clôturer'),
          ),
        ],
      ),
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
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Membres attendus',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            ElevatedButton.icon(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectMemberDialog extends StatelessWidget {
  final List<MemberModel> members;

  const _SelectMemberDialog({required this.members});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir un membre'),
      content: SizedBox(
        width: 480,
        height: 420,
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

class _ExpectedMembersCard extends StatelessWidget {
  final List<MemberModel> members;
  final Map<String, AttendanceRecordModel> recordByUserId;
  final Future<void> Function({
    required MemberModel member,
    required String status,
  })
  onMarkAttendance;

  const _ExpectedMembersCard({
    required this.members,
    required this.recordByUserId,
    required this.onMarkAttendance,
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

                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          onMarkAttendance(member: member, status: 'present'),
                      child: const Text('Présent'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          onMarkAttendance(member: member, status: 'retard'),
                      child: const Text('Retard'),
                    ),
                    OutlinedButton(
                      onPressed: () => onMarkAttendance(
                        member: member,
                        status: 'absent_justifie',
                      ),
                      child: const Text('Abs. justifiée'),
                    ),
                    OutlinedButton(
                      onPressed: () => onMarkAttendance(
                        member: member,
                        status: 'absent_non_justifie',
                      ),
                      child: const Text('Abs. non justifiée'),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(flex: 2, child: identity),
                      const SizedBox(width: 12),
                      statusChip,
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
