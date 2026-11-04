// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/user_experience.dart';
import '../../../shared/ui/app_components.dart';
import '../models/alumni_profile_model.dart';
import '../../members/screens/members_screen.dart' show EditMemberDialog;
import '../../members/services/members_service.dart';
import '../services/alumni_gateway.dart';
import '../services/alumni_error_message.dart';
import '../widgets/alumni_avatar.dart';

class AlumniProfileDetailScreen extends StatefulWidget {
  final String profileId;
  final AlumniGateway? gateway;
  final bool fromDirectory;

  const AlumniProfileDetailScreen({
    super.key,
    required this.profileId,
    this.gateway,
    this.fromDirectory = false,
  });

  @override
  State<AlumniProfileDetailScreen> createState() =>
      _AlumniProfileDetailScreenState();
}

class _AlumniProfileDetailScreenState extends State<AlumniProfileDetailScreen> {
  late final AlumniGateway _gateway;
  AlumniProfileModel? _profile;
  UserExperience? _user;
  String? _error;
  bool _loading = true;
  bool _mentorAvailable = false;
  int _loadSequence = 0;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiAlumniGateway();
    _load();
  }

  Future<void> _load() async {
    final request = ++_loadSequence;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _gateway.getProfile(widget.profileId),
        _gateway.loadCenter(),
      ]);
      if (!mounted || request != _loadSequence) return;
      final profile = results[0] as AlumniProfileModel;
      final center = results[1] as AlumniCenterData;
      setState(() {
        _profile = profile;
        _user = center.user;
        _mentorAvailable = center.isMentorAvailable(profile);
      });
    } catch (error) {
      if (mounted && request == _loadSequence) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && request == _loadSequence) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _canManage {
    final user = _user;
    final profile = _profile;
    return user != null &&
        profile != null &&
        (profile.userId == user.id || user.canManageMembers);
  }

  Future<void> _edit() async {
    final profile = _profile!;
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _AlumniEditDialog(profile: profile, gateway: _gateway),
    );
    if (!mounted || updated != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
    await _load();
  }

  Future<void> _editIdentity() async {
    try {
      final service = MembersService();
      final member = await service.getMember(_profile!.userId);
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) =>
            EditMemberDialog(member: member, membersService: service),
      );
      if (mounted && saved == true) await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le profil alumni ?'),
        content: const Text(
          'Cette suppression est définitive. Vérifie le profil avant de confirmer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _gateway.deleteProfile(widget.profileId);
      if (mounted) _backToDirectory();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lien indisponible.')));
    }
  }

  void _backToDirectory([AlumniMentorSelection? selection]) {
    if (context.canPop()) {
      context.pop(selection);
    } else {
      context.go('/alumni');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = _profile;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _backToDirectory,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Retour à l’annuaire'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null || profile == null)
                    _StateCard(
                      message: _error ?? 'Profil Alumni indisponible.',
                      onRetry: _load,
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AlumniAvatar(
                                  name: profile.displayName,
                                  photoUrl: profile.photoUrl,
                                  radius: 32,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.displayName,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _value(
                                          profile.currentPosition,
                                          fallback: 'Poste non renseigné',
                                        ),
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                        ),
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
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                AppStatusBadge(label: profile.visibilityLabel),
                                if (_mentorAvailable)
                                  const AppStatusBadge(
                                    label: 'Mentorat disponible',
                                    tone: AppStatusTone.success,
                                  ),
                                if (widget.fromDirectory &&
                                    _mentorAvailable &&
                                    _user?.isActiveMember == true &&
                                    _user?.isEnacchef == true)
                                  FilledButton.icon(
                                    onPressed: () => _backToDirectory((
                                      mentorId: profile.userId,
                                      individual: false,
                                    )),
                                    icon: const Icon(Icons.handshake_outlined),
                                    label: const Text('Proposer un mentorat'),
                                  ),
                                if (widget.fromDirectory &&
                                    _gateway is IndividualMentorshipGateway &&
                                    _mentorAvailable &&
                                    _user?.isActiveMember == true &&
                                    (profile.visibility == 'internal' ||
                                        (profile.visibility ==
                                                'enacchef_only' &&
                                            _user?.isEnacchef == true)))
                                  FilledButton.tonalIcon(
                                    onPressed: () => _backToDirectory((
                                      mentorId: profile.userId,
                                      individual: true,
                                    )),
                                    icon: const Icon(
                                      Icons.person_add_alt_outlined,
                                    ),
                                    label: const Text(
                                      'Demander un mentorat individuel',
                                    ),
                                  ),
                                if (_canManage)
                                  FilledButton.tonalIcon(
                                    onPressed: _edit,
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Modifier le profil'),
                                  ),
                                if (_canManage)
                                  PopupMenuButton<String>(
                                    tooltip: 'Autres actions',
                                    onSelected: (value) {
                                      if (value == 'identity') {
                                        _editIdentity();
                                      } else {
                                        _delete();
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (_user?.canManageMembers == true)
                                        const PopupMenuItem(
                                          value: 'identity',
                                          child: Text(
                                            'Identité et coordonnées',
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Supprimer le profil'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileSection(
                      title: 'Repères',
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 14,
                        children: [
                          _Datum(
                            'Promotion',
                            profile.graduationYear?.toString() ??
                                'Non renseignée',
                          ),
                          _Datum('Domaine', _value(profile.domain)),
                          _Datum('Visibilité', profile.visibilityLabel),
                          _Datum(
                            'Mentorat',
                            _mentorAvailable ? 'Disponible' : 'Indisponible',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileSection(
                      title: 'Parcours',
                      child: Text(
                        _value(
                          profile.experienceSummary,
                          fallback: 'Parcours à compléter.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileSection(
                      title: 'Expérience',
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 14,
                        children: [
                          _Datum('Entreprise', _value(profile.currentCompany)),
                          _Datum('Poste', _value(profile.currentPosition)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileSection(
                      title: 'Compétences',
                      child: _ProfileSkills(value: profile.skills),
                    ),
                    if ((profile.linkedinUrl ?? '').trim().isNotEmpty ||
                        (profile.portfolioUrl ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ProfileSection(
                        title: 'Liens professionnels',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if ((profile.linkedinUrl ?? '').trim().isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openLink(profile.linkedinUrl!),
                                icon: const Icon(Icons.work_outline_rounded),
                                label: const Text('LinkedIn'),
                              ),
                            if ((profile.portfolioUrl ?? '').trim().isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openLink(profile.portfolioUrl!),
                                icon: const Icon(Icons.language_rounded),
                                label: const Text('Portfolio'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}

class _ProfileSkills extends StatelessWidget {
  const _ProfileSkills({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final skills = _skills(value);
    if (skills.isEmpty) return const Text('Compétences non renseignées.');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final skill in skills) Chip(label: Text(skill))],
    );
  }
}

class _AlumniEditDialog extends StatefulWidget {
  final AlumniProfileModel profile;
  final AlumniGateway gateway;
  const _AlumniEditDialog({required this.profile, required this.gateway});
  @override
  State<_AlumniEditDialog> createState() => _AlumniEditDialogState();
}

class _AlumniEditDialogState extends State<_AlumniEditDialog> {
  late final Map<String, TextEditingController> fields;
  late bool mentoring;
  late String visibility;
  bool submitting = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    fields = {
      'year': TextEditingController(text: p.graduationYear?.toString() ?? ''),
      'company': TextEditingController(text: p.currentCompany ?? ''),
      'position': TextEditingController(text: p.currentPosition ?? ''),
      'domain': TextEditingController(text: p.domain ?? ''),
      'skills': TextEditingController(text: p.skills ?? ''),
      'summary': TextEditingController(text: p.experienceSummary ?? ''),
      'linkedin': TextEditingController(text: p.linkedinUrl ?? ''),
      'portfolio': TextEditingController(text: p.portfolioUrl ?? ''),
    };
    mentoring = p.availableForMentoring;
    visibility = p.visibility;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (submitting) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.gateway.updateProfile(
        widget.profile.id,
        graduationYear: int.tryParse(fields['year']!.text),
        currentCompany: fields['company']!.text,
        currentPosition: fields['position']!.text,
        domain: fields['domain']!.text,
        skills: fields['skills']!.text,
        experienceSummary: fields['summary']!.text,
        availableForMentoring: mentoring,
        linkedinUrl: fields['linkedin']!.text,
        portfolioUrl: fields['portfolio']!.text,
        visibility: visibility,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          submitting = false;
          error = _message(e);
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Modifier le profil'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in const [
              ('year', 'Promotion'),
              ('company', 'Entreprise'),
              ('position', 'Poste'),
              ('domain', 'Domaine'),
              ('skills', 'Compétences'),
              ('summary', 'Expérience'),
              ('linkedin', 'LinkedIn'),
              ('portfolio', 'Portfolio'),
            ]) ...[
              TextField(
                controller: fields[item.$1],
                enabled: !submitting,
                keyboardType: item.$1 == 'year' ? TextInputType.number : null,
                minLines: item.$1 == 'summary' ? 3 : 1,
                maxLines: item.$1 == 'summary' ? 5 : 1,
                decoration: InputDecoration(labelText: item.$2),
              ),
              const SizedBox(height: 10),
            ],
            DropdownButtonFormField<String>(
              initialValue: visibility,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Visibilité'),
              items: const [
                DropdownMenuItem(value: 'internal', child: Text('Membres')),
                DropdownMenuItem(value: 'alumni_only', child: Text('Alumni')),
                DropdownMenuItem(
                  value: 'enacchef_only',
                  child: Text('Responsables'),
                ),
                DropdownMenuItem(value: 'private', child: Text('Privé')),
              ],
              onChanged: submitting
                  ? null
                  : (v) => setState(() => visibility = v!),
            ),
            SwitchListTile(
              value: mentoring,
              onChanged: submitting
                  ? null
                  : (v) => setState(() => mentoring = v),
              title: const Text('Disponible pour mentorat'),
              contentPadding: EdgeInsets.zero,
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: submitting ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: submitting ? null : submit,
        child: Text(submitting ? 'Enregistrement…' : 'Enregistrer'),
      ),
    ],
  );
}

class _Datum extends StatelessWidget {
  final String label;
  final String value;
  const _Datum(this.label, this.value);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _StateCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _StateCard({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

String _value(String? value, {String fallback = 'Non renseigné'}) =>
    value == null || value.trim().isEmpty ? fallback : value.trim();
List<String> _skills(String? value) => value == null
    ? const []
    : value
          .split(RegExp(r'[,;]'))
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
String _message(Object error) => alumniErrorMessage(
  error,
  fallback:
      'Impossible d’ouvrir ou de mettre à jour ce profil. Réessayez dans quelques instants.',
);
