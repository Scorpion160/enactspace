import 'package:flutter/material.dart';

import '../../members/models/member_model.dart';
import '../models/pole_management_models.dart';
import '../models/pole_model.dart';

class PoleFormDialog extends StatefulWidget {
  final PoleModel? pole;
  final Future<PoleModel> Function(PoleMutationDraft draft) onSubmit;

  const PoleFormDialog({super.key, this.pole, required this.onSubmit});

  @override
  State<PoleFormDialog> createState() => _PoleFormDialogState();
}

class _PoleFormDialogState extends State<PoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _shortName;
  late final TextEditingController _description;
  late final TextEditingController _objectives;
  late String _type;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = widget.pole == null
        ? const PoleMutationDraft(
            name: '',
            shortName: '',
            type: 'metier',
            description: '',
            objectives: '',
          )
        : PoleMutationDraft.fromPole(widget.pole!);
    _name = TextEditingController(text: draft.name);
    _shortName = TextEditingController(text: draft.shortName);
    _description = TextEditingController(text: draft.description);
    _objectives = TextEditingController(text: draft.objectives);
    _type = draft.type == 'support' ? 'support' : 'metier';
  }

  @override
  void dispose() {
    _name.dispose();
    _shortName.dispose();
    _description.dispose();
    _objectives.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.pole == null ? 'Créer un pôle' : 'Modifier le pôle'),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('pole-name-field'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Le nom est obligatoire.'
                    : null,
              ),
              TextFormField(
                controller: _shortName,
                decoration: const InputDecoration(labelText: 'Sigle'),
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('pole-type-field'),
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type *'),
                items: const [
                  DropdownMenuItem(value: 'metier', child: Text('Pôle cœur')),
                  DropdownMenuItem(
                    value: 'support',
                    child: Text('Pôle support'),
                  ),
                ],
                onChanged: _sending
                    ? null
                    : (value) => setState(() => _type = value ?? 'metier'),
              ),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 4,
              ),
              TextFormField(
                controller: _objectives,
                decoration: const InputDecoration(labelText: 'Objectifs'),
                minLines: 2,
                maxLines: 4,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _sending ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const ValueKey('pole-form-submit'),
        onPressed: _sending ? null : _submit,
        child: _sending
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_error == null ? 'Enregistrer' : 'Réessayer'),
      ),
    ],
  );

  Future<void> _submit() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(
        PoleMutationDraft(
          name: _name.text,
          shortName: _shortName.text,
          type: _type,
          description: _description.text,
          objectives: _objectives.text,
        ),
      );
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = poleManagementErrorMessage(error);
      });
    }
  }
}

class PoleManagementActions extends StatelessWidget {
  final VoidCallback onEdit;

  const PoleManagementActions({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: OutlinedButton.icon(
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Modifier le pôle'),
    ),
  );
}

class PoleTeamManagementSection extends StatelessWidget {
  final String poleName;
  final List<MemberModel>? members;
  final bool unavailable;
  final PoleManagementPermissions permissions;
  final VoidCallback? onAddMember;
  final VoidCallback? onChangeLead;
  final VoidCallback? onChangeDeputy;
  final ValueChanged<MemberModel>? onRemoveMember;

