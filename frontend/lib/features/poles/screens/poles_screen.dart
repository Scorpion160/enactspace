import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../models/pole_model.dart';
import '../services/poles_service.dart';

class PolesScreen extends StatefulWidget {
  const PolesScreen({super.key});

  @override
  State<PolesScreen> createState() => _PolesScreenState();
}

class _PolesScreenState extends State<PolesScreen> {
  final PolesService _polesService = PolesService();
  final MembersService _membersService = MembersService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  UserExperience? _userExperience;
  List<PoleModel> _poles = [];
  List<MemberModel> _members = [];

  @override
  void initState() {
    super.initState();
    _loadPoles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPoles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final poles = await _polesService.getPoles();
      final members = await _loadMembersSafely();
      final userExperience = await _loadUserExperienceSafely();

      if (!mounted) return;

      setState(() {
        _poles = poles;
        _members = members;
        _userExperience = userExperience;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<UserExperience?> _loadUserExperienceSafely() async {
    try {
      final user = await _authService.getCurrentUser();
      return UserExperience.fromJson(user);
    } catch (_) {
      return null;
    }
  }

  Future<List<MemberModel>> _loadMembersSafely() async {
    try {
      return await _membersService.getMembers();
    } catch (_) {
      return [];
    }
  }

  List<PoleModel> get _filteredPoles {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _poles;

    return _poles.where((pole) {
      return pole.name.toLowerCase().contains(query) ||
          (pole.shortName ?? '').toLowerCase().contains(query) ||
          pole.typeLabel.toLowerCase().contains(query);
    }).toList();
  }

  int _memberCount(PoleModel pole) {
    return _members.where((member) => member.corePoleId == pole.id).length;
  }

  List<MemberModel> _membersForPole(PoleModel pole) {
    return _members.where((member) => member.corePoleId == pole.id).toList();
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _CreatePoleSheet(service: _polesService);
      },
    );

    if (created == true) {
      await _loadPoles();
    }
  }

  Future<void> _reloadAfterMembershipChange() async {
    await _loadPoles();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _userExperience?.canCreateOperationalWork ?? false;

    return RefreshIndicator(
      onRefresh: _loadPoles,
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
                    children: [
                      _PolesHeader(
                        total: _poles.length,
                        members: _members
                            .where((member) => member.corePoleId != null)
                            .length,
                        onCreate: canManage ? _openCreateSheet : null,
                        onRefresh: _loadPoles,
                      ),
                      const SizedBox(height: 18),
                      _PolesToolbar(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 22),
                      if (_loading)
                        const _LoadingCard()
                      else if (_error != null)
                        _ErrorCard(message: _error!, onRetry: _loadPoles)
                      else if (_filteredPoles.isEmpty)
                        const _EmptyPolesCard()
                      else
                        _PolesGrid(
                          poles: _filteredPoles,
                          allMembers: _members,
                          polesService: _polesService,
                          canManage: canManage,
                          memberCount: _memberCount,
                          membersForPole: _membersForPole,
                          onMembershipChanged: _reloadAfterMembershipChange,
                        ),
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

class _PolesHeader extends StatelessWidget {
  final int total;
  final int members;
  final VoidCallback? onCreate;
  final VoidCallback onRefresh;

  const _PolesHeader({
    required this.total,
    required this.members,
    required this.onCreate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 820;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: isWide
          ? Row(
              children: [
                const _HeaderIcon(),
                const SizedBox(width: 18),
                Expanded(
                  child: _HeaderText(total: total, members: members),
                ),
                const SizedBox(width: 18),
                _HeaderActions(onCreate: onCreate, onRefresh: onRefresh),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderIcon(),
                const SizedBox(height: 18),
                _HeaderText(total: total, members: members),
                const SizedBox(height: 18),
                _HeaderActions(onCreate: onCreate, onRefresh: onRefresh),
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
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.hub_rounded, color: AppTheme.softBlack, size: 36),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final int total;
  final int members;

  const _HeaderText({required this.total, required this.members});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pôles',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'La carte des équipes qui font avancer Enactus ESP.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeaderChip(label: '$total pôle(s)'),
            _HeaderChip(label: '$members membre(s) rattaché(s)'),
          ],
        ),
      ],
    );
  }
}

class _HeaderActions extends StatelessWidget {
  final VoidCallback? onCreate;
  final VoidCallback onRefresh;

  const _HeaderActions({required this.onCreate, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
          label: const Text('Créer un pôle'),
        ),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;

  const _HeaderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}

class _PolesToolbar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _PolesToolbar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: const InputDecoration(
            labelText: 'Rechercher un pôle',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
    );
  }
}

class _PolesGrid extends StatelessWidget {
  final List<PoleModel> poles;
  final List<MemberModel> allMembers;
  final PolesService polesService;
  final bool canManage;
  final int Function(PoleModel pole) memberCount;
  final List<MemberModel> Function(PoleModel pole) membersForPole;
  final Future<void> Function() onMembershipChanged;

  const _PolesGrid({
    required this.poles,
    required this.allMembers,
    required this.polesService,
    required this.canManage,
    required this.memberCount,
    required this.membersForPole,
    required this.onMembershipChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;

        const spacing = 14.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final pole in poles)
              SizedBox(
                width: itemWidth,
                child: _PoleCard(
                  pole: pole,
                  memberCount: memberCount(pole),
                  members: membersForPole(pole),
                  allMembers: allMembers,
                  polesService: polesService,
                  canManage: canManage,
                  onMembershipChanged: onMembershipChanged,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PoleCard extends StatelessWidget {
  final PoleModel pole;
  final int memberCount;
  final List<MemberModel> members;
  final List<MemberModel> allMembers;
  final PolesService polesService;
  final bool canManage;
  final Future<void> Function() onMembershipChanged;

  const _PoleCard({
    required this.pole,
    required this.memberCount,
    required this.members,
    required this.allMembers,
    required this.polesService,
    required this.canManage,
    required this.onMembershipChanged,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat('dd/MM/yyyy').format(pole.createdAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.enactusYellow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    pole.displayShortName,
                    style: const TextStyle(
                      color: AppTheme.softBlack,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pole.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${pole.typeLabel} • créé le $createdAt',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PoleChip(
                  icon: Icons.people_alt_rounded,
                  label: '$memberCount membre(s)',
                ),
                _PoleChip(icon: Icons.category_rounded, label: pole.typeLabel),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _safeText(
                pole.description,
                fallback: 'Aucune description renseignée pour ce pôle.',
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 14),
            _PoleHealthStrip(pole: pole, memberCount: memberCount),
            const SizedBox(height: 14),
            _PoleMemberPreview(members: members),
            const Divider(height: 26),
            Row(
              children: [
                const Icon(Icons.flag_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _safeText(
                      pole.objectives,
                      fallback: 'Objectifs à préciser',
                    ),
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
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showPoleDetails(
                  context,
                  pole,
                  members,
                  allMembers,
                  polesService,
                  canManage,
                  onMembershipChanged,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Détail pôle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoleHealthStrip extends StatelessWidget {
  final PoleModel pole;
  final int memberCount;

  const _PoleHealthStrip({required this.pole, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    final health = _poleHealthScore(pole, memberCount);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_rounded, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Santé du pôle',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '$health/100',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: health / 100,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppTheme.enactusYellow,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoleMemberPreview extends StatelessWidget {
  final List<MemberModel> members;

  const _PoleMemberPreview({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Text(
        'Aucun membre rattaché pour le moment.',
        style: TextStyle(color: Colors.black54),
      );
    }

    final preview = members.take(4).toList();

    return Row(
      children: [
        SizedBox(
          width: 126,
          height: 34,
          child: Stack(
            children: [
              for (var index = 0; index < preview.length; index++)
                Positioned(
                  left: index * 28,
                  child: _MemberMiniAvatar(member: preview[index]),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            members.length > preview.length
                ? '${members.length} membres, dont ${preview.map((m) => m.displayName).take(2).join(', ')}...'
                : preview.map((m) => m.displayName).join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

class _MemberMiniAvatar extends StatelessWidget {
  final MemberModel member;

  const _MemberMiniAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 17,
      backgroundColor: AppTheme.enactusYellow,
      foregroundColor: AppTheme.softBlack,
      child: Text(
        _initials(member.displayName),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

void _showPoleDetails(
  BuildContext context,
  PoleModel pole,
  List<MemberModel> members,
  List<MemberModel> allMembers,
  PolesService polesService,
  bool canManage,
  Future<void> Function() onMembershipChanged,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _PoleDetailsSheet(
      pole: pole,
      members: members,
      allMembers: allMembers,
      polesService: polesService,
      canManage: canManage,
      onMembershipChanged: onMembershipChanged,
    ),
  );
}

class _PoleDetailsSheet extends StatelessWidget {
  final PoleModel pole;
  final List<MemberModel> members;
  final List<MemberModel> allMembers;
  final PolesService polesService;
  final bool canManage;
  final Future<void> Function() onMembershipChanged;

  const _PoleDetailsSheet({
    required this.pole,
    required this.members,
    required this.allMembers,
    required this.polesService,
    required this.canManage,
    required this.onMembershipChanged,
  });

  @override
  Widget build(BuildContext context) {
    final leaders = members.where(_looksLikePoleLead).toList();
    final deputies = members.where(_looksLikeDeputy).toList();
    final health = _poleHealthScore(pole, members.length);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.52,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.enactusYellow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          pole.displayShortName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pole.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${pole.typeLabel} · ${members.length} membre(s) · santé $health/100',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DetailSection(
                    title: 'Objectifs',
                    icon: Icons.flag_rounded,
                    body: _safeText(
                      pole.objectives,
                      fallback: 'Objectifs à préciser par le responsable.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: 'Description',
                    icon: Icons.description_rounded,
                    body: _safeText(
                      pole.description,
                      fallback: 'Description à compléter.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GovernancePanel(leaders: leaders, deputies: deputies),
                  const SizedBox(height: 16),
                  _PoleMembershipManager(
                    pole: pole,
                    members: members,
                    allMembers: allMembers,
                    service: polesService,
                    canManage: canManage,
                    onMembershipChanged: onMembershipChanged,
                  ),
                  const SizedBox(height: 16),
                  const _PoleActionLinks(),
                  const SizedBox(height: 16),
                  Text(
                    'Membres du pôle',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (members.isEmpty)
                    const Text(
                      'Aucun membre rattaché pour le moment.',
                      style: TextStyle(color: Colors.black54),
                    )
                  else
                    ...members.map(
                      (member) => _PoleMemberTile(
                        member: member,
                        onRemove: canManage
                            ? () async {
                                await polesService.removeMember(
                                  poleId: pole.id,
                                  userId: member.id,
                                );
                                await onMembershipChanged();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${member.displayName} a été retiré du pôle.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String body;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.enactusYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.softBlack),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GovernancePanel extends StatelessWidget {
  final List<MemberModel> leaders;
  final List<MemberModel> deputies;

  const _GovernancePanel({required this.leaders, required this.deputies});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _GovernanceCard(
          title: 'Chef de pôle',
          icon: Icons.admin_panel_settings_rounded,
          members: leaders,
        ),
        _GovernanceCard(
          title: 'Adjoint(s)',
          icon: Icons.supervisor_account_rounded,
          members: deputies,
        ),
      ],
    );
  }
}

class _GovernanceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<MemberModel> members;

  const _GovernanceCard({
    required this.title,
    required this.icon,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 72).clamp(260.0, 340.0),
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.enactusYellow,
                foregroundColor: AppTheme.softBlack,
                child: Icon(icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      members.isEmpty
                          ? 'À désigner'
                          : members
                                .map((member) => member.displayName)
                                .join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PoleMembershipManager extends StatefulWidget {
  final PoleModel pole;
  final List<MemberModel> members;
  final List<MemberModel> allMembers;
  final PolesService service;
  final bool canManage;
  final Future<void> Function() onMembershipChanged;

  const _PoleMembershipManager({
    required this.pole,
    required this.members,
    required this.allMembers,
    required this.service,
    required this.canManage,
    required this.onMembershipChanged,
  });

  @override
  State<_PoleMembershipManager> createState() => _PoleMembershipManagerState();
}

class _PoleMembershipManagerState extends State<_PoleMembershipManager> {
  String? _selectedUserId;
  String _position = 'membre';
  bool _saving = false;

  Future<void> _assign() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un membre à affecter.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.service.assignMember(
        poleId: widget.pole.id,
        userId: _selectedUserId!,
        position: _position,
      );
      await widget.onMembershipChanged();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Affectation pôle mise à jour.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeIds = widget.members.map((member) => member.id).toSet();
    final sortedMembers = [...widget.allMembers]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fieldWidth = constraints.maxWidth >= 680
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.group_add_rounded, color: AppTheme.enactusYellow),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Affectation au pôle',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUserId,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      decoration: const InputDecoration(
                        labelText: 'Membre',
                        prefixIcon: Icon(Icons.person_add_rounded),
                      ),
                      items: [
                        for (final member in sortedMembers)
                          DropdownMenuItem(
                            value: member.id,
                            child: Text(
                              activeIds.contains(member.id)
                                  ? '${member.displayName} · déjà rattaché'
                                  : member.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: !widget.canManage || _saving
                          ? null
                          : (value) => setState(() => _selectedUserId = value),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      initialValue: _position,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      decoration: const InputDecoration(
                        labelText: 'Position',
                        prefixIcon: Icon(Icons.admin_panel_settings_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'membre',
                          child: Text('Membre'),
                        ),
                        DropdownMenuItem(
                          value: 'adjoint_chef_pole',
                          child: Text('Adjoint chef de pôle'),
                        ),
                        DropdownMenuItem(
                          value: 'chef_pole',
                          child: Text('Chef de pôle'),
                        ),
                      ],
                      onChanged: !widget.canManage || _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _position = value);
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: !widget.canManage || _saving ? null : _assign,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Mettre à jour'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PoleActionLinks extends StatelessWidget {
  const _PoleActionLinks();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _PoleActionChip(icon: Icons.task_alt_rounded, label: 'Tâches liées'),
        _PoleActionChip(icon: Icons.description_rounded, label: 'Documents'),
        _PoleActionChip(icon: Icons.campaign_rounded, label: 'Annonces'),
        _PoleActionChip(icon: Icons.forum_rounded, label: 'Discussion pôle'),
        _PoleActionChip(
          icon: Icons.summarize_rounded,
          label: 'Rapport mensuel',
        ),
      ],
    );
  }
}

class _PoleActionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PoleActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _PoleMemberTile extends StatelessWidget {
  final MemberModel member;
  final Future<void> Function()? onRemove;

  const _PoleMemberTile({required this.member, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _MemberMiniAvatar(member: member),
      title: Text(member.displayName),
      subtitle: Text(member.email),
      trailing: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text(_memberRoleLabel(member))),
          if (onRemove != null)
            IconButton(
              tooltip: 'Retirer du pôle',
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_rounded),
            ),
        ],
      ),
    );
  }
}

class _PoleChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PoleChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.14),
      side: BorderSide(color: AppTheme.enactusYellow.withValues(alpha: 0.34)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _CreatePoleSheet extends StatefulWidget {
  final PolesService service;

  const _CreatePoleSheet({required this.service});

  @override
  State<_CreatePoleSheet> createState() => _CreatePoleSheetState();
}

class _CreatePoleSheetState extends State<_CreatePoleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _objectivesController = TextEditingController();

  String _type = 'metier';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    _descriptionController.dispose();
    _objectivesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await widget.service.createPole(
        name: _nameController.text,
        shortName: _shortNameController.text,
        type: _type,
        description: _descriptionController.text,
        objectives: _objectivesController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Créer un pôle',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du pôle',
                    prefixIcon: Icon(Icons.hub_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est obligatoire.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _shortNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom court',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'metier', child: Text('Métier')),
                    DropdownMenuItem(value: 'support', child: Text('Support')),
                    DropdownMenuItem(value: 'bureau', child: Text('Bureau')),
                    DropdownMenuItem(value: 'projet', child: Text('Projet')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _objectivesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Objectifs',
                    prefixIcon: Icon(Icons.flag_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Créer le pôle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(40),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement des pôles',
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

class _EmptyPolesCard extends StatelessWidget {
  const _EmptyPolesCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: Text(
            'Aucun pôle ne correspond à la recherche actuelle.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

String _safeText(String? value, {required String fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  return value.trim();
}

int _poleHealthScore(PoleModel pole, int memberCount) {
  var score = 25;

  if (memberCount >= 3) score += 25;
  if (memberCount >= 6) score += 10;
  if ((pole.description ?? '').trim().length >= 40) score += 15;
  if ((pole.objectives ?? '').trim().length >= 40) score += 20;
  if (pole.shortName != null && pole.shortName!.trim().isNotEmpty) score += 5;

  return score.clamp(0, 100);
}

bool _looksLikePoleLead(MemberModel member) {
  final position = (member.polePosition ?? '').toLowerCase();
  if (position == 'chef_pole') return true;

  final roles = member.roles.map((role) => role.toLowerCase()).join(' ');
  return roles.contains('chef') ||
      roles.contains('lead') ||
      roles.contains('responsable');
}

bool _looksLikeDeputy(MemberModel member) {
  final position = (member.polePosition ?? '').toLowerCase();
  if (position == 'adjoint_chef_pole') return true;

  final roles = member.roles.map((role) => role.toLowerCase()).join(' ');
  return roles.contains('adjoint') ||
      roles.contains('deputy') ||
      roles.contains('assistant');
}

String _memberRoleLabel(MemberModel member) {
  switch (member.polePosition) {
    case 'chef_pole':
      return 'Chef de pôle';
    case 'adjoint_chef_pole':
      return 'Adjoint chef de pôle';
    case 'membre':
      return 'Membre du pôle';
  }

  final roles = member.roles.where((role) => role.trim().isNotEmpty).toList();
  if (roles.isEmpty) return member.statusLabel;
  return roles.take(2).join(', ');
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();

  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
