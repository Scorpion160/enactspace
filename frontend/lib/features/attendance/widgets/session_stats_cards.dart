import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SessionStatsCards extends StatelessWidget {
  final int totalExpected;
  final int present;
  final int late;
  final int justifiedAbsence;
  final int unjustifiedAbsence;
  final int notFilled;
  final int totalPenaltyAmount;

  const SessionStatsCards({
    super.key,
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
        label: 'Presents',
        value: present.toString(),
        icon: Icons.check_circle_rounded,
      ),
      _AttendanceStatItem(
        label: 'Retards',
        value: late.toString(),
        icon: Icons.schedule_rounded,
      ),
      _AttendanceStatItem(
        label: 'Abs. justifiees',
        value: justifiedAbsence.toString(),
        icon: Icons.verified_rounded,
      ),
      _AttendanceStatItem(
        label: 'Abs. non justifiees',
        value: unjustifiedAbsence.toString(),
        icon: Icons.warning_rounded,
      ),
      _AttendanceStatItem(
        label: 'Non saisis',
        value: notFilled < 0 ? '0' : notFilled.toString(),
        icon: Icons.pending_actions_rounded,
      ),
      _AttendanceStatItem(
        label: 'Penalites',
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
