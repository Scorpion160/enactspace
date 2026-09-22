import 'package:flutter/material.dart';

import '../../members/models/member_model.dart';
import '../models/project_member_model.dart';
import '../models/project_team_management_models.dart';

class ProjectTeamManagementSection extends StatelessWidget {
  final String projectName;
  final List<ProjectMemberModel>? members;
  final bool unavailable;
  final ProjectTeamPermissions permissions;
  final VoidCallback? onAddMember;
  final VoidCallback? onChangeLead;
  final VoidCallback? onChangeDeputy;
  final ValueChanged<ProjectMemberModel>? onRemoveMember;

  const ProjectTeamManagementSection({
    super.key,
    required this.projectName,
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
      return const _TeamState(
        icon: Icons.groups_2_outlined,
        title: 'Équipe indisponible',
        message: 'Les affectations n’ont pas pu être chargées.',
      );
    }
    final active = (members ?? const [])
        .where((member) => member.isActive && member.leftAt == null)
        .toList();
    final lead = _at(active, ProjectPositionPresentation.lead);
    final deputy = _at(active, ProjectPositionPresentation.deputy);
    final ordinary = active
        .where(
          (member) =>
              member.position == ProjectPositionPresentation.member ||
              !ProjectPositionPresentation.isLeadership(member.position),
        )
        .toList();

    return ListView(
      key: const Key('project-team-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Text(
              'Équipe',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (permissions.canManageOrdinaryMembers)
              FilledButton.icon(
                onPressed: onAddMember,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  active.isEmpty ? 'Constituer l’équipe' : 'Ajouter un membre',
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (active.isEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const Icon(Icons.group_off_rounded, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'Aucune équipe affectée',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ce projet ne possède actuellement aucune affectation active.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          _ResponsibilityCard(
            title: 'Chef de projet',
            member: lead,
            actionLabel: lead == null
                ? 'Nommer un chef de projet'
                : 'Changer de chef de projet',
            onAction: permissions.canManageResponsibilities
                ? onChangeLead
                : null,
            onRemove: lead != null && permissions.canRemove(lead)
                ? () => onRemoveMember?.call(lead)
                : null,
          ),
          _ResponsibilityCard(
            title: 'Adjoint chef de projet',
            member: deputy,
            actionLabel: deputy == null
                ? 'Nommer un adjoint'
                : 'Changer d’adjoint',
            onAction: permissions.canManageResponsibilities
                ? onChangeDeputy
                : null,
            onRemove: deputy != null && permissions.canRemove(deputy)
                ? () => onRemoveMember?.call(deputy)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            'Membres',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (ordinary.isEmpty)
            const Text('Aucun autre membre affecté')
          else
            ...ordinary.map(
              (member) => _MemberCard(
                member: member,
                onRemove: permissions.canRemove(member)
                    ? () => onRemoveMember?.call(member)
                    : null,
              ),
            ),
        ],
      ],
    );
  }

  ProjectMemberModel? _at(List<ProjectMemberModel> active, String position) {
    for (final member in active) {
      if (member.position == position) return member;
    }
    return null;
  }
}

class ProjectMemberDialog extends StatefulWidget {
  final String projectName;
  final List<MemberModel> directory;
  final List<ProjectMemberModel> activeMemberships;
  final Future<ProjectMemberMutationResult> Function(MemberModel member)
  onSubmit;

  const ProjectMemberDialog({
    super.key,
    required this.projectName,
    required this.directory,
    required this.activeMemberships,
    required this.onSubmit,
  });

  @override
  State<ProjectMemberDialog> createState() => _ProjectMemberDialogState();
}

class _ProjectMemberDialogState extends State<ProjectMemberDialog> {
  final _search = TextEditingController();
  MemberModel? _selected;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeByUser = {
      for (final membership in widget.activeMemberships)
        if (membership.isActive && membership.leftAt == null)
          membership.userId: membership,
    };
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
      title: const Text('Ajouter un membre'),
      content: SizedBox(
        width: 580,
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Projet · ${widget.projectName}'),
            const Text('Responsabilité dans le projet · Membre du projet'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('project-member-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Rechercher par nom ou e-mail',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: candidates.isEmpty
                  ? const Center(child: Text('Aucun membre disponible'))
                  : ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final member = candidates[index];
                        final membership = activeByUser[member.id];
                        return ListTile(
                          enabled: membership == null,
                          onTap: membership == null
                              ? () => setState(() => _selected = member)
                              : null,
                          leading: Icon(
                            _selected?.id == member.id
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                          ),
                          title: Text(member.displayName),
                          subtitle: Text(
                            membership == null
                                ? member.email
                                : '${member.email} · Déjà dans l’équipe (${membership.positionLabel})',
                          ),
                        );
                      },
                    ),
            ),
            if (_selected != null)
              Text(
                '${_selected!.displayName} rejoindra ${widget.projectName} comme Membre du projet.',
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
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
        _error = projectTeamErrorMessage(error);
      });
    }
  }
}

