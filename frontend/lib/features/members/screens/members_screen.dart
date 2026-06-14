import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/member_model.dart';
import '../services/members_service.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final MembersService _membersService = MembersService();

  bool _loading = true;
  String? _error;
  List<MemberModel> _members = [];
  String _search = '';

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
      final members = await _membersService.getMembers();

      if (!mounted) return;

      setState(() {
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

  Future<void> _approveMember(MemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Approuver le membre'),
          content: Text(
            'Voulez-vous approuver ${member.displayName} ?\n\n'
            'Son compte passera en statut actif.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Approuver'),
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

  Future<void> _openAssignRoleDialog(MemberModel member) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AssignRoleDialog(
          member: member,
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
          content: Text('Pôle cœur mis à jour pour ${member.displayName}.'),
        ),
      );
    }
  }

  List<MemberModel> get _filteredMembers {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) return _members;

    return _members.where((member) {
      return member.displayName.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query) ||
          member.statusLabel.toLowerCase().contains(query);
    }).toList();
  }

  int get _activeCount {
    return _members
        .where((m) => m.status == 'active' || m.isActive == true)
        .length;
  }

  int get _pendingCount {
    return _members.where((m) => m.status == 'pending').length;
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _filteredMembers;

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _MembersHeader(
            total: _members.length,
            active: _activeCount,
            pending: _pendingCount,
            onRefresh: _loadMembers,
          ),
          const SizedBox(height: 20),
          _SearchAndActions(
            onChanged: (value) {
              setState(() {
                _search = value;
              });
            },
            onAdd: _openAddMemberDialog,
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
            _ErrorCard(message: _error!, onRetry: _loadMembers)
          else if (filteredMembers.isEmpty)
            const _EmptyMembersCard()
          else
            _MembersList(
              members: filteredMembers,
              onApprove: _approveMember,
              onAssignRole: _openAssignRoleDialog,
              onAssignDepartment: _openAssignDepartmentDialog,
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
  final VoidCallback onRefresh;

  const _MembersHeader({
    required this.total,
    required this.active,
    required this.pending,
    required this.onRefresh,
  });

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
              Icons.people_alt_rounded,
              color: AppTheme.softBlack,
              size: 34,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Membres',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$total membre(s) • $active actif(s) • $pending en attente',
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SearchAndActions extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onAdd;

  const _SearchAndActions({required this.onChanged, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    final searchField = TextField(
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: 'Rechercher un membre',
        hintText: 'Nom, email, statut...',
        prefixIcon: Icon(Icons.search_rounded),
      ),
    );

    final addButton = ElevatedButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text('Ajouter'),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: searchField),
          const SizedBox(width: 14),
          addButton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [searchField, const SizedBox(height: 12), addButton],
    );
  }
}

class _MembersList extends StatelessWidget {
  final List<MemberModel> members;
  final ValueChanged<MemberModel> onApprove;
  final ValueChanged<MemberModel> onAssignRole;
  final ValueChanged<MemberModel> onAssignDepartment;

