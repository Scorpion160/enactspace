import 'package:flutter/material.dart';

import '../../../core/auth/user_experience.dart';
import '../../members/models/member_model.dart';
import '../../members/widgets/searchable_member_picker.dart';
import '../models/alumni_profile_model.dart';
import '../services/alumni_error_message.dart';
import '../services/alumni_gateway.dart';

class IndividualMentorshipForm extends StatefulWidget {
  final UserExperience user;
  final List<AlumniProfileModel> mentors;
  final List<MemberModel> members;
  final String? initialMentorId;
  final IndividualMentorshipGateway gateway;

  const IndividualMentorshipForm({
    super.key,
    required this.user,
    required this.mentors,
    required this.members,
    required this.gateway,
    this.initialMentorId,
  });

  @override
  State<IndividualMentorshipForm> createState() =>
      _IndividualMentorshipFormState();
}

class _IndividualMentorshipFormState extends State<IndividualMentorshipForm> {
  final _formKey = GlobalKey<FormState>();
  final _objective = TextEditingController();
  late String? _mentorId = widget.initialMentorId;
  late String _menteeId = widget.user.id;
  bool _saving = false;
  String? _error;

  bool get _menteeIsEnacchef {
    if (_menteeId == widget.user.id) return widget.user.isEnacchef;
    final member = widget.members.firstWhere(
      (member) => member.id == _menteeId,
    );
    return UserExperience.fromJson({'roles': member.roles}).isEnacchef;
  }

  @override
  void dispose() {
    _objective.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.createIndividualRequest(
        mentorId: _mentorId!,
        menteeId: _menteeId,
        objective: _objective.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = alumniErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mentors = widget.mentors.where(
      (mentor) => mentor.visibility == 'internal' || _menteeIsEnacchef,
    );
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Demander un mentorat individuel'),
        scrollable: true,
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('La demande sera soumise à validation.'),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey(_menteeId),
                  initialValue: _mentorId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Mentor'),
                  items: [
                    for (final mentor in mentors)
                      DropdownMenuItem(
                        value: mentor.userId,
                        child: Text(
                          mentor.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _mentorId = value),
                  validator: (value) =>
                      value == null ? 'Choisissez un mentor.' : null,
                ),
                const SizedBox(height: 12),
                if (widget.user.canManageMembers && widget.members.isNotEmpty)
                  SearchableMemberPickerField(
                    members: widget.members,
                    value: _menteeId,
                    enabled: !_saving,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _menteeId = value;
                        if (!_menteeIsEnacchef &&
                            widget.mentors.any(
                              (mentor) =>
                                  mentor.userId == _mentorId &&
                                  mentor.visibility != 'internal',
                            )) {
                          _mentorId = null;
                        }
                      });
                    },
                    label: 'Membre mentoré',
                  )
                else
                  const Text('Vous créez cette demande pour vous-même.'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _objective,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Objectif du mentorat',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Décrivez votre objectif.'
                      : null,
                ),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Envoi en cours…' : 'Envoyer la demande'),
          ),
        ],
      ),
    );
  }
}
