import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
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

      if (!mounted) return;

      setState(() {
        _poles = poles;
        _members = members;
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

  @override
  Widget build(BuildContext context) {
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
                        onCreate: _openCreateSheet,
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
                          memberCount: _memberCount,
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
  final VoidCallback onCreate;
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
  final VoidCallback onCreate;
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
  final int Function(PoleModel pole) memberCount;

  const _PolesGrid({required this.poles, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: poles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: count == 1 ? 1.45 : 1.05,
          ),
          itemBuilder: (context, index) {
            final pole = poles[index];
            return _PoleCard(pole: pole, memberCount: memberCount(pole));
          },
        );
      },
    );
  }
}

class _PoleCard extends StatelessWidget {
  final PoleModel pole;
  final int memberCount;

  const _PoleCard({required this.pole, required this.memberCount});

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
            const Spacer(),
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
          ],
        ),
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