  const PoleTeamManagementSection({
    super.key,
    required this.poleName,
    required this.members,
    required this.unavailable,
    required this.permissions,
    this.onAddMember,
    this.onChangeLead,
    this.onChangeDeputy,
    this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    if (unavailable) {
      return const _TeamCard(
        child: Text('Équipe indisponible. Réessayez ultérieurement.'),
      );
    }
    final active = (members ?? const [])
        .where((member) => member.isActive != false)
        .toList();
    final lead = _at(active, PolePositionPresentation.lead);
    final deputy = _at(active, PolePositionPresentation.deputy);
    final ordinary = active
        .where(
          (member) =>
              !PolePositionPresentation.isLeadership(member.polePosition),
        )
        .toList();
    return _TeamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              const Text(
                'Équipe',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              if (onAddMember != null)
                FilledButton.icon(
                  onPressed: onAddMember,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Ajouter ou réintégrer'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _ResponsibilityCard(
            title: 'Chef de pôle',
            member: lead,
            actionLabel: lead == null ? 'Nommer' : 'Remplacer',
            onAction: onChangeLead,
            onRemove: lead != null && permissions.isGlobalManager
                ? () => onRemoveMember?.call(lead)
                : null,
          ),
          _ResponsibilityCard(
            title: 'Adjoint du pôle',
            member: deputy,
            actionLabel: deputy == null ? 'Nommer' : 'Remplacer',
            onAction: onChangeDeputy,
            onRemove: deputy != null && permissions.isGlobalManager
                ? () => onRemoveMember?.call(deputy)
                : null,
          ),
          const SizedBox(height: 8),
          Text('Membres ordinaires · ${ordinary.length}'),
          const SizedBox(height: 6),
          if (ordinary.isEmpty)
            const Text('Aucun membre ordinaire affecté')
          else
            ...ordinary.map(
              (member) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(member.displayName),
                subtitle: Text(member.email),
                trailing:
                    onRemoveMember != null && permissions.canRemove(member)
                    ? IconButton(
                        tooltip: 'Retirer ${member.displayName} de l’équipe',
                        onPressed: () => onRemoveMember!(member),
                        icon: const Icon(Icons.person_remove_outlined),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  MemberModel? _at(List<MemberModel> members, String position) {
    for (final member in members) {
      if (member.polePosition == position) return member;
    }
    return null;
  }
}

class PoleMemberDialog extends StatefulWidget {
  final String poleName;
  final List<MemberModel> directory;
  final List<MemberModel> activeMemberships;
  final Future<PoleMemberMutationResult> Function(MemberModel member) onSubmit;

  const PoleMemberDialog({
    super.key,
    required this.poleName,
    required this.directory,
    required this.activeMemberships,
    required this.onSubmit,
  });

  @override
  State<PoleMemberDialog> createState() => _PoleMemberDialogState();
}

class _PoleMemberDialogState extends State<PoleMemberDialog> {
  final _search = TextEditingController();
  MemberModel? _selected;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final activeIds = widget.activeMemberships.map((item) => item.id).toSet();
    final query = _search.text.trim().toLowerCase();
    final candidates = widget.directory
        .where((member) => member.status == 'active' && !member.isAlumni)
        .where(
          (member) =>
              query.isEmpty ||
              member.displayName.toLowerCase().contains(query) ||
              member.email.toLowerCase().contains(query),
        )
        .toList();
    return AlertDialog(
      title: const Text('Ajouter ou réintégrer une personne'),
      content: SizedBox(
        width: 580,
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pôle · ${widget.poleName}'),
            const Text('Responsabilité attribuée · Membre du pôle'),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('pole-directory-search'),
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Rechercher par nom ou e-mail',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: candidates.isEmpty
                  ? const Center(child: Text('Aucune personne disponible'))
                  : ListView(
                      children: candidates.map((member) {
                        final already = activeIds.contains(member.id);
                        return ListTile(
                          selected: _selected?.id == member.id,
                          enabled: !already && !_sending,
                          onTap: already || _sending
                              ? null
                              : () => setState(() => _selected = member),
                          leading: Icon(
                            _selected?.id == member.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text(member.displayName),
                          subtitle: Text(
                            already ? 'Déjà dans l’équipe' : member.email,
                          ),
                        );
                      }).toList(),
                    ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const ValueKey('pole-member-submit'),
          onPressed: _selected == null || _sending ? null : _submit,
          child: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_error == null ? 'Ajouter à l’équipe' : 'Réessayer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_sending || _selected == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(_selected!);
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = poleManagementErrorMessage(error);
      });
    }
  }
}

class PoleResponsibilityDialog extends StatefulWidget {
  final String poleName;
  final String targetPosition;
  final MemberModel? currentHolder;
  final List<MemberModel> directory;
  final Future<PoleMemberMutationResult> Function(MemberModel member) onSubmit;

  const PoleResponsibilityDialog({
    super.key,
    required this.poleName,
    required this.targetPosition,
    required this.currentHolder,
    required this.directory,
    required this.onSubmit,
  });

  @override
  State<PoleResponsibilityDialog> createState() =>
      _PoleResponsibilityDialogState();
}

class _PoleResponsibilityDialogState extends State<PoleResponsibilityDialog> {
  MemberModel? _selected;
  bool _sending = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final lead = widget.targetPosition == PolePositionPresentation.lead;
    final eligible = widget.directory
        .where((member) => member.status == 'active' && !member.isAlumni)
        .where((member) => member.id != widget.currentHolder?.id)
        .toList();
    return AlertDialog(
      title: Text(lead ? 'Nommer le chef de pôle' : 'Nommer l’adjoint du pôle'),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pôle · ${widget.poleName}'),
            DropdownButtonFormField<MemberModel>(
              key: const ValueKey('pole-responsibility-select'),
              initialValue: _selected,
              decoration: InputDecoration(
                labelText: lead ? 'Nouveau chef' : 'Nouvel adjoint',
              ),
              items: eligible
                  .map(
                    (member) => DropdownMenuItem(
                      value: member,
                      child: Text(member.displayName),
                    ),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (value) => setState(() => _selected = value),
            ),
            if (widget.currentHolder != null && _selected != null) ...[
              const SizedBox(height: 12),
              Text(
                '${widget.currentHolder!.displayName} → ${_selected!.displayName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                lead
                    ? 'L’ancien chef redevient membre du pôle et reste dans l’équipe active.'
                    : 'L’ancien adjoint redevient membre du pôle et reste dans l’équipe active.',
              ),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const ValueKey('pole-responsibility-submit'),
          onPressed: _selected == null || _sending ? null : _submit,
          child: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_error == null ? 'Confirmer la nomination' : 'Réessayer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_sending || _selected == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(_selected!);
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = poleManagementErrorMessage(error);
      });
    }
  }
}

class PoleMemberRemovalDialog extends StatefulWidget {
  final String poleName;
  final MemberModel membership;
  final Future<void> Function() onSubmit;

  const PoleMemberRemovalDialog({
    super.key,
    required this.poleName,
    required this.membership,
    required this.onSubmit,
  });

  @override
  State<PoleMemberRemovalDialog> createState() =>
      _PoleMemberRemovalDialogState();
}

class _PoleMemberRemovalDialogState extends State<PoleMemberRemovalDialog> {
  bool _confirmed = false;
  bool _sending = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final leadership = PolePositionPresentation.isLeadership(
      widget.membership.polePosition,
    );
    return AlertDialog(
      title: const Text('Retirer cette personne de l’équipe ?'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.membership.displayName),
            Text('Pôle · ${widget.poleName}'),
            Text(
              'Responsabilité actuelle · ${PolePositionPresentation.label(widget.membership.polePosition)}',
            ),
            const SizedBox(height: 12),
            const Text('La personne quittera l’équipe active du pôle.'),
            if (leadership) ...[
              const SizedBox(height: 8),
              const Text(
                'Aucun remplacement automatique ne sera effectué.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              CheckboxListTile(
                value: _confirmed,
                contentPadding: EdgeInsets.zero,
                onChanged: _sending
                    ? null
                    : (value) => setState(() => _confirmed = value == true),
                title: const Text('Je confirme le retrait du responsable'),
              ),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const ValueKey('pole-removal-submit'),
          onPressed: _sending || (leadership && !_confirmed) ? null : _submit,
          child: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_error == null ? 'Retirer de l’équipe' : 'Réessayer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = poleManagementErrorMessage(error);
      });
    }
  }
}

class _TeamCard extends StatelessWidget {
  final Widget child;
  const _TeamCard({required this.child});

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class _ResponsibilityCard extends StatelessWidget {
  final String title;
  final MemberModel? member;
  final String actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onRemove;

  const _ResponsibilityCard({
    required this.title,
    required this.member,
    required this.actionLabel,
    required this.onAction,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(member?.displayName ?? 'Non affecté'),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (onAction != null)
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          if (onRemove != null)
            TextButton(
              onPressed: onRemove,
              child: const Text('Retirer de l’équipe'),
            ),
        ],
      ),
    ),
  );
}
