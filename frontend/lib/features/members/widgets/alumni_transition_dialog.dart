import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/member_model.dart';
import '../services/members_service.dart';
import 'searchable_member_picker.dart';

class AlumniTransitionDialog extends StatefulWidget {
  final MembersService service;
  final List<MemberModel> members;

  const AlumniTransitionDialog({
    super.key,
    required this.service,
    required this.members,
  });

  @override
  State<AlumniTransitionDialog> createState() => _AlumniTransitionDialogState();
}

class _AlumniTransitionDialogState extends State<AlumniTransitionDialog> {
  String? _memberId;
  Future<Map<String, dynamic>>? _preview;
  bool _repairing = false;
  String? _repairError;

  void _selectMember(String? id) {
    setState(() {
      _memberId = id;
      _repairError = null;
      _preview = id == null ? null : widget.service.previewAlumni(id);
    });
  }

  Future<void> _repair(Map<String, dynamic> preview) async {
    final id = _memberId;
    if (id == null || _repairing) return;
    setState(() {
      _repairing = true;
      _repairError = null;
    });
    try {
      final control = await widget.service.repairAlumniTransition(id);
      if (mounted) {
        final updatedPreview = Future.value({...preview, 'control': control});
        setState(() {
          _preview = updatedPreview;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _repairError = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _repairing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_repairing,
      child: AlertDialog(
        title: const Text('Contrôler un passage Alumni'),
        scrollable: true,
        content: SizedBox(
          width: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableMemberPickerField(
                members: widget.members,
                value: _memberId,
                label: 'Compte à contrôler',
                onChanged: _selectMember,
                enabled: !_repairing,
              ),
              if (_preview != null) ...[
                const SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>>(
                  future: _preview,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    final preview = snapshot.data;
                    if (preview == null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.error.toString().replaceFirst(
                              'Exception: ',
                              '',
                            ),
                          ),
                          TextButton(
                            onPressed: () => _selectMember(_memberId),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      );
                    }
                    return _details(context, preview);
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _repairing ? null : () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, Map<String, dynamic> preview) {
    final control = preview['control'] as Map<String, dynamic>;
    final state = control['state'];
    final account = MemberModel.fromJson(preview);
    final confirmation = DateTime.tryParse(
      control['confirmed_at']?.toString() ?? '',
    );
    final profileId = control['profile_id'] as String?;
    final visibility = switch (control['visibility']) {
      'internal' => 'Membres',
      'alumni_only' => 'Alumni',
      'enacchef_only' => 'EnacChefs',
      'private' => 'Restreinte',
      _ => null,
    };
    final (title, explanation) = switch (state) {
      'missing_profile' => (
        'Fiche Alumni manquante',
        'Le passage est confirmé. La fiche sera créée à partir de ce compte et liée à son identifiant.',
      ),
      'inconsistent_account' => (
        'Compte à synchroniser',
        'Le passage est confirmé. Vérifiez le statut et les rôles du compte avant de réparer sa fiche.',
      ),
      'linked_visible' => (
        'Fiche liée et visible',
        'Le compte est déjà rattaché à sa fiche dans l’annuaire.',
      ),
      'linked_restricted' => (
        'Fiche liée à visibilité restreinte',
        'Le compte est déjà rattaché à sa fiche. Vous pouvez consulter ses réglages de visibilité.',
      ),
      _ => (
        'Passage non confirmé',
        'Aucun passage Enacteur vers Alumni n’est enregistré pour ce compte. Un compte créé directement comme Alumni peut déjà avoir sa propre fiche.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 6),
        Text(explanation),
        const SizedBox(height: 12),
        Text(
          'Rôles actuels · ${account.roles.isEmpty ? 'Aucun' : account.rolesLabel}',
        ),
        Text('Statut du compte · ${account.statusLabel}'),
        if (confirmation != null)
          Text(
            'Confirmé le ${DateFormat('dd/MM/yyyy').format(confirmation.toLocal())}',
          ),
        if (visibility != null) Text('Visibilité de la fiche · $visibility'),
        if (_repairError != null)
          Semantics(liveRegion: true, child: Text(_repairError!)),
        const SizedBox(height: 8),
        if (control['can_repair'] == true)
          FilledButton.icon(
            onPressed: _repairing ? null : () => _repair(preview),
            icon: const Icon(Icons.link),
            label: Text(
              _repairing ? 'Réparation en cours…' : 'Créer et lier la fiche',
            ),
          )
        else if (profileId != null && state != 'inconsistent_account')
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(profileId),
            icon: const Icon(Icons.open_in_new_outlined),
            label: const Text('Ouvrir la fiche Alumni'),
          ),
      ],
    );
  }
}
