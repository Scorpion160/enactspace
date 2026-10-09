import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ui/photo_preview.dart';
import '../../gamification/services/games_service.dart';
import '../../members/models/member_model.dart';
import '../services/my_profile_service.dart';

class MyProfileScreen extends StatefulWidget {
  final MyProfileService? service;

  const MyProfileScreen({super.key, this.service});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late final MyProfileService _service;
  MemberModel? _profile;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MyProfileService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _service.load();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final result = await showModalBottomSheet<MemberModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          _ProfileEditSheet(profile: profile, service: _service),
    );
    if (result == null || !mounted) return;
    setState(() => _profile = result);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profil mis à jour.')));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 700 ? 16 : 28,
          20,
          MediaQuery.sizeOf(context).width < 700 ? 16 : 28,
          32,
        ),
        children: [
          if (_loading && _profile == null)
            const SizedBox(
              height: 420,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _profile == null)
            _ProfileError(onRetry: _load)
          else if (_profile != null)
            _ProfileContent(profile: _profile!, onEdit: _editProfile),
        ],
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final MemberModel profile;
  final VoidCallback onEdit;

  const _ProfileContent({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHero(profile: profile, onEdit: onEdit),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final identity = _IdentitySection(profile: profile);
                final journey = _JourneySection(profile: profile);
                if (!wide) {
                  return Column(
                    children: [identity, const SizedBox(height: 14), journey],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 14),
                    Expanded(child: journey),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _AboutSection(profile: profile),
            const SizedBox(height: 14),
            _ActivitySection(profile: profile),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final MemberModel profile;
  final VoidCallback onEdit;

  const _ProfileHero({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(profile.displayName);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PhotoPreviewTap(
            image: _imageProvider(profile.photoUrl),
            title: profile.displayName,
            child: CircleAvatar(
              radius: 38,
              backgroundColor: AppTheme.enactusYellow,
              foregroundColor: AppTheme.softBlack,
              backgroundImage: _imageProvider(profile.photoUrl),
              child: profile.photoUrl?.trim().isNotEmpty == true
                  ? null
                  : Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 600
                ? (MediaQuery.sizeOf(context).width - 92).clamp(180, 480)
                : 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${profile.primaryRoleLabel} · ${profile.statusLabel}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Modifier mon profil'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.enactusYellow,
              foregroundColor: AppTheme.softBlack,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentitySection extends StatelessWidget {
  final MemberModel profile;

  const _IdentitySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'Identité & contact',
      icon: Icons.badge_rounded,
      children: [
        _InfoLine(label: 'Profil', value: profile.memberLabel),
        _InfoLine(label: 'Email', value: profile.email),
        _InfoLine(label: 'Téléphone', value: profile.phoneLabel),
        _InfoLine(label: 'Département ESP', value: profile.departmentLabel),
        _InfoLine(label: 'Rôle principal', value: profile.primaryRoleLabel),
        _InfoLine(label: 'Rôles', value: profile.rolesLabel),
      ],
    );
  }
}

class _JourneySection extends StatelessWidget {
  final MemberModel profile;

  const _JourneySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'Parcours',
      icon: Icons.route_rounded,
      children: [
        _InfoLine(label: 'Cursus', value: profile.cursusLabel),
        _InfoLine(label: 'Niveau', value: profile.studyLevelLabel),
        _InfoLine(label: 'Spécialité', value: profile.specialtyLabel),
        _InfoLine(label: 'Promotion', value: profile.promotionLabel),
        _InfoLine(
          label: 'Entrée à Enactus',
          value: profile.enactusJoinYearLabel,
        ),
        _InfoLine(label: 'Compte créé', value: profile.joinedAtLabel),
        if (profile.polePosition?.trim().isNotEmpty == true)
          _InfoLine(label: 'Position pôle', value: profile.polePositionLabel),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  final MemberModel profile;

  const _AboutSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'À propos de moi',
      icon: Icons.person_rounded,
      children: [
        Text(
          profile.bioLabel,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        if (_hasText(profile.linkedinUrl) ||
            _hasText(profile.githubUrl) ||
            _hasText(profile.portfolioUrl)) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_hasText(profile.linkedinUrl))
                _LinkChip(label: 'LinkedIn', value: profile.linkedinUrl!),
              if (_hasText(profile.githubUrl))
                _LinkChip(label: 'GitHub', value: profile.githubUrl!),
              if (_hasText(profile.portfolioUrl))
                _LinkChip(label: 'Portfolio', value: profile.portfolioUrl!),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final MemberModel profile;

  const _ActivitySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'Vie Enactus & contributions',
      icon: Icons.auto_graph_rounded,
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: GamesService().profile(profile.id),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) return const SizedBox.shrink();
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniMetric(label: 'Points', value: '${data['points'] ?? 0}'),
                _MiniMetric(label: 'Victoires', value: '${data['wins'] ?? 0}'),
                _MiniMetric(label: 'Parties', value: '${data['games'] ?? 0}'),
                if (data['badges'] is List)
                  _MiniMetric(
                    label: 'Badges',
                    value: '${(data['badges'] as List).length}',
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ProfileShortcut(
              label: 'Mes tâches',
              icon: Icons.task_alt_rounded,
              onTap: () => context.go('/tasks?view=my'),
            ),
            _ProfileShortcut(
              label: 'Academy',
              icon: Icons.school_rounded,
              onTap: () => context.go('/academy'),
            ),
            if (!profile.isAlumni)
              _ProfileShortcut(
                label: 'Mes présences',
                icon: Icons.fact_check_rounded,
                onTap: () => context.go('/attendance'),
              ),
            _ProfileShortcut(
              label: 'Ma mémoire',
              icon: Icons.history_edu_rounded,
              onTap: () => context.go(
                '/archives?member_id=${Uri.encodeQueryComponent(profile.id)}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      '$value  $label',
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

class _ProfileShortcut extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileShortcut({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon),
    label: Text(label),
  );
}

class _LinkChip extends StatelessWidget {
  final String label;
  final String value;

  const _LinkChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: const Icon(Icons.link_rounded, size: 18),
    label: Text(label),
    tooltip: value,
    onPressed: () async {
      final uri = Uri.tryParse(value.trim());
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    },
  );
}

class _ProfileEditSheet extends StatefulWidget {
  final MemberModel profile;
  final MyProfileService service;

  const _ProfileEditSheet({required this.profile, required this.service});

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final Map<String, TextEditingController> c;
  bool saving = false;
  bool pickingPhoto = false;
  bool removePhoto = false;
  Uint8List? pendingPhotoBytes;
  String? pendingPhotoFileName;
  String? error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    c = {
      'first': TextEditingController(text: p.firstName ?? ''),
      'last': TextEditingController(text: p.lastName ?? ''),
      'phone': TextEditingController(text: p.phone ?? ''),
      'department': TextEditingController(text: p.department ?? ''),
      'cursus': TextEditingController(text: p.cursus ?? ''),
      'level': TextEditingController(text: p.studyLevel ?? ''),
      'specialty': TextEditingController(text: p.specialty ?? ''),
      'promotion': TextEditingController(text: p.promotion ?? ''),
      'bio': TextEditingController(text: p.bio ?? ''),
      'linkedin': TextEditingController(text: p.linkedinUrl ?? ''),
      'github': TextEditingController(text: p.githubUrl ?? ''),
      'portfolio': TextEditingController(text: p.portfolioUrl ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() {
      pickingPhoto = true;
      error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.size > 8 * 1024 * 1024) {
        setState(() => error = 'La photo de profil ne doit pas dépasser 8 Mo.');
        return;
      }
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => error = 'Impossible de lire la photo sélectionnée.');
        return;
      }
      setState(() {
        pendingPhotoBytes = Uint8List.fromList(bytes);
        pendingPhotoFileName = file.name;
        removePhoto = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Impossible de sélectionner la photo.');
      }
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }

  void _markPhotoForRemoval() {
    setState(() {
      pendingPhotoBytes = null;
      pendingPhotoFileName = null;
      removePhoto = true;
      error = null;
    });
  }

  Future<void> _save() async {
    if (c['first']!.text.trim().isEmpty || c['last']!.text.trim().isEmpty) {
      setState(() => error = 'Le prénom et le nom sont obligatoires.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      var updated = await widget.service.update(
        firstName: c['first']!.text,
        lastName: c['last']!.text,
        phone: c['phone']!.text,
        department: c['department']!.text,
        cursus: c['cursus']!.text,
        studyLevel: c['level']!.text,
        specialty: c['specialty']!.text,
        promotion: c['promotion']!.text,
        bio: c['bio']!.text,
        linkedinUrl: c['linkedin']!.text,
        githubUrl: c['github']!.text,
        portfolioUrl: c['portfolio']!.text,
      );
      if (removePhoto && widget.profile.photoUrl?.trim().isNotEmpty == true) {
        updated = await widget.service.deletePhoto();
      } else if (pendingPhotoBytes != null && pendingPhotoFileName != null) {
        updated = await widget.service.uploadPhoto(
          bytes: pendingPhotoBytes!,
          fileName: pendingPhotoFileName!,
        );
      }
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Modifier mon profil',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Ces informations constituent ton profil EnactSpace.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              _photoEditor(context),
              const SizedBox(height: 18),
              _field('Prénom', 'first'),
              _field('Nom', 'last'),
              _field('Téléphone', 'phone'),
              _field('Département ESP', 'department'),
              _field('Cursus', 'cursus'),
              _field('Niveau d’études', 'level'),
              _field('Spécialité', 'specialty'),
              _field('Promotion', 'promotion'),
              _field('Bio', 'bio', lines: 4),
              _field('LinkedIn', 'linkedin'),
              _field('GitHub', 'github'),
              _field('Portfolio', 'portfolio'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoEditor(BuildContext context) {
    final image = pendingPhotoBytes != null
        ? MemoryImage(pendingPhotoBytes!) as ImageProvider<Object>
        : removePhoto
        ? null
        : _imageProvider(widget.profile.photoUrl);
    final hasPhoto =
        pendingPhotoBytes != null ||
        (!removePhoto && widget.profile.photoUrl?.trim().isNotEmpty == true);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: AppTheme.enactusYellow,
              foregroundColor: AppTheme.softBlack,
              backgroundImage: image,
              child: image == null
                  ? Text(
                      _initials(widget.profile.displayName),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Photo de profil',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elle apparaîtra aussi dans la liste des membres et dans le chat.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: saving || pickingPhoto ? null : _pickPhoto,
                        icon: pickingPhoto
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_camera_rounded),
                        label: Text(
                          hasPhoto ? 'Changer la photo' : 'Choisir une photo',
                        ),
                      ),
                      if (hasPhoto)
                        TextButton.icon(
                          onPressed: saving ? null : _markPhotoForRemoval,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Supprimer'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'JPEG, PNG ou WebP · 8 Mo maximum',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String key, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c[key],
        maxLines: lines,
        textCapitalization:
            const {'phone', 'linkedin', 'github', 'portfolio'}.contains(key)
            ? TextCapitalization.none
            : lines > 1
            ? TextCapitalization.sentences
            : TextCapitalization.words,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ProfileError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.person_off_outlined, size: 42),
          const SizedBox(height: 12),
          const Text(
            'Impossible de charger le profil.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

ImageProvider<Object>? _imageProvider(String? value) {
  final url = value?.trim() ?? '';
  if (url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri != null && {'http', 'https'}.contains(uri.scheme)) {
    return NetworkImage(url);
  }
  final absolute =
      '${ApiClient.serverUrl}${url.startsWith('/') ? '' : '/'}$url';
  return NetworkImage(absolute);
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'E';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

bool _hasText(String? value) => value?.trim().isNotEmpty == true;
