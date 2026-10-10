import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/academic/esp_academic_catalog.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../shared/ui/app_components.dart';
import '../../gamification/services/games_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/member_model.dart';
import '../services/members_service.dart';
import 'member_import_panel.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final AuthService _authService = AuthService();
  final MembersService _membersService = MembersService();
  final PolesService _polesService = PolesService();
  final ProjectsService _projectsService = ProjectsService();

  bool _loading = true;
  String? _error;
  List<MemberModel> _members = [];
  UserExperience? _userExperience;
  String _search = '';
  String _statusFilter = 'all';
  String _roleFilter = 'all';
  String _poleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = UserExperience.fromJson(await _authService.getCurrentUser());
      final members = user.canManageMembers
          ? await _membersService.getManagedMembers()
          : await _membersService.getMembers();
      if (user.canReviewJoinRequests && !user.canManageMembers) {
        final pendingMembers = await _membersService.getPendingMembers();
        final knownIds = members.map((member) => member.id).toSet();
        members.addAll(
          pendingMembers.where((member) => knownIds.add(member.id)),
        );
      }
      members.removeWhere((member) => member.isAlumni);
      members.sort(MemberModel.compareAlphabetically);

      if (!mounted) return;

      setState(() {
        _userExperience = user;
        _members = members;
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

  Future<void> _openAddMemberDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AddMemberDialog(membersService: _membersService);
      },
    );

    if (created == true) {
      await _loadMembers();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membre ajouté avec succès.')),
      );
    }
  }

  Future<void> _openImportMembersPanel() async {
    final imported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => MemberImportPanel(membersService: _membersService),
    );

    if (imported == true) {
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import membres termine avec succes.')),
      );
    }
  }

  Future<void> _approveMember(MemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Approuver le membre'),
          content: Text(
            'Voulez-vous approuver ${member.displayName} ?\n\n'
            'Son compte passera en statut actif.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: Icon(Icons.check_circle_outline_rounded),
              label: Text('Approuver'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _membersService.approveMember(member.id);
      await _loadMembers();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.displayName} a été approuvé avec succès.'),
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

  Future<void> _rejectMember(MemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rejeter la demande'),
        content: Text(
          'La demande de ${member.displayName} sera rejetée. '
          'Cette action ne supprime pas son dossier.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: Icon(Icons.close_rounded),
            label: Text('Rejeter'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _membersService.rejectMember(member.id);
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demande de ${member.displayName} rejetée.')),
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

  Future<void> _openAssignRoleDialog(MemberModel member) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AssignRoleDialog(
          member: member,
          userExperience: _userExperience,
          membersService: _membersService,
        );
      },
    );

    if (updated == true) {
      await _loadMembers();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rôle assigné à ${member.displayName}.')),
      );
    }
  }

  Future<void> _openLifecycleDialog(MemberModel member) async {
    final choice = await showDialog<_LifecycleChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Gérer ${member.displayName}'),
        children: [
          if (member.status == 'active')
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_LifecycleChoice.makeAlumni),
              child: ListTile(
                leading: Icon(Icons.workspace_premium_outlined),
                title: Text('Passer Alumni'),
                subtitle: Text('Clôture les affectations actives'),
              ),
            ),
          if (member.status != 'suspended' &&
              member.status != 'pending' &&
              member.status != 'rejected')
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_LifecycleChoice.suspend),
              child: ListTile(
                leading: Icon(Icons.person_off_outlined),
                title: Text('Suspendre le compte'),
              ),
            ),
          if (member.status == 'suspended' || member.status == 'inactive')
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_LifecycleChoice.reactivate),
              child: ListTile(
                leading: Icon(Icons.person_add_alt_rounded),
                title: Text('Réactiver le compte'),
              ),
            ),
        ],
      ),
    );
    if (choice == null) return;

    try {
      switch (choice) {
        case _LifecycleChoice.makeAlumni:
          final preview = await _membersService.previewAlumni(member.id);
          if (!mounted) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Préparer le passage Alumni de ${member.displayName}',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview['message'].toString(),
                      style: const TextStyle(height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${(preview['poles'] as List).length} affectations de pôle · ${(preview['projects'] as List).length} affectations de projet à clôturer.',
                    ),
                    const SizedBox(height: 12),
                    for (final task in (preview['pending_tasks'] as List))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Travail à transmettre : ${task['title']}'),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Confirmez que cette personne a terminé ses études. Le dernier niveau d’études ne suffit pas à établir qu’elle est diplômée.',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Préparer le relais d’abord'),
                ),
                FilledButton(
                  onPressed: preview['can_convert'] == true
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('Confirmer le passage Alumni'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await _membersService.makeAlumni(member.id);
          break;
        case _LifecycleChoice.suspend:
          await _membersService.suspendMember(member.id);
          break;
        case _LifecycleChoice.reactivate:
          await _membersService.reactivateMember(member.id);
          break;
      }
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.displayName} a été mis à jour.')),
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

  Future<void> _openAssignDepartmentDialog(MemberModel member) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AssignDepartmentDialog(
          member: member,
          membersService: _membersService,
        );
      },
    );

    if (updated == true) {
      await _loadMembers();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Département ESP mis à jour pour ${member.displayName}.',
          ),
        ),
      );
    }
  }

  Future<void> _openMemberAssignmentSheet(MemberModel member) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return _MemberAssignmentSheet(
          member: member,
          membersService: _membersService,
          polesService: _polesService,
          projectsService: _projectsService,
          canAssignLeadership: _userExperience?.canManageMembers == true,
        );
      },
    );

    if (updated == true) {
      await _loadMembers();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Affectation mise à jour pour ${member.displayName}.'),
        ),
      );
    }
  }

  List<MemberModel> get _filteredMembers {
    final query = _search.trim().toLowerCase();

    return _members.where((member) {
      final matchesSearch =
          query.isEmpty ||
          member.displayName.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query) ||
          member.phoneLabel.toLowerCase().contains(query) ||
          member.departmentLabel.toLowerCase().contains(query) ||
          member.statusLabel.toLowerCase().contains(query) ||
          member.rolesLabel.toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == 'all' || member.status == _statusFilter;
      final matchesRole =
          _roleFilter == 'all' || member.roles.contains(_roleFilter);
      final matchesPole =
          _poleFilter == 'all' || member.department == _poleFilter;
      return matchesSearch && matchesStatus && matchesRole && matchesPole;
    }).toList()..sort(MemberModel.compareAlphabetically);
  }

  int get _activeCount {
    return _members
        .where((m) => !m.isAlumni && m.status == 'active' && m.isActive == true)
        .length;
  }

  int get _pendingCount {
    return _members.where((m) => m.status == 'pending').length;
  }

  Future<void> _openEditMemberDialog(MemberModel member) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) =>
          EditMemberDialog(member: member, membersService: _membersService),
    );
    if (updated != true) return;
    await _loadMembers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${member.displayName} a été mis à jour.')),
    );
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _statusFilter = 'all';
      _roleFilter = 'all';
      _poleFilter = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _filteredMembers;
    final canManageMembers = _userExperience?.canManageMembers == true;
    final canReviewJoinRequests =
        _userExperience?.canReviewJoinRequests == true;
    final canManageLifecycle =
        _userExperience?.isAdmin == true ||
        _userExperience?.isTeamLeader == true;
    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          AppResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MembersHeader(
                  total: _members.length,
                  active: _activeCount,
                  pending: _pendingCount,
                  canManage: canManageMembers,
                  onRefresh: _loadMembers,
                  onAdd: _openAddMemberDialog,
                ),
                if (canManageMembers)
                  OutlinedButton.icon(
                    onPressed: () => context.go('/members/first-access'),
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('Préparer les premières connexions'),
                  ),
                SizedBox(height: 18),
                _SearchAndActions(
                  onChanged: (value) => setState(() => _search = value),
                  statusFilter: _statusFilter,
                  roleFilter: _roleFilter,
                  poleFilter: _poleFilter,
                  poles:
                      _members
                          .map((member) => member.department)
                          .whereType<String>()
                          .where((value) => value.trim().isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(),
                  onStatusChanged: (value) =>
                      setState(() => _statusFilter = value),
                  onRoleChanged: (value) => setState(() => _roleFilter = value),
                  onPoleChanged: (value) => setState(() => _poleFilter = value),
                  onReset: _resetFilters,
                  onImport: canManageMembers ? _openImportMembersPanel : null,
                ),
                SizedBox(height: 18),
                if (_loading)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  _ErrorCard(message: _error!, onRetry: _loadMembers)
                else if (filteredMembers.isEmpty)
                  const _EmptyMembersCard()
                else
                  _MembersList(
                    members: filteredMembers,
                    canManageMembers: canManageMembers,
                    canReviewJoinRequests: canReviewJoinRequests,
                    canManageLifecycle: canManageLifecycle,
                    currentUserId: _userExperience?.id,
                    onApprove: _approveMember,
                    onReject: _rejectMember,
                    onManageLifecycle: _openLifecycleDialog,
                    onAssignRole: _openAssignRoleDialog,
                    onEdit: _openEditMemberDialog,
                    onAssignDepartment: _openAssignDepartmentDialog,
                    onAssignPlacement: _openMemberAssignmentSheet,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersHeader extends StatelessWidget {
  final int total;
  final int active;
  final int pending;
  final bool canManage;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _MembersHeader({
    required this.total,
    required this.active,
    required this.pending,
    required this.canManage,
    required this.onRefresh,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final identity = Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppTheme.enactusYellow,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.people_alt_rounded,
            color: AppTheme.softBlack,
            size: 34,
          ),
        ),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Membres',
                style: TextStyle(
                  color: AppTheme.softBlack,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '$total membre(s) • $active actif(s) • $pending en attente',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AppSecondaryButton(
          label: 'Actualiser',
          icon: Icons.refresh_rounded,
          onPressed: onRefresh,
        ),
        if (canManage)
          AppPrimaryButton(
            label: 'Ajouter',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: onAdd,
          ),
      ],
    );

    return AppDataCard(
      padding: const EdgeInsets.all(26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [identity, SizedBox(height: 18), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _SearchAndActions extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String statusFilter;
  final String roleFilter;
  final String poleFilter;
  final List<String> poles;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onPoleChanged;
  final VoidCallback onReset;
  final VoidCallback? onImport;

  const _SearchAndActions({
    required this.onChanged,
    required this.statusFilter,
    required this.roleFilter,
    required this.poleFilter,
    required this.poles,
    required this.onStatusChanged,
    required this.onRoleChanged,
    required this.onPoleChanged,
    required this.onReset,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1180;

    final searchField = TextField(
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: 'Rechercher un membre',
        hintText: 'Nom, email, téléphone, département...',
        prefixIcon: Icon(Icons.search_rounded),
      ),
    );
    final statusFilterField = DropdownButtonFormField<String>(
      initialValue: statusFilter,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Statut'),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('Tous')),
        DropdownMenuItem(value: 'active', child: Text('Actifs')),
        DropdownMenuItem(value: 'pending', child: Text('En attente')),
        DropdownMenuItem(value: 'inactive', child: Text('Inactifs')),
        DropdownMenuItem(value: 'suspended', child: Text('Suspendus')),
        DropdownMenuItem(value: 'rejected', child: Text('Refusés')),
      ],
      onChanged: (value) {
        if (value != null) onStatusChanged(value);
      },
    );
    final roleFilterField = DropdownButtonFormField<String>(
      initialValue: roleFilter,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Rôle'),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('Tous')),
        DropdownMenuItem(value: 'enacteur', child: Text('Enacteur/Enactrice')),
        DropdownMenuItem(value: 'team_leader', child: Text('Team Leader')),
        DropdownMenuItem(value: 'secretaire_generale', child: Text('SG')),
        DropdownMenuItem(value: 'financier', child: Text('Financier')),
        DropdownMenuItem(value: 'pole_veille', child: Text('Pôle Veille')),
        DropdownMenuItem(value: 'chef_pole', child: Text('Chef pôle')),
        DropdownMenuItem(
          value: 'adjoint_chef_pole',
          child: Text('Adjoint pôle'),
        ),
        DropdownMenuItem(value: 'chef_projet', child: Text('Chef projet')),
        DropdownMenuItem(
          value: 'adjoint_chef_projet',
          child: Text('Adjoint projet'),
        ),
      ],
      onChanged: (value) {
        if (value != null) onRoleChanged(value);
      },
    );
    final poleFilterField = DropdownButtonFormField<String>(
      initialValue: poleFilter,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Département ESP'),
      items: [
        const DropdownMenuItem(
          value: 'all',
          child: Text('Tous les départements'),
        ),
        ...poles.map(
          (pole) => DropdownMenuItem(value: pole, child: Text(pole)),
        ),
      ],
      onChanged: (value) {
        if (value != null) onPoleChanged(value);
      },
    );

    final importButton = onImport == null
        ? null
        : OutlinedButton.icon(
            onPressed: onImport,
            icon: Icon(Icons.upload_file_rounded),
            label: Text('Importer'),
          );

    if (isWide && importButton != null) {
      return Row(
        children: [
          Expanded(child: searchField),
          SizedBox(width: 14),
          SizedBox(width: 145, child: statusFilterField),
          SizedBox(width: 12),
          SizedBox(width: 170, child: roleFilterField),
          SizedBox(width: 14),
          SizedBox(width: 150, child: poleFilterField),
          SizedBox(width: 14),
          importButton,
        ],
      );
    }

    final actionButtons = [?importButton];

    if (actionButtons.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          SizedBox(height: 12),
          AppDataCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              title: Text('Filtres avancés'),
              subtitle: Text('Statut, rôle et département'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                statusFilterField,
                SizedBox(height: 12),
                roleFilterField,
                SizedBox(height: 12),
                poleFilterField,
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onReset,
                    icon: Icon(Icons.restart_alt_rounded),
                    label: Text('Réinitialiser'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        searchField,
        SizedBox(height: 12),
        AppDataCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            title: Text('Filtres avancés'),
            subtitle: Text('Statut, rôle et département'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              statusFilterField,
              SizedBox(height: 12),
              roleFilterField,
              SizedBox(height: 12),
              poleFilterField,
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onReset,
                  icon: Icon(Icons.restart_alt_rounded),
                  label: Text('Réinitialiser'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: actionButtons),
      ],
    );
  }
}

class _MembersList extends StatelessWidget {
  final List<MemberModel> members;
  final bool canManageMembers;
  final bool canReviewJoinRequests;
  final bool canManageLifecycle;
  final String? currentUserId;
  final ValueChanged<MemberModel> onApprove;
  final ValueChanged<MemberModel> onReject;
  final ValueChanged<MemberModel> onManageLifecycle;
  final ValueChanged<MemberModel> onAssignRole;
  final ValueChanged<MemberModel> onEdit;
  final ValueChanged<MemberModel> onAssignDepartment;
  final ValueChanged<MemberModel> onAssignPlacement;

  const _MembersList({
    required this.members,
    required this.canManageMembers,
    required this.canReviewJoinRequests,
    required this.canManageLifecycle,
    required this.currentUserId,
    required this.onApprove,
    required this.onReject,
    required this.onManageLifecycle,
    required this.onAssignRole,
    required this.onEdit,
    required this.onAssignDepartment,
    required this.onAssignPlacement,
  });

  @override
  Widget build(BuildContext context) {
    // The desktop shell reserves a navigation rail. Keep primary actions on
    // screen below ultra-wide widths by using the responsive member cards.
    final isWide = MediaQuery.of(context).size.width >= 1600;

    if (isWide) {
      return Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: canManageMembers ? 1640 : 1450,
            child: DataTable(
              columnSpacing: 28,
              horizontalMargin: 24,
              headingRowHeight: 52,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 66,
              columns: const [
                DataColumn(label: Text('Membre')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Statut')),
                DataColumn(label: Text('Rôles')),
                DataColumn(label: Text('Département ESP')),
                DataColumn(label: Text('Actif')),
                DataColumn(label: Text('Email vérifié')),
                DataColumn(label: Text('Actions')),
              ],
              rows: members.map((member) {
                return DataRow(
                  cells: [
                    DataCell(_MemberIdentity(member: member)),

                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          member.email,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    DataCell(_StatusChip(member: member)),

                    DataCell(
                      SizedBox(
                        width: 170,
                        child: Text(
                          member.rolesLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Text(
                          member.departmentLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    DataCell(_BooleanChip(value: member.isActive)),

                    DataCell(_BooleanChip(value: member.emailVerified)),

                    DataCell(
                      SizedBox(
                        width: canManageMembers ? 350 : 160,
                        child: Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  _showMemberDetails(context, member),
                              icon: Icon(Icons.visibility_rounded),
                              label: Text('Profil'),
                            ),
                            if (canManageMembers)
                              TextButton.icon(
                                onPressed: () => onEdit(member),
                                icon: Icon(Icons.edit_outlined),
                                label: Text('Modifier'),
                              ),
                            if (canManageMembers) ...[
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => onAssignRole(member),
                                icon: Icon(Icons.admin_panel_settings_rounded),
                                tooltip: 'Assigner rôle',
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => onAssignDepartment(member),
                                icon: Icon(Icons.account_tree_rounded),
                                tooltip: 'Assigner le département ESP',
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => onAssignPlacement(member),
                                icon: Icon(Icons.hub_rounded),
                                tooltip: 'Affecter',
                              ),
                            ],
                            if (canReviewJoinRequests &&
                                member.status == 'pending') ...[
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => onApprove(member),
                                icon: Icon(Icons.verified_user_rounded),
                                tooltip: 'Approuver',
                                color: Colors.green,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => onReject(member),
                                icon: Icon(Icons.cancel_outlined),
                                tooltip: 'Rejeter',
                                color: Colors.red,
                              ),
                            ],
                            if (canManageLifecycle &&
                                member.id != currentUserId &&
                                const {
                                  'active',
                                  'alumni',
                                  'suspended',
                                  'inactive',
                                }.contains(member.status))
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => onManageLifecycle(member),
                                icon: Icon(Icons.manage_accounts_outlined),
                                tooltip: 'Gérer le compte',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 820 ? 2 : 1;
        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final member in members)
              SizedBox(
                width: cardWidth,
                child: _MemberCard(
                  member: member,
                  canManageMembers: canManageMembers,
                  canReviewJoinRequests: canReviewJoinRequests,
                  canManageLifecycle:
                      canManageLifecycle &&
                      member.id != currentUserId &&
                      const {
                        'active',
                        'alumni',
                        'suspended',
                        'inactive',
                      }.contains(member.status),
                  onDetails: () => _showMemberDetails(context, member),
                  onApprove: member.status == 'pending'
                      ? () => onApprove(member)
                      : null,
                  onReject: member.status == 'pending'
                      ? () => onReject(member)
                      : null,
                  onManageLifecycle: () => onManageLifecycle(member),
                  onAssignRole: () => onAssignRole(member),
                  onEdit: onEdit,
                  onAssignDepartment: () => onAssignDepartment(member),
                  onAssignPlacement: () => onAssignPlacement(member),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showMemberDetails(BuildContext context, MemberModel member) {
    if (member.id.trim().isNotEmpty) {
      context.go('/members/${Uri.encodeComponent(member.id)}');
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(
                      name: member.displayName,
                      photoUrl: member.photoUrl,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _StatusChip(member: member),
                              Chip(label: Text(member.primaryRoleLabel)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                const AppSectionHeader(title: 'Contact'),
                SizedBox(height: 10),
                _DetailLine(label: 'Email', value: member.email),
                _DetailLine(label: 'Téléphone', value: member.phoneLabel),
                SizedBox(height: 8),
                const AppSectionHeader(title: 'Organisation'),
                SizedBox(height: 10),
                _DetailLine(label: 'Statut', value: member.statusLabel),
                _DetailLine(label: 'Profil', value: member.memberLabel),
                _DetailLine(
                  label: 'Rôle principal',
                  value: member.primaryRoleLabel,
                ),
                _DetailLine(label: 'Rôles', value: member.rolesLabel),
                _DetailLine(
                  label: 'Département ESP',
                  value: member.departmentLabel,
                ),
                SizedBox(height: 8),
                const AppSectionHeader(title: 'Parcours'),
                SizedBox(height: 10),
                _DetailLine(label: 'Niveau', value: member.studyLevelLabel),
                _DetailLine(label: 'Promotion', value: member.promotionLabel),
                _DetailLine(label: 'Adhésion', value: member.joinedAtLabel),
                _DetailLine(label: 'Bio', value: member.bioLabel),
                SizedBox(height: 12),
                const AppSectionHeader(title: 'Jeux du club'),
                FutureBuilder<Map<String, dynamic>>(
                  future: GamesService().profile(member.id),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    if (data == null) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['wins']} victoire(s) · ${data['points']} points · ${data['games']} partie(s)',
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final badge in (data['badges'] as List))
                              Chip(
                                avatar: Icon(
                                  Icons.emoji_events_outlined,
                                  size: 17,
                                ),
                                label: Text('$badge'),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: 8),
                const AppSectionHeader(title: 'État du compte'),
                SizedBox(height: 10),
                _DetailLine(
                  label: 'Actif',
                  value: member.isActive == true ? 'Oui' : 'Non',
                ),
                _DetailLine(
                  label: 'Email vérifié',
                  value: member.emailVerified == true ? 'Oui' : 'Non',
                ),
                _DetailLine(label: 'ID', value: member.id),
                SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('member_memory_link'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(
                      '/archives?member_id=${Uri.encodeQueryComponent(member.id)}',
                    );
                  },
                  icon: Icon(Icons.history),
                  label: Text('Voir dans la mémoire'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MemberIdentity extends StatelessWidget {
  final MemberModel member;

  const _MemberIdentity({required this.member});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(name: member.displayName, photoUrl: member.photoUrl),
        SizedBox(width: 10),
        Text(member.displayName, style: TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final MemberModel member;
  final bool canManageMembers;
  final bool canReviewJoinRequests;
  final bool canManageLifecycle;
  final VoidCallback onDetails;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback onManageLifecycle;
  final VoidCallback onAssignRole;
  final ValueChanged<MemberModel> onEdit;
  final VoidCallback onAssignDepartment;
  final VoidCallback onAssignPlacement;

  const _MemberCard({
    required this.member,
    required this.canManageMembers,
    required this.canReviewJoinRequests,
    required this.canManageLifecycle,
    required this.onDetails,
    required this.onApprove,
    required this.onReject,
    required this.onManageLifecycle,
    required this.onAssignRole,
    required this.onEdit,
    required this.onAssignDepartment,
    required this.onAssignPlacement,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(name: member.displayName, photoUrl: member.photoUrl),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        member.email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompact)
                  PopupMenuButton<_MemberAction>(
                    tooltip: 'Actions du membre',
                    onSelected: (action) {
                      switch (action) {
                        case _MemberAction.details:
                          onDetails();
                          break;
                        case _MemberAction.assignRole:
                          onAssignRole();
                          break;
                        case _MemberAction.assignDepartment:
                          onAssignDepartment();
                          break;
                        case _MemberAction.assignPlacement:
                          onAssignPlacement();
                          break;
                        case _MemberAction.approve:
                          onApprove?.call();
                          break;
                        case _MemberAction.reject:
                          onReject?.call();
                          break;
                        case _MemberAction.manageLifecycle:
                          onManageLifecycle();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _MemberAction.details,
                        child: ListTile(
                          leading: Icon(Icons.visibility_rounded),
                          title: Text('Voir le profil'),
                        ),
                      ),
                      if (canManageMembers) ...[
                        const PopupMenuItem(
                          value: _MemberAction.assignRole,
                          child: ListTile(
                            leading: Icon(Icons.admin_panel_settings_rounded),
                            title: Text('Assigner un rôle'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _MemberAction.assignDepartment,
                          child: ListTile(
                            leading: Icon(Icons.account_balance_outlined),
                            title: Text('Assigner le département ESP'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _MemberAction.assignPlacement,
                          child: ListTile(
                            leading: Icon(Icons.hub_rounded),
                            title: Text('Affecter pôle/projet'),
                          ),
                        ),
                      ],
                      if (canReviewJoinRequests && onApprove != null) ...[
                        const PopupMenuItem(
                          value: _MemberAction.approve,
                          child: ListTile(
                            leading: Icon(
                              Icons.verified_user_rounded,
                              color: Colors.green,
                            ),
                            title: Text('Approuver'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _MemberAction.reject,
                          child: ListTile(
                            leading: Icon(
                              Icons.cancel_outlined,
                              color: Colors.red,
                            ),
                            title: Text('Rejeter'),
                          ),
                        ),
                      ],
                      if (canManageLifecycle)
                        const PopupMenuItem(
                          value: _MemberAction.manageLifecycle,
                          child: ListTile(
                            leading: Icon(Icons.manage_accounts_outlined),
                            title: Text('Gérer le compte'),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatusChip(member: member),
                _SoftInfoChip(
                  icon: Icons.badge_rounded,
                  label: member.primaryRoleLabel,
                ),
                _DepartmentChip(department: member.departmentLabel),
              ],
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onDetails,
                  icon: Icon(Icons.visibility_rounded),
                  label: Text('Voir le profil'),
                ),
                if (canManageMembers)
                  TextButton.icon(
                    onPressed: () => onEdit(member),
                    icon: Icon(Icons.edit_outlined),
                    label: Text('Modifier'),
                  ),
              ],
            ),
            SizedBox(height: 12),
            if (!isCompact) ...[
              const Divider(height: 20),
              Wrap(
                spacing: 4,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (canManageMembers) ...[
                    IconButton(
                      onPressed: onAssignRole,
                      icon: Icon(Icons.admin_panel_settings_rounded),
                      tooltip: 'Assigner rôle',
                    ),
                    IconButton(
                      onPressed: onAssignDepartment,
                      icon: Icon(Icons.account_tree_rounded),
                      tooltip: 'Assigner le département ESP',
                    ),
                    IconButton(
                      onPressed: onAssignPlacement,
                      icon: Icon(Icons.hub_rounded),
                      tooltip: 'Affecter pôle/projet',
                    ),
                  ],
                  if (canReviewJoinRequests && onApprove != null) ...[
                    FilledButton.icon(
                      onPressed: onApprove,
                      icon: Icon(Icons.verified_user_rounded),
                      label: Text('Approuver'),
                    ),
                    IconButton(
                      onPressed: onReject,
                      icon: Icon(Icons.cancel_outlined),
                      color: Colors.red,
                      tooltip: 'Rejeter',
                    ),
                  ],
                  if (canManageLifecycle)
                    IconButton(
                      onPressed: onManageLifecycle,
                      icon: Icon(Icons.manage_accounts_outlined),
                      tooltip: 'Gérer le compte',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _Avatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final imageUrl = _absoluteMemberPhotoUrl(photoUrl);

    return CircleAvatar(
      backgroundColor: AppTheme.enactusYellow,
      foregroundColor: AppTheme.softBlack,
      backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
      child: imageUrl == null
          ? Text(initial, style: TextStyle(fontWeight: FontWeight.w900))
          : null,
    );
  }
}

enum _MemberAction {
  details,
  assignRole,
  assignDepartment,
  assignPlacement,
  approve,
  reject,
  manageLifecycle,
}

enum _LifecycleChoice { makeAlumni, suspend, reactivate }

enum _AssignmentMode { corePole, pole, project }

String? _absoluteMemberPhotoUrl(String? value) {
  final url = value?.trim();
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${ApiClient.serverUrl}${url.startsWith('/') ? '' : '/'}$url';
}

(Color, Color) _memberAccentColors(BuildContext context, Color accent) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return (
    accent.withValues(alpha: dark ? 0.24 : 0.12),
    dark ? Color.lerp(accent, Colors.white, 0.48)! : accent,
  );
}

class _StatusChip extends StatelessWidget {
  final MemberModel member;

  const _StatusChip({required this.member});

  @override
  Widget build(BuildContext context) {
    final isActive = !member.isAlumni &&
        member.status == 'active' && member.isActive == true;
    final isPending = member.status == 'pending';

    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = isActive
        ? _memberAccentColors(context, AppTheme.success)
        : isPending
        ? _memberAccentColors(context, AppTheme.warning)
        : (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);

    return Chip(
      label: SizedBox(
        width: 90,
        child: Text(
          member.statusLabel,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      side: BorderSide(color: foreground.withValues(alpha: 0.2)),
    );
  }
}

class _BooleanChip extends StatelessWidget {
  final bool? value;

  const _BooleanChip({required this.value});

  @override
  Widget build(BuildContext context) {
    final isTrue = value == true;
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = isTrue
        ? _memberAccentColors(context, AppTheme.success)
        : (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);

    return Chip(
      label: SizedBox(
        width: 36,
        child: Text(isTrue ? 'Oui' : 'Non', textAlign: TextAlign.center),
      ),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      side: BorderSide.none,
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
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
            SizedBox(height: 12),
            Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMembersCard extends StatelessWidget {
  const _EmptyMembersCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(26),
        child: Center(
          child: Text(
            'Aucun membre trouvé.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

double _dialogWidth(BuildContext context, double maxWidth) {
  return (MediaQuery.sizeOf(context).width - 32).clamp(280.0, maxWidth);
}

class AddMemberDialog extends StatefulWidget {
  final MembersService membersService;

  const AddMemberDialog({super.key, required this.membersService});

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.membersService.createMember(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
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
    return AppFormDialog(
      icon: Icons.person_add_alt_1_rounded,
      description: 'Créez le profil d’un nouvel enacteur.',
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('Ajouter un membre'),
      content: SizedBox(
        width: _dialogWidth(context, 460),
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
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Prénom',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le prénom est obligatoire.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est obligatoire.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'L’email est obligatoire.';
                    }

                    if (!email.contains('@')) {
                      return 'Email invalide.';
                    }

                    return null;
                  },
                ),
                SizedBox(height: 14),
                const Text(
                  'Après validation du compte, le membre recevra un code personnel pour choisir son mot de passe.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.person_add_alt_1_rounded),
          label: Text(_loading ? 'Création...' : 'Créer'),
        ),
      ],
    );
  }
}

class _SoftInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
      backgroundColor: scheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: scheme.outlineVariant),
    );
  }
}

class AssignRoleDialog extends StatefulWidget {
  final MemberModel member;
  final UserExperience? userExperience;
  final MembersService membersService;

  const AssignRoleDialog({
    super.key,
    required this.member,
    required this.userExperience,
    required this.membersService,
  });

  @override
  State<AssignRoleDialog> createState() => _AssignRoleDialogState();
}

class _AssignRoleDialogState extends State<AssignRoleDialog> {
  late final Set<String> _selectedRoles;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedRoles = {
      ...widget.member.roles.where(_availableRoles.contains),
      if (widget.member.status != 'alumni') 'enacteur',
    };
  }

  List<String> get _availableRoles {
    final user = widget.userExperience;

    if (user?.isAdmin == true) {
      return const [
        'administrateur',
        'team_leader',
        'secretaire_generale',
        'financier',
        'faculty_advisor',
        'pole_veille',
        'enacteur',
      ];
    }

    if (user?.isTeamLeader == true) {
      return const [
        'secretaire_generale',
        'financier',
        'faculty_advisor',
        'pole_veille',
        'enacteur',
      ];
    }

    if (user?.isSecretary == true) {
      return const ['financier', 'enacteur'];
    }

    return const ['enacteur'];
  }

  Future<void> _submit() async {
    if (_selectedRoles.isEmpty) {
      setState(() {
        _error = 'Sélectionnez au moins un rôle.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.membersService.assignRoles(
        userId: widget.member.id,
        roleNames: _selectedRoles.toList(),
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

  String _labelForRole(String role) {
    switch (role) {
      case 'team_leader':
        return 'Team Leader';
      case 'secretaire_generale':
        return 'Secrétaire Générale';
      case 'administrateur':
        return 'Administrateur';
      case 'financier':
        return 'Financier';
      case 'pole_veille':
        return 'Pôle Veille';
      case 'chef_pole':
        return 'Chef de pôle';
      case 'chef_projet':
        return 'Chef de projet';
      case 'adjoint_chef_pole':
        return 'Adjoint pôle';
      case 'adjoint_chef_projet':
        return 'Adjoint projet';
      case 'faculty_advisor':
        return 'Faculty Advisor';
      case 'enacteur':
        return widget.member.memberLabel;
      case 'alumni':
        return 'Alumni';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('Assigner un rôle'),
      content: SizedBox(
        width: _dialogWidth(context, 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.member.displayName,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              SizedBox(height: 4),
              Text(
                widget.member.email,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Les chefs et adjoints sont nommés depuis les modules '
                'Pôles et Projets afin de conserver leur périmètre.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 14),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableRoles.map((role) {
                  final selected = _selectedRoles.contains(role);

                  return FilterChip(
                    selected: selected,
                    label: Text(_labelForRole(role)),
                    onSelected: _loading
                        ? null
                        : (value) {
                            setState(() {
                              if (value) {
                                _selectedRoles.add(role);
                              } else {
                                _selectedRoles.remove(role);
                              }
                            });
                          },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.save_rounded),
          label: Text(_loading ? 'Enregistrement...' : 'Enregistrer'),
        ),
      ],
    );
  }
}

class _DepartmentChip extends StatelessWidget {
  final String department;

  const _DepartmentChip({required this.department});

  @override
  Widget build(BuildContext context) {
    final defined =
        department.trim().isNotEmpty &&
        !department.toLowerCase().contains('non ');

    final scheme = Theme.of(context).colorScheme;
    final background = defined
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = defined
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return Chip(
      label: SizedBox(
        width: 120,
        child: Text(
          department,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      side: BorderSide(color: scheme.outlineVariant),
    );
  }
}

class _MemberAssignmentSheet extends StatefulWidget {
  final MemberModel member;
  final MembersService membersService;
  final PolesService polesService;
  final ProjectsService projectsService;
  final bool canAssignLeadership;

  const _MemberAssignmentSheet({
    required this.member,
    required this.membersService,
    required this.polesService,
    required this.projectsService,
    required this.canAssignLeadership,
  });

  @override
  State<_MemberAssignmentSheet> createState() => _MemberAssignmentSheetState();
}

class _MemberAssignmentSheetState extends State<_MemberAssignmentSheet> {
  _AssignmentMode _mode = _AssignmentMode.corePole;
  List<PoleModel> _poles = [];
  List<ProjectModel> _projects = [];
  String? _selectedCorePoleId;
  String? _selectedPoleId;
  String? _selectedProjectId;
  String _polePosition = 'membre';
  String _projectPosition = 'membre';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.polesService.getPoles(),
        widget.projectsService.getProjects(),
      ]);
      final poles = results[0] as List<PoleModel>;
      final projects = results[1] as List<ProjectModel>;

      if (!mounted) return;

      setState(() {
        _poles = poles;
        _projects = projects;
        _selectedCorePoleId = _corePoles.isNotEmpty
            ? _corePoles.first.id
            : null;
        _selectedPoleId = poles.isNotEmpty ? poles.first.id : null;
        _selectedProjectId = projects.isNotEmpty ? projects.first.id : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PoleModel> get _corePoles {
    final core = _poles.where((pole) => pole.isCorePole).toList();
    return core.isEmpty ? _poles : core;
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      switch (_mode) {
        case _AssignmentMode.corePole:
          final pole = _findPole(_selectedCorePoleId, _corePoles);
          if (pole == null) {
            throw Exception('Sélectionnez un pôle cœur.');
          }
          await widget.polesService.assignMember(
            poleId: pole.id,
            userId: widget.member.id,
            position: 'membre',
          );
          break;
        case _AssignmentMode.pole:
          final pole = _findPole(_selectedPoleId, _poles);
          if (pole == null) {
            throw Exception('Sélectionnez un pôle.');
          }
          await widget.polesService.assignMember(
            poleId: pole.id,
            userId: widget.member.id,
            position: _polePosition,
          );
          break;
        case _AssignmentMode.project:
          final project = _findProject(_selectedProjectId, _projects);
          if (project == null) {
            throw Exception('Sélectionnez un projet.');
          }
          await widget.projectsService.assignMember(
            projectId: project.id,
            userId: widget.member.id,
            position: _projectPosition,
          );
          break;
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final corePoles = _corePoles;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Affecter ${widget.member.displayName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'Choisissez le type d’affectation puis la cible.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 18),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<_AssignmentMode>(
                    initialValue: _mode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      prefixIcon: Icon(Icons.route_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _AssignmentMode.corePole,
                        child: Text('Pôle cœur principal'),
                      ),
                      DropdownMenuItem(
                        value: _AssignmentMode.pole,
                        child: Text('Rattachement pôle'),
                      ),
                      DropdownMenuItem(
                        value: _AssignmentMode.project,
                        child: Text('Rattachement projet'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _mode = value);
                          },
                  ),
                  SizedBox(height: 14),
                  if (_mode == _AssignmentMode.corePole)
                    _PoleTargetField(
                      value: _selectedCorePoleId,
                      poles: corePoles,
                      label: 'Pôle cœur',
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _selectedCorePoleId = value;
                            }),
                    )
                  else if (_mode == _AssignmentMode.pole) ...[
                    _PoleTargetField(
                      value: _selectedPoleId,
                      poles: _poles,
                      label: 'Pôle',
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _selectedPoleId = value;
                            }),
                    ),
                    SizedBox(height: 14),
                    _PositionField(
                      value: _polePosition,
                      canAssignLeadership: widget.canAssignLeadership,
                      leaderValue: 'chef_pole',
                      deputyValue: 'adjoint_chef_pole',
                      leaderLabel: 'Chef de pôle',
                      deputyLabel: 'Adjoint chef de pôle',
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _polePosition = value;
                            }),
                    ),
                  ] else ...[
                    _ProjectTargetField(
                      value: _selectedProjectId,
                      projects: _projects,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _selectedProjectId = value;
                            }),
                    ),
                    SizedBox(height: 14),
                    _PositionField(
                      value: _projectPosition,
                      canAssignLeadership: widget.canAssignLeadership,
                      leaderValue: 'chef_projet',
                      deputyValue: 'adjoint_chef_projet',
                      leaderLabel: 'Chef de projet',
                      deputyLabel: 'Adjoint chef de projet',
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _projectPosition = value;
                            }),
                    ),
                  ],
                  SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.save_rounded),
                    label: Text('Enregistrer l’affectation'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  PoleModel? _findPole(String? id, List<PoleModel> poles) {
    if (id == null) return null;
    for (final pole in poles) {
      if (pole.id == id) return pole;
    }
    return null;
  }

  ProjectModel? _findProject(String? id, List<ProjectModel> projects) {
    if (id == null) return null;
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }
}

class _PoleTargetField extends StatelessWidget {
  final String? value;
  final List<PoleModel> poles;
  final String label;
  final ValueChanged<String?>? onChanged;

  const _PoleTargetField({
    required this.value,
    required this.poles,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.account_tree_rounded),
      ),
      items: [
        for (final pole in poles)
          DropdownMenuItem(
            value: pole.id,
            child: Text(
              '${pole.name} · ${pole.typeLabel}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ProjectTargetField extends StatelessWidget {
  final String? value;
  final List<ProjectModel> projects;
  final ValueChanged<String?>? onChanged;

  const _ProjectTargetField({
    required this.value,
    required this.projects,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Projet',
        prefixIcon: Icon(Icons.rocket_launch_rounded),
      ),
      items: [
        for (final project in projects)
          DropdownMenuItem(
            value: project.id,
            child: Text(
              '${project.name} · ${project.statusLabel}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _PositionField extends StatelessWidget {
  final String value;
  final bool canAssignLeadership;
  final String leaderValue;
  final String deputyValue;
  final String leaderLabel;
  final String deputyLabel;
  final ValueChanged<String>? onChanged;

  const _PositionField({
    required this.value,
    required this.canAssignLeadership,
    required this.leaderValue,
    required this.deputyValue,
    required this.leaderLabel,
    required this.deputyLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Position',
        prefixIcon: Icon(Icons.admin_panel_settings_rounded),
      ),
      items: [
        const DropdownMenuItem(value: 'membre', child: Text('Membre')),
        if (canAssignLeadership)
          DropdownMenuItem(value: deputyValue, child: Text(deputyLabel)),
        if (canAssignLeadership)
          DropdownMenuItem(value: leaderValue, child: Text(leaderLabel)),
      ],
      onChanged: (value) {
        if (value != null) onChanged?.call(value);
      },
    );
  }
}

class AssignDepartmentDialog extends StatefulWidget {
  final MemberModel member;
  final MembersService membersService;

  const AssignDepartmentDialog({
    super.key,
    required this.member,
    required this.membersService,
  });

  @override
  State<AssignDepartmentDialog> createState() => _AssignDepartmentDialogState();
}

class _AssignDepartmentDialogState extends State<AssignDepartmentDialog> {
  static const List<String> _departments = espAcademicDepartments;

  String? _selectedDepartment;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final current = widget.member.department;

    if (current != null && current.trim().isNotEmpty) {
      _selectedDepartment = current;
    }
  }

  Future<void> _submit() async {
    if (_selectedDepartment == null || _selectedDepartment!.trim().isEmpty) {
      setState(() {
        _error = 'Sélectionnez un département ESP.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.membersService.updateMemberAdmin(
        userId: widget.member.id,
        department: _selectedDepartment,
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
      title: Text('Assigner le département ESP'),
      content: SizedBox(
        width: _dialogWidth(context, 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.member.displayName,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            SizedBox(height: 4),
            Text(
              widget.member.email,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 18),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _selectedDepartment,
              decoration: const InputDecoration(
                labelText: 'Département ESP',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              items: _departments.map((department) {
                return DropdownMenuItem<String>(
                  value: department,
                  child: Text(department),
                );
              }).toList(),
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedDepartment = value;
                      });
                    },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.save_rounded),
          label: Text(_loading ? 'Enregistrement...' : 'Enregistrer'),
        ),
      ],
    );
  }
}

class EditMemberDialog extends StatefulWidget {
  const EditMemberDialog({
    super.key,
    required this.member,
    required this.membersService,
  });

  final MemberModel member;
  final MembersService membersService;

  @override
  State<EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<EditMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  bool _loading = false;
  String? _error;
  static const _labels = {
    'first_name': 'Prénom', 'last_name': 'Nom', 'email': 'Adresse e-mail',
    'phone': 'Téléphone', 'department': 'Département ESP', 'cursus': 'Cursus',
    'study_level': 'Niveau d’études', 'specialty': 'Spécialité',
    'promotion': 'Promotion', 'enactus_join_year': 'Année d’entrée à Enactus ESP',
    'bio': 'Présentation', 'linkedin_url': 'LinkedIn', 'github_url': 'GitHub',
    'portfolio_url': 'Portfolio',
  };
  @override
  void initState() {
    super.initState();
    final m = widget.member;
    final values = {
      'first_name': m.firstName, 'last_name': m.lastName, 'email': m.email,
      'phone': m.phone, 'department': m.department, 'cursus': m.cursus,
      'study_level': m.studyLevel, 'specialty': m.specialty,
      'promotion': m.promotion, 'enactus_join_year': m.enactusJoinYear?.toString(),
      'bio': m.bio, 'linkedin_url': m.linkedinUrl, 'github_url': m.githubUrl,
      'portfolio_url': m.portfolioUrl,
    };
    _fields = values.map((key, value) => MapEntry(key, TextEditingController(text: value ?? '')));
  }
  @override
  void dispose() {
    for (final controller in _fields.values) { controller.dispose(); }
    super.dispose();
  }
  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = <String, dynamic>{
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      };
      data['enactus_join_year'] = int.tryParse(_fields['enactus_join_year']!.text.trim());
      await widget.membersService.updateMemberAdmin(userId: widget.member.id, profileData: data);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_loading,
    child: AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Compléter les informations'),
      content: SizedBox(
        width: _dialogWidth(context, 520),
        child: SingleChildScrollView(
          child: Form(key: _formKey, child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const Text('Une nouvelle adresse e-mail devra être vérifiée par son titulaire.'),
              const SizedBox(height: 16),
              for (final entry in _labels.entries) ...[
                TextFormField(
                  controller: _fields[entry.key], enabled: !_loading,
                  decoration: InputDecoration(labelText: entry.value),
                  maxLines: entry.key == 'bio' ? 3 : 1,
                  keyboardType: entry.key == 'email' ? TextInputType.emailAddress
                    : entry.key == 'phone' ? TextInputType.phone
                    : entry.key == 'enactus_join_year' ? TextInputType.number : TextInputType.text,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if ({'first_name', 'last_name', 'email'}.contains(entry.key) && text.isEmpty) return 'Ce champ est obligatoire.';
                    if (entry.key == 'email' && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) return 'Adresse e-mail invalide.';
                    if (entry.key == 'enactus_join_year' && text.isNotEmpty) {
                      final year = int.tryParse(text);
                      if (year == null || year < 1900 || year > DateTime.now().year) return 'Indiquez une année valide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          )),
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
        ElevatedButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Enregistrement…' : 'Enregistrer')),
      ],
    ),
  );
}
