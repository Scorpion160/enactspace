import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../models/gamification_models.dart';
import '../services/gamification_service.dart';

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen> {
  final GamificationService _gamificationService = GamificationService();
  final MembersService _membersService = MembersService();
  final PolesService _polesService = PolesService();

  bool _loading = true;
  String? _error;

  List<MemberModel> _members = [];
  List<PoleModel> _poles = [];
  List<EngagementPointModel> _points = [];
  List<BadgeModel> _badges = [];
  List<UserBadgeModel> _userBadges = [];
  List<UserRankingModel> _userRanking = [];
  List<PoleRankingModel> _poleRanking = [];
  MonthlyWinnerModel? _memberOfMonth;
  MonthlyWinnerModel? _poleOfMonth;

  int get _month => DateTime.now().month;
  int get _year => DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadGamification();
  }

  Future<void> _loadGamification() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _membersService.getMembers(),
        _polesService.getPoles(),
        _gamificationService.getPoints(),
        _gamificationService.getBadges(),
        _gamificationService.getUserBadges(),
        _gamificationService.getUserRanking(month: _month, year: _year),
        _gamificationService.getPoleRanking(month: _month, year: _year),
        _gamificationService.getMemberOfMonth(month: _month, year: _year),
        _gamificationService.getPoleOfMonth(month: _month, year: _year),
      ]);

      if (!mounted) return;

      setState(() {
        _members = results[0] as List<MemberModel>;
        _poles = results[1] as List<PoleModel>;
        _points = results[2] as List<EngagementPointModel>;
        _badges = results[3] as List<BadgeModel>;
        _userBadges = results[4] as List<UserBadgeModel>;
        _userRanking = results[5] as List<UserRankingModel>;
        _poleRanking = results[6] as List<PoleRankingModel>;
        _memberOfMonth = results[7] as MonthlyWinnerModel;
        _poleOfMonth = results[8] as MonthlyWinnerModel;
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

  Future<void> _initBadges() async {
    try {
      final created = await _gamificationService.initDefaultBadges();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created.isEmpty
                ? 'Les badges par défaut existent déjà.'
                : '${created.length} badge(s) initialisé(s).',
          ),
        ),
      );

      await _loadGamification();
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _openAwardPointsDialog() async {
    if (_members.isEmpty) {
      _showError('Ajoutez au moins un membre avant d’attribuer des points.');
      return;
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AwardPointsDialog(
          members: _members,
          poles: _poles,
          gamificationService: _gamificationService,
        );
      },
    );

    if (created == true) {
      await _loadGamification();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red.shade700, content: Text(message)),
    );
  }

  String _memberName(String? userId) {
    if (userId == null || userId.isEmpty) return 'Aucun membre';
    final member = _members.where((item) => item.id == userId).firstOrNull;
    return member?.displayName ?? _shortId(userId);
  }

  String _poleName(String? poleId) {
    if (poleId == null || poleId.isEmpty) return 'Aucun pôle';
    final pole = _poles.where((item) => item.id == poleId).firstOrNull;
    return pole?.name ?? _shortId(poleId);
  }

  int get _totalPoints {
    return _points.fold(0, (sum, point) => sum + point.points);
  }

  int get _positivePoints {
    return _points
        .where((point) => point.points > 0)
        .fold(0, (sum, point) => sum + point.points);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadGamification,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 560 ? 14.0 : 24.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              28,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GamificationHeader(
                        monthLabel: _monthLabel(_month, _year),
                        onRefresh: _loadGamification,
                        onAwardPoints: _openAwardPointsDialog,
                        onInitBadges: _initBadges,
                      ),
                      const SizedBox(height: 18),
                      if (_loading)
                        const _LoadingCard()
                      else if (_error != null)
                        _ErrorCard(message: _error!, onRetry: _loadGamification)
                      else ...[
                        _GamificationStats(
                          totalPoints: _totalPoints,
                          positivePoints: _positivePoints,
                          badges: _badges.length,
                          awardedBadges: _userBadges.length,
                        ),
                        const SizedBox(height: 18),
                        _WinnersGrid(
                          memberName: _memberName(_memberOfMonth?.userId),
                          poleName: _poleName(_poleOfMonth?.poleId),
                          memberPoints: _memberOfMonth?.totalPoints ?? 0,
                          polePoints: _poleOfMonth?.totalPoints ?? 0,
                        ),
                        const SizedBox(height: 18),
                        _RankingsSection(
                          userRanking: _userRanking,
                          poleRanking: _poleRanking,
                          memberName: _memberName,
                          poleName: _poleName,
                        ),
                        const SizedBox(height: 18),
                        _BadgesSection(badges: _badges),
                        const SizedBox(height: 18),
                        _RecentPointsSection(
                          points: _points.take(12).toList(),
                          memberName: _memberName,
                          poleName: _poleName,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GamificationHeader extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onRefresh;
  final VoidCallback onAwardPoints;
  final VoidCallback onInitBadges;

  const _GamificationHeader({
    required this.monthLabel,
    required this.onRefresh,
    required this.onAwardPoints,
    required this.onInitBadges,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.softBlack,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;

            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.enactusYellow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    monthLabel,
                    style: const TextStyle(
                      color: AppTheme.softBlack,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Engagement et reconnaissance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Badges, points positifs et classements pour valoriser les contributions des Enacteurs.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
              ],
            );

            final actions = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualiser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onInitBadges,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('Badges par défaut'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onAwardPoints,
                  icon: const Icon(Icons.add_reaction_rounded),
                  label: const Text('Attribuer points'),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 18), actions],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: title),
                const SizedBox(width: 20),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GamificationStats extends StatelessWidget {
  final int totalPoints;
  final int positivePoints;
  final int badges;
  final int awardedBadges;

  const _GamificationStats({
    required this.totalPoints,
    required this.positivePoints,
    required this.badges,
    required this.awardedBadges,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('Points totaux', totalPoints.toString(), Icons.bolt_rounded),
      _StatItem(
        'Points positifs',
        positivePoints.toString(),
        Icons.favorite_rounded,
      ),
      _StatItem('Badges', badges.toString(), Icons.workspace_premium_rounded),
      _StatItem(
        'Badges attribués',
        awardedBadges.toString(),
        Icons.verified_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 118,
          ),
          itemBuilder: (context, index) {
            final item = items[index];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.enactusYellow,
                      foregroundColor: AppTheme.softBlack,
                      child: Icon(item.icon),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.value,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            item.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
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

class _WinnersGrid extends StatelessWidget {
  final String memberName;
  final String poleName;
  final int memberPoints;
  final int polePoints;

  const _WinnersGrid({
    required this.memberName,
    required this.poleName,
    required this.memberPoints,
    required this.polePoints,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 760 ? 2 : 1;

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 154,
          ),
          children: [
            _WinnerCard(
              title: 'Membre du mois',
              name: memberName,
              points: memberPoints,
              icon: Icons.emoji_events_rounded,
            ),
            _WinnerCard(
              title: 'Pôle du mois',
              name: poleName,
              points: polePoints,
              icon: Icons.military_tech_rounded,
            ),
          ],
        );
      },
    );
  }
}

class _WinnerCard extends StatelessWidget {
  final String title;
  final String name;
  final int points;
  final IconData icon;

  const _WinnerCard({
    required this.title,
    required this.name,
    required this.points,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.enactusYellow,
              foregroundColor: AppTheme.softBlack,
              child: Icon(icon, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$points point(s)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingsSection extends StatelessWidget {
  final List<UserRankingModel> userRanking;
  final List<PoleRankingModel> poleRanking;
  final String Function(String? userId) memberName;
  final String Function(String? poleId) poleName;

  const _RankingsSection({
    required this.userRanking,
    required this.poleRanking,
    required this.memberName,
    required this.poleName,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 900;
        final sections = [
          _RankingCard<UserRankingModel>(
            title: 'Classement Enacteurs',
            icon: Icons.leaderboard_rounded,
            items: userRanking,
            emptyText: 'Aucun point membre ce mois-ci.',
            nameOf: (item) => memberName(item.userId),
            pointsOf: (item) => item.totalPoints,
          ),
          _RankingCard<PoleRankingModel>(
            title: 'Classement pôles',
            icon: Icons.hub_rounded,
            items: poleRanking,
            emptyText: 'Aucun point pôle ce mois-ci.',
            nameOf: (item) => poleName(item.poleId),
            pointsOf: (item) => item.totalPoints,
          ),
        ];

        if (!twoColumns) {
          return Column(
            children: [
              sections.first,
              const SizedBox(height: 12),
              sections.last,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: sections.first),
            const SizedBox(width: 12),
            Expanded(child: sections.last),
          ],
        );
      },
    );
  }
}

class _RankingCard<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<T> items;
  final String emptyText;
  final String Function(T item) nameOf;
  final int Function(T item) pointsOf;

  const _RankingCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
    required this.nameOf,
    required this.pointsOf,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(icon: icon, title: title),
            const Divider(height: 26),
            if (items.isEmpty)
              _EmptyText(emptyText)
            else
              ...items.take(8).indexed.map((entry) {
                final rank = entry.$1 + 1;
                final item = entry.$2;

                return _RankingRow(
                  rank: rank,
                  name: nameOf(item),
                  points: pointsOf(item),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final String name;
  final int points;

  const _RankingRow({
    required this.rank,
    required this.name,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.enactusYellow.withValues(alpha: 0.16)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: highlight ? AppTheme.enactusYellow : Colors.white,
            foregroundColor: AppTheme.softBlack,
            child: Text(
              '$rank',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$points pts',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _BadgesSection extends StatelessWidget {
  final List<BadgeModel> badges;

  const _BadgesSection({required this.badges});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              icon: Icons.workspace_premium_rounded,
              title: 'Badges disponibles',
            ),
            const Divider(height: 26),
            if (badges.isEmpty)
              const _EmptyText(
                'Aucun badge configuré. Initialise les badges par défaut pour commencer.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final count = constraints.maxWidth >= 980
                      ? 4
                      : constraints.maxWidth >= 680
                      ? 3
                      : constraints.maxWidth >= 460
                      ? 2
                      : 1;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: badges.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 142,
                    ),
                    itemBuilder: (context, index) {
                      return _BadgeCard(badge: badges[index]);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.enactusYellow.withValues(alpha: 0.45),
        ),
        color: AppTheme.enactusYellow.withValues(alpha: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.enactusYellow,
            foregroundColor: AppTheme.softBlack,
            child: Icon(_badgeIcon(badge.name)),
          ),
          const SizedBox(height: 10),
          Text(
            badge.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              badge.description ?? 'Badge de reconnaissance EnactSpace.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPointsSection extends StatelessWidget {
  final List<EngagementPointModel> points;
  final String Function(String? userId) memberName;
  final String Function(String? poleId) poleName;

  const _RecentPointsSection({
    required this.points,
    required this.memberName,
    required this.poleName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              icon: Icons.history_rounded,
              title: 'Derniers points',
            ),
            const Divider(height: 26),
            if (points.isEmpty)
              const _EmptyText('Aucun point attribué pour le moment.')
            else
              ...points.map((point) {
                return _PointTile(
                  point: point,
                  memberName: memberName(point.userId),
                  poleName: poleName(point.poleId),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _PointTile extends StatelessWidget {
  final EngagementPointModel point;
  final String memberName;
  final String poleName;

  const _PointTile({
    required this.point,
    required this.memberName,
    required this.poleName,
  });

  @override
  Widget build(BuildContext context) {
    final positive = point.points >= 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: positive
            ? AppTheme.enactusYellow
            : Colors.red.shade100,
        foregroundColor: AppTheme.softBlack,
        child: Icon(positive ? Icons.add_rounded : Icons.remove_rounded),
      ),
      title: Text(
        memberName,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        [
          _sourceLabel(point.sourceType),
          if (point.poleId != null) poleName,
          DateFormat('dd/MM/yyyy HH:mm').format(point.createdAt),
        ].join(' • '),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${positive ? '+' : ''}${point.points}',
        style: TextStyle(
          color: positive ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

class AwardPointsDialog extends StatefulWidget {
  final List<MemberModel> members;
  final List<PoleModel> poles;
  final GamificationService gamificationService;

  const AwardPointsDialog({
    super.key,
    required this.members,
    required this.poles,
    required this.gamificationService,
  });

  @override
  State<AwardPointsDialog> createState() => _AwardPointsDialogState();
}

class _AwardPointsDialogState extends State<AwardPointsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pointsController = TextEditingController(text: '5');
  final _reasonController = TextEditingController();

  String? _selectedUserId;
  String? _selectedPoleId;
  String _sourceType = 'manual';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.members.isNotEmpty
        ? widget.members.first.id
        : null;
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.gamificationService.createPoint(
        userId: _selectedUserId!,
        poleId: _selectedPoleId,
        sourceType: _sourceType,
        points: int.parse(_pointsController.text.trim()),
        reason: _reasonController.text,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Attribuer des points'),
      content: SizedBox(
        width: _dialogWidth(context, 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_error != null) _DialogError(message: _error!),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUserId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Membre',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  items: widget.members.map((member) {
                    return DropdownMenuItem(
                      value: member.id,
                      child: Text(member.displayName),
                    );
                  }).toList(),
                  onChanged: _loading
                      ? null
                      : (value) => setState(() => _selectedUserId = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sélectionnez un membre.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedPoleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pôle lié',
                    prefixIcon: Icon(Icons.hub_rounded),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Aucun pôle'),
                    ),
                    ...widget.poles.map((pole) {
                      return DropdownMenuItem<String?>(
                        value: pole.id,
                        child: Text(pole.name),
                      );
                    }),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) => setState(() => _selectedPoleId = value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _sourceType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Contribution',
                    prefixIcon: Icon(Icons.auto_awesome_rounded),
                  ),
                  items: _sourceTypes.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _sourceType = value);
                          }
                        },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points',
                    prefixIcon: Icon(Icons.bolt_rounded),
                  ),
                  validator: (value) {
                    final points = int.tryParse(value?.trim() ?? '');
                    if (points == null || points == 0) {
                      return 'Entrez un nombre de points non nul.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motif',
                    prefixIcon: Icon(Icons.notes_rounded),
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
          label: Text(_loading ? 'Attribution...' : 'Attribuer'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(42),
        child: Center(child: CircularProgressIndicator()),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
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

class _DialogError extends StatelessWidget {
  final String message;

  const _DialogError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade700)),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem(this.label, this.value, this.icon);
}

const _sourceTypes = <String, String>{
  'task_validated': 'Tâche validée',
  'attendance_present': 'Présence',
  'attendance_late': 'Retard assumé',
  'event_participation': 'Participation événement',
  'training_completed': 'Formation suivie',
  'document_shared': 'Document partagé',
  'project_progress': 'Avancement projet',
  'mentorship': 'Mentorat',
  'leader_rating': 'Appréciation leader',
  'manual': 'Attribution manuelle',
};

String _sourceLabel(String sourceType) {
  return _sourceTypes[sourceType] ?? sourceType;
}

IconData _badgeIcon(String name) {
  switch (name) {
    case 'ponctuel':
      return Icons.schedule_rounded;
    case 'leader':
      return Icons.flag_rounded;
    case 'innovateur':
      return Icons.lightbulb_rounded;
    case 'finisher':
      return Icons.task_alt_rounded;
    case 'mentor':
      return Icons.school_rounded;
    case 'communicateur':
      return Icons.campaign_rounded;
    case 'batisseur':
      return Icons.construction_rounded;
    default:
      return Icons.workspace_premium_rounded;
  }
}

double _dialogWidth(BuildContext context, double maxWidth) {
  return (MediaQuery.sizeOf(context).width - 32).clamp(280.0, maxWidth);
}

String _shortId(String id) {
  if (id.length <= 8) return id;
  return '${id.substring(0, 8)}...';
}

String _monthLabel(int month, int year) {
  const labels = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  final label = labels[(month - 1).clamp(0, 11)];
  return '$label $year';
}
