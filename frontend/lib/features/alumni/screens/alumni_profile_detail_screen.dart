// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/user_experience.dart';
import '../models/alumni_profile_model.dart';
import '../services/alumni_gateway.dart';

class AlumniProfileDetailScreen extends StatefulWidget {
  final String profileId;
  final AlumniGateway? gateway;

  const AlumniProfileDetailScreen({
    super.key,
    required this.profileId,
    this.gateway,
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

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiAlumniGateway();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _gateway.getProfile(widget.profileId),
        _gateway.loadCenter(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as AlumniProfileModel;
        _user = (results[1] as AlumniCenterData).user;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canManage {
    final user = _user;
    final profile = _profile;
    return user != null &&
        profile != null &&
        (profile.userId == user.id ||
            user.isAdmin ||
            user.isTeamLeader ||
            user.isSecretary);
  }

  Future<void> _edit() async {
    final profile = _profile!;
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _AlumniEditDialog(profile: profile, gateway: _gateway),
    );
    if (updated == true) await _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le profil alumni ?'),
        content: const Text(
          'Cette suppression est définitive et sera contrôlée par le backend.',
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
      if (mounted) context.go('/alumni');
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
        child: _StateCard(message: _error!, onRetry: _load),
      );
    final profile = _profile!;
    final links = <Widget>[
      if ((profile.linkedinUrl ?? '').trim().isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => _openLink(profile.linkedinUrl!),
          icon: const Icon(Icons.work_outline_rounded),
          label: const Text('LinkedIn'),
        ),
      if ((profile.portfolioUrl ?? '').trim().isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => _openLink(profile.portfolioUrl!),
          icon: const Icon(Icons.language_rounded),
          label: const Text('Portfolio'),
        ),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundImage: profile.photoUrl == null
                            ? null
                            : NetworkImage(profile.photoUrl!),
                        child: profile.photoUrl == null
                            ? const Icon(Icons.person_rounded, size: 38)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              [profile.currentPosition, profile.currentCompany]
                                  .whereType<String>()
                                  .where((v) => v.trim().isNotEmpty)
                                  .join(' · '),
                            ),
                          ],
                        ),
                      ),
                      if (_canManage)
                        PopupMenuButton<String>(
                          tooltip: 'Gérer le profil',
                          onSelected: (value) =>
                              value == 'edit' ? _edit() : _delete(),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Modifier'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Supprimer'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Wrap(
                        spacing: 28,
                        runSpacing: 18,
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
                            profile.availableForMentoring
                                ? 'Disponible'
                                : 'Indisponible',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expérience',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(_value(profile.experienceSummary)),
                          const SizedBox(height: 18),
                          Text(
                            'Compétences',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _skills(
                              profile.skills,
                            ).map((value) => Chip(label: Text(value))).toList(),
                          ),
                          if (links.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Wrap(spacing: 10, runSpacing: 10, children: links),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
                minLines: item.$1 == 'summary' ? 3 : 1,
                maxLines: item.$1 == 'summary' ? 5 : 1,
                decoration: InputDecoration(labelText: item.$2),
              ),
              const SizedBox(height: 10),
            ],
            DropdownButtonFormField<String>(
              initialValue: visibility,
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

String _value(String? value) =>
    value == null || value.trim().isEmpty ? 'Non renseigné' : value.trim();
List<String> _skills(String? value) => value == null
    ? const []
    : value
          .split(RegExp(r'[,;]'))
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
String _message(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
