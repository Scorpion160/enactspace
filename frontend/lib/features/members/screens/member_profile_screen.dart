import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ui/photo_preview.dart';
import '../../gamification/services/games_service.dart';
import '../models/member_model.dart';
import '../services/members_service.dart';

class MemberProfileScreen extends StatefulWidget {
  final String memberId;
  final MembersService? service;

  const MemberProfileScreen({super.key, required this.memberId, this.service});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  late final MembersService _service;
  MemberModel? _member;
  Object? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MembersService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final member = await _service.getMember(widget.memberId);
      if (mounted) setState(() => _member = member);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          if (_loading && _member == null)
            const SizedBox(
              height: 420,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _member == null)
            _ErrorCard(onRetry: _load)
          else if (_member != null)
            _MemberProfileContent(member: _member!),
        ],
      ),
    );
  }
}

class _MemberProfileContent extends StatelessWidget {
  final MemberModel member;

  const _MemberProfileContent({required this.member});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MemberHero(member: member),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final identity = _ProfileSection(
                  title: 'Identité & contact',
                  icon: Icons.badge_rounded,
                  children: [
                    _InfoLine(label: 'Profil', value: member.memberLabel),
                    _InfoLine(label: 'Email', value: member.email),
                    _InfoLine(label: 'Téléphone', value: member.phoneLabel),
                    _InfoLine(
                      label: 'Département ESP',
                      value: member.departmentLabel,
                    ),
                    _InfoLine(
                      label: 'Rôle principal',
                      value: member.primaryRoleLabel,
                    ),
                    _InfoLine(label: 'Rôles', value: member.rolesLabel),
                  ],
                );
                final journey = _ProfileSection(
                  title: 'Parcours',
                  icon: Icons.route_rounded,
                  children: [
                    _InfoLine(label: 'Cursus', value: member.cursusLabel),
                    _InfoLine(label: 'Niveau', value: member.studyLevelLabel),
                    _InfoLine(
                      label: 'Spécialité',
                      value: member.specialtyLabel,
                    ),
                    _InfoLine(label: 'Promotion', value: member.promotionLabel),
                    _InfoLine(
                      label: 'Entrée à Enactus',
                      value: member.enactusJoinYearLabel,
                    ),
                    _InfoLine(
                      label: 'Compte créé',
                      value: member.joinedAtLabel,
                    ),
                    if (member.polePosition?.trim().isNotEmpty == true)
                      _InfoLine(
                        label: 'Position pôle',
                        value: member.polePositionLabel,
                      ),
                  ],
                );
                if (constraints.maxWidth < 760) {
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
            _ProfileSection(
              title: 'À propos',
              icon: Icons.person_rounded,
              children: [
                Text(
                  member.bioLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (_hasSocialLinks(member)) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_hasText(member.linkedinUrl))
                        _ExternalLinkChip(
                          label: 'LinkedIn',
                          value: member.linkedinUrl!,
                        ),
                      if (_hasText(member.githubUrl))
                        _ExternalLinkChip(
                          label: 'GitHub',
                          value: member.githubUrl!,
                        ),
                      if (_hasText(member.portfolioUrl))
                        _ExternalLinkChip(
                          label: 'Portfolio',
                          value: member.portfolioUrl!,
                        ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _ActivityCard(member: member),
          ],
        ),
      ),
    );
  }
}

class _MemberHero extends StatelessWidget {
  final MemberModel member;

  const _MemberHero({required this.member});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final copyWidth = narrow
        ? (MediaQuery.sizeOf(context).width - 92).clamp(180.0, 480.0)
        : 480.0;
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
            image: _imageProvider(member.photoUrl),
            title: member.displayName,
            child: CircleAvatar(
              radius: 38,
              backgroundColor: AppTheme.enactusYellow,
              foregroundColor: AppTheme.softBlack,
              backgroundImage: _imageProvider(member.photoUrl),
              child: member.photoUrl?.trim().isNotEmpty == true
                  ? null
                  : Text(
                      _initials(member.displayName),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          SizedBox(
            width: copyWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${member.primaryRoleLabel} · ${member.statusLabel}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  member.departmentLabel,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final MemberModel member;
  const _ActivityCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      title: 'Vie Enactus & contributions',
      icon: Icons.auto_graph_rounded,
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: GamesService().profile(member.id),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) return const SizedBox.shrink();
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(label: 'Points', value: '${data['points'] ?? 0}'),
                _Metric(label: 'Victoires', value: '${data['wins'] ?? 0}'),
                _Metric(label: 'Parties', value: '${data['games'] ?? 0}'),
                if (data['badges'] is List)
                  _Metric(
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
            OutlinedButton.icon(
              onPressed: () => context.go(
                '/archives?member_id=${Uri.encodeQueryComponent(member.id)}',
              ),
              icon: const Icon(Icons.history_edu_rounded),
              label: const Text('Voir sa mémoire'),
            ),
            if (member.isAlumni)
              const Chip(
                avatar: Icon(Icons.workspace_premium_rounded, size: 18),
                label: Text('Alumni Enactus ESP'),
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
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

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

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

class _ExternalLinkChip extends StatelessWidget {
  final String label;
  final String value;

  const _ExternalLinkChip({required this.label, required this.value});

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

class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.person_off_outlined, size: 44),
          const SizedBox(height: 12),
          const Text(
            'Impossible de charger ce profil.',
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
bool _hasSocialLinks(MemberModel member) =>
    _hasText(member.linkedinUrl) ||
    _hasText(member.githubUrl) ||
    _hasText(member.portfolioUrl);