  const _MembersList({
    required this.members,
    required this.onApprove,
    required this.onAssignRole,
    required this.onAssignDepartment,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1200;

    if (isWide) {
      return Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1450,
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
                DataColumn(label: Text('Pôle cœur')),
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
                        width: 180,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _showMemberDetails(context, member);
                              },
                              icon: const Icon(Icons.visibility_rounded),
                              tooltip: 'Voir',
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () => onAssignRole(member),
                              icon: const Icon(
                                Icons.admin_panel_settings_rounded,
                              ),
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
                              icon: const Icon(Icons.account_tree_rounded),
                              tooltip: 'Assigner pôle cœur',
                            ),
                            if (member.status == 'pending')
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => onApprove(member),
                                icon: const Icon(Icons.verified_user_rounded),
                                tooltip: 'Approuver',
                                color: Colors.green,
                              ),
                            IconButton(
                              onPressed: () => onAssignDepartment(member),
                              icon: const Icon(Icons.account_tree_rounded),
                              tooltip: 'Assigner pôle cœur',
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

    return Column(
      children: members.map((member) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Avatar(name: member.displayName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _StatusChip(member: member),
                          _BooleanChip(value: member.emailVerified),
                          _RolesChip(roles: member.roles),
                          _DepartmentChip(department: member.departmentLabel),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _showMemberDetails(context, member),
                      icon: const Icon(Icons.visibility_rounded),
                      tooltip: 'Voir',
                    ),
                    if (member.status == 'pending')
                      IconButton(
                        onPressed: () => onApprove(member),
                        icon: const Icon(Icons.verified_user_rounded),
                        tooltip: 'Approuver',
                        color: Colors.green,
                      ),
                    IconButton(
                      onPressed: () => onAssignRole(member),
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                      tooltip: 'Assigner rôle',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showMemberDetails(BuildContext context, MemberModel member) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(name: member.displayName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      member.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailLine(label: 'Email', value: member.email),
              _DetailLine(label: 'Statut', value: member.statusLabel),
              _DetailLine(
                label: 'Actif',
                value: member.isActive == true ? 'Oui' : 'Non',
              ),
              _DetailLine(
                label: 'Email vérifié',
                value: member.emailVerified == true ? 'Oui' : 'Non',
              ),
              _DetailLine(label: 'ID', value: member.id),
            ],
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
        _Avatar(name: member.displayName),
        const SizedBox(width: 10),
        Text(
          member.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return CircleAvatar(
      backgroundColor: AppTheme.enactusYellow,
      foregroundColor: AppTheme.softBlack,
      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MemberModel member;

  const _StatusChip({required this.member});

  @override
  Widget build(BuildContext context) {
    final isActive = member.status == 'active' || member.isActive == true;
    final isPending = member.status == 'pending';

    Color background;
    Color foreground;

    if (isActive) {
      background = Colors.green.shade50;
      foreground = Colors.green.shade700;
    } else if (isPending) {
      background = Colors.orange.shade50;
      foreground = Colors.orange.shade800;
    } else {
      background = Colors.grey.shade100;
      foreground = Colors.grey.shade700;
    }

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

    return Chip(
      label: SizedBox(
        width: 36,
        child: Text(isTrue ? 'Oui' : 'Non', textAlign: TextAlign.center),
      ),
      backgroundColor: isTrue ? Colors.green.shade50 : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isTrue ? Colors.green.shade700 : Colors.grey.shade700,
        fontWeight: FontWeight.w700,
      ),
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
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
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

class _EmptyMembersCard extends StatelessWidget {
  const _EmptyMembersCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(26),
        child: Center(
          child: Text(
            'Aucun membre trouvé.',
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
  final _passwordController = TextEditingController(text: 'Test12345');

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
        password: _passwordController.text,
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
      title: const Text('Ajouter un membre'),
      content: SizedBox(
        width: 460,
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
                const SizedBox(height: 14),
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
                const SizedBox(height: 14),
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe temporaire',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final password = value?.trim() ?? '';

                    if (password.length < 8) {
                      return 'Le mot de passe doit contenir au moins 8 caractères.';
                    }

                    return null;
                  },
                  onFieldSubmitted: (_) => _loading ? null : _submit(),
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
              : const Icon(Icons.person_add_alt_1_rounded),
          label: Text(_loading ? 'Création...' : 'Créer'),
        ),
      ],
    );
  }
}

class _RolesChip extends StatelessWidget {
  final List<String> roles;

  const _RolesChip({required this.roles});

  @override
  Widget build(BuildContext context) {
    final label = roles.isEmpty ? 'Aucun rôle' : roles.join(', ');

    return Chip(
      label: SizedBox(
        width: 140,
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
      backgroundColor: Colors.blueGrey.shade50,
      labelStyle: TextStyle(
        color: Colors.blueGrey.shade700,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: Colors.blueGrey.shade100),
    );
  }
}

class AssignRoleDialog extends StatefulWidget {
  final MemberModel member;
  final MembersService membersService;

  const AssignRoleDialog({
    super.key,
    required this.member,
    required this.membersService,
  });

  @override
  State<AssignRoleDialog> createState() => _AssignRoleDialogState();
}

class _AssignRoleDialogState extends State<AssignRoleDialog> {
  final List<String> _availableRoles = const [
    'team_leader',
    'secretaire_generale',
    'admin',
    'chef_pole',
    'chef_projet',
    'adjoint_pole',
    'adjoint_projet',
    'enacteur',
  ];

  late final Set<String> _selectedRoles;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedRoles = {...widget.member.roles};
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
      case 'admin':
        return 'Admin';
      case 'chef_pole':
        return 'Chef de pôle';
      case 'chef_projet':
        return 'Chef de projet';
      case 'adjoint_pole':
        return 'Adjoint pôle';
      case 'adjoint_projet':
        return 'Adjoint projet';
      case 'enacteur':
        return 'Enacteur';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assigner un rôle'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.member.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.member.email,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
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
              : const Icon(Icons.save_rounded),
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
    final defined = department != 'Non défini';

    return Chip(
      label: SizedBox(
        width: 120,
        child: Text(
          department,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
      backgroundColor: defined ? Colors.purple.shade50 : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: defined ? Colors.purple.shade700 : Colors.grey.shade700,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: defined ? Colors.purple.shade100 : Colors.grey.shade200,
      ),
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
  final List<String> _departments = const [
    'Gestion',
    'IT',
    'Tech',
    'Chimie',
    'Génie électrique',
    'Génie mécanique',
    'Génie civil',
  ];

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
        _error = 'Sélectionnez un pôle cœur.';
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
      title: const Text('Assigner le pôle cœur'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.member.displayName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              widget.member.email,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
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
            DropdownButtonFormField<String>(
              initialValue: _selectedDepartment,
              decoration: const InputDecoration(
                labelText: 'Pôle cœur',
                prefixIcon: Icon(Icons.account_tree_rounded),
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
              : const Icon(Icons.save_rounded),
          label: Text(_loading ? 'Enregistrement...' : 'Enregistrer'),
        ),
      ],
    );
  }
}