class ProjectLeadChangeDialog extends StatefulWidget {
  final String projectName;
  final String targetPosition;
  final ProjectMemberModel? currentHolder;
  final List<MemberModel> directory;
  final Future<ProjectMemberMutationResult> Function(MemberModel member)
  onSubmit;

  const ProjectLeadChangeDialog({
    super.key,
    required this.projectName,
    required this.targetPosition,
    required this.currentHolder,
    required this.directory,
    required this.onSubmit,
  });

  @override
  State<ProjectLeadChangeDialog> createState() =>
      _ProjectLeadChangeDialogState();
}

class _ProjectLeadChangeDialogState extends State<ProjectLeadChangeDialog> {
  MemberModel? _selected;
  bool _sending = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final isLead = widget.targetPosition == ProjectPositionPresentation.lead;
    final eligible = widget.directory
        .where(
          (member) =>
              member.status == 'active' &&
              !member.isAlumni &&
              member.id != widget.currentHolder?.userId,
        )
        .toList();
    final title = widget.currentHolder == null
        ? (isLead ? 'Nommer un chef de projet' : 'Nommer un adjoint')
        : (isLead ? 'Changer de chef de projet' : 'Changer d’adjoint');
    final action = isLead
        ? 'Nommer comme chef de projet'
        : 'Nommer comme adjoint';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Projet · ${widget.projectName}'),
            Text(
              'Responsabilité dans le projet · ${ProjectPositionPresentation.label(widget.targetPosition)}',
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<MemberModel>(
              initialValue: _selected,
              decoration: InputDecoration(
                labelText: isLead ? 'Nouveau chef' : 'Nouvel adjoint',
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
            if (eligible.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Aucun membre disponible'),
              ),
            if (widget.currentHolder != null && _selected != null) ...[
              const SizedBox(height: 14),
              Text(
                '${widget.currentHolder!.displayName} → ${_selected!.displayName}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                isLead
                    ? 'Le chef actuel quittera cette responsabilité et restera membre du projet.'
                    : 'L’adjoint actuel quittera cette responsabilité et restera membre du projet.',
              ),
            ],
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
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          onPressed: _selected == null || _sending ? null : _submit,
          child: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_error == null ? action : 'Réessayer'),
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
        _error = projectTeamErrorMessage(error);
      });
    }
  }
}

class ProjectMemberRemovalDialog extends StatefulWidget {
  final String projectName;
  final ProjectMemberModel membership;
  final bool isCurrentUser;
  final Future<ProjectMemberModel> Function() onSubmit;

  const ProjectMemberRemovalDialog({
    super.key,
    required this.projectName,
    required this.membership,
    required this.isCurrentUser,
    required this.onSubmit,
  });

  @override
  State<ProjectMemberRemovalDialog> createState() =>
      _ProjectMemberRemovalDialogState();
}

class _ProjectMemberRemovalDialogState
    extends State<ProjectMemberRemovalDialog> {
  bool _sending = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final leadership = ProjectPositionPresentation.isLeadership(
      widget.membership.position,
    );
    return AlertDialog(
      title: const Text('Retirer ce membre du projet ?'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.membership.displayName),
            Text(widget.membership.email),
            Text('Projet · ${widget.projectName}'),
            Text(
              'Responsabilité actuelle · ${widget.membership.positionLabel}',
            ),
            const SizedBox(height: 12),
            const Text(
              'La personne ne fera plus partie de l’équipe active du projet.',
            ),
            if (leadership) ...[
              const SizedBox(height: 8),
              Text(
                widget.membership.position == ProjectPositionPresentation.lead
                    ? 'Le projet restera sans chef tant qu’aucun remplacement ne sera nommé.'
                    : 'Le projet restera sans adjoint tant qu’aucun remplacement ne sera nommé.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (widget.isCurrentUser) ...[
              const SizedBox(height: 8),
              const Text(
                'Vous perdrez votre capacité locale de gestion après ce retrait.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
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
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
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
      final result = await widget.onSubmit();
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = projectTeamErrorMessage(error);
      });
    }
  }
}

class _ResponsibilityCard extends StatelessWidget {
  final String title;
  final ProjectMemberModel? member;
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
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(member?.displayName ?? 'Non affecté'),
                if (member != null) Text(member!.email),
                if (member != null)
                  Text('Arrivée · ${_date(member!.joinedAt)}'),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
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
        ],
      ),
    ),
  );
}

class _MemberCard extends StatelessWidget {
  final ProjectMemberModel member;
  final VoidCallback? onRemove;
  const _MemberCard({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Text(member.displayName.characters.first)),
      title: Text(member.displayName),
      subtitle: Text(
        '${member.email}\n${member.positionLabel} · Arrivée le ${_date(member.joinedAt)}',
      ),
      isThreeLine: true,
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: 'Retirer ${member.displayName} de l’équipe',
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_outlined),
            ),
    ),
  );
}

class _TeamState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _TeamState({
    required this.icon,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String _date(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
