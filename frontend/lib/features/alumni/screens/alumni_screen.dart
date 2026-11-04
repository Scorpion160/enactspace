import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ui/app_components.dart';
import '../../../shared/ui/app_filter_toolbar.dart';
import '../../members/models/member_model.dart';
import '../../members/widgets/searchable_member_picker.dart';
import '../../poles/models/pole_model.dart';
import '../../projects/models/project_model.dart';
import '../models/alumni_directory.dart';
import '../models/alumni_profile_model.dart';
import '../models/mentorship_model.dart';
import '../services/alumni_error_message.dart';
import '../services/alumni_gateway.dart';
import '../widgets/alumni_avatar.dart';
import '../widgets/alumni_community_hero.dart';

class AlumniScreen extends StatefulWidget {
  final AlumniGateway? gateway;
  const AlumniScreen({super.key, this.gateway});

  @override
  State<AlumniScreen> createState() => _AlumniScreenState();
}

class _AlumniScreenState extends State<AlumniScreen>
    with SingleTickerProviderStateMixin {
  late final AlumniGateway _gateway;
  late final TabController _tabs;
  int _loadSequence = 0;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  bool _mentorsOnly = false;
  String _mentorshipStatus = 'all';
  int? _graduationYear;
  String? _domain;
  Set<String> _availableMentorIds = {};
  UserExperience? _userExperience;

  List<AlumniProfileModel> _profiles = [];
  List<MentorshipModel> _mentorships = [];
  List<MemberModel> _members = [];
  List<ProjectModel> _projects = [];
  List<PoleModel> _poles = [];

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiAlumniGateway();
    _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);
    _loadAlumni();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  Future<void> _loadAlumni() async {
    final request = ++_loadSequence;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _gateway.loadCenter();
      if (!mounted || request != _loadSequence) return;
      setState(() {
        _userExperience = data.user;
        _profiles = data.profiles;
        _mentorships = data.mentorships;
        _members = data.members;
        _projects = data.projects;
        _poles = data.poles;
        _availableMentorIds = {
          for (final profile in data.profiles)
            if (data.isMentorAvailable(profile)) profile.userId,
        };
        if (!_years.contains(_graduationYear)) _graduationYear = null;
        if (!_domains.containsKey(_domain)) _domain = null;
      });
    } catch (error) {
      if (!mounted || request != _loadSequence) return;
      setState(() => _error = alumniErrorMessage(error));
    } finally {
      if (mounted && request == _loadSequence) {
        setState(() => _loading = false);
      }
    }
  }

  List<int> get _years =>
      {for (final profile in _profiles) ?profile.graduationYear}.toList()
        ..sort((left, right) => right.compareTo(left));

  Map<String, String> get _domains {
    final names = <String, String>{};
    for (final profile in _profiles) {
      final label = profile.domain?.trim() ?? '';
      if (label.isNotEmpty) {
        names.putIfAbsent(MemberModel.alphabeticKey(label), () => label);
      }
    }
    return Map.fromEntries(
      names.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key)),
    );
  }

  int get _directoryFilterCount =>
      (_searchController.text.trim().isNotEmpty ? 1 : 0) +
      (_mentorsOnly ? 1 : 0) +
      (_graduationYear != null ? 1 : 0) +
      (_domain != null ? 1 : 0);

  void _resetDirectoryFilters({bool mentorsOnly = false}) {
    setState(() {
      _searchController.clear();
      _mentorsOnly = mentorsOnly;
      _graduationYear = null;
      _domain = null;
    });
  }

  Future<void> _openProfile(AlumniProfileModel profile) async {
    final mentorId = await context.push<String>(
      '/alumni/${profile.id}',
      extra: AlumniProfileRouteArgs(_gateway),
    );
    if (!mounted) return;
    await _loadAlumni();
    if (!mounted ||
        mentorId == null ||
        _error != null ||
        !_canCreateMentorship) {
      return;
    }
    _tabs.animateTo(1);
    if (!_availableMentorIds.contains(mentorId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce mentor n’est plus disponible.')),
      );
      return;
    }
    await _openCreateMentorshipSheet(mentorId: mentorId);
  }

  Map<String, MemberModel> get _membersById {
    return {for (final member in _members) member.id: member};
  }

  Map<String, ProjectModel> get _projectsById {
    return {for (final project in _projects) project.id: project};
  }

  Map<String, PoleModel> get _polesById {
    return {for (final pole in _poles) pole.id: pole};
  }

  Future<void> _openCreateProfileSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _CreateProfileSheet(
          gateway: _gateway,
          members: _members,
          existingProfiles: _profiles,
          currentUserId: _userExperience?.id,
          canSelectUser: _canManageAlumni,
        );
      },
    );

    if (mounted && created == true) await _loadAlumni();
  }

  bool get _canManageAlumni => _userExperience?.canManageMembers == true;

  bool get _canCreateOwnProfile {
    final user = _userExperience;
    if (user == null ||
        user.status != 'alumni' ||
        user.profileType != 'alumni') {
      return false;
    }
    return !_profiles.any((profile) => profile.userId == user.id);
  }

  bool get _canCreateProfile => _canManageAlumni || _canCreateOwnProfile;
  bool get _canCreateMentorship =>
      _userExperience?.isActiveMember == true &&
      _userExperience?.isEnacchef == true;

  Future<void> _openCreateMentorshipSheet({String? mentorId}) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _CreateMentorshipSheet(
          gateway: _gateway,
          initialMentorId: mentorId,
          profiles: filterAlumniDirectory(
            profiles: _profiles,
            membersById: _membersById,
            availableMentorIds: _availableMentorIds,
            search: '',
            mentorsOnly: true,
          ),
          membersById: _membersById,
          projects: _projects,
          poles: _poles,
        );
      },
    );

    if (mounted && created == true) await _loadAlumni();
  }

  Future<void> _manageMentorship(
    MentorshipModel mentorship,
    String action,
  ) async {
    try {
      if (action == 'complete') {
        await _gateway.completeMentorship(mentorship.id);
      } else if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Supprimer le mentorat ?'),
            content: Text(
              'Vérifie le mentorat avant de confirmer la suppression.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Supprimer'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await _gateway.deleteMentorship(mentorship.id);
      } else {
        await _gateway.updateMentorship(
          mentorship.id,
          status: action == 'pause' ? 'paused' : 'active',
        );
      }
      if (mounted) await _loadAlumni();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alumniErrorMessage(
                error,
                fallback:
                    'Impossible de mettre à jour le mentorat. Réessayez dans quelques instants.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final membersById = _membersById;
    final canWrite = !_loading && _error == null;

    return RefreshIndicator(
      onRefresh: _loadAlumni,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth < 560 ? 14.0 : 24.0;
          final scrollTabs = MediaQuery.textScalerOf(context).scale(14) > 16;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AlumniCommunityHero(
                        total: _profiles.length,
                        mentors: _availableMentorIds.length,
                        activeMentorships: _mentorships
                            .where(
                              (mentorship) => mentorship.status == 'active',
                            )
                            .length,
                        onMemories: () => _tabs.animateTo(2),
                        showHeritagePhoto: false,
                        actions: [
                          IconButton.filledTonal(
                            tooltip: 'Actualiser l’espace Alumni',
                            onPressed: _loading ? null : _loadAlumni,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                          if (canWrite && _canCreateProfile)
                            FilledButton.tonalIcon(
                              onPressed: _openCreateProfileSheet,
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: const Text('Créer un profil'),
                            ),
                        ],
                      ),
                      if (canWrite && _canCreateOwnProfile) ...[
                        const SizedBox(height: 14),
                        _AlumniProfilePrompt(
                          onCreateProfile: _openCreateProfileSheet,
                        ),
                      ],
                      const SizedBox(height: 18),
                      Card(
                        child: TabBar(
                          controller: _tabs,
                          isScrollable: scrollTabs,
                          tabAlignment: scrollTabs ? TabAlignment.start : null,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.people_outline),
                              text: 'Annuaire',
                            ),
                            Tab(
                              icon: Icon(Icons.handshake_outlined),
                              text: 'Mentorat',
                            ),
                            Tab(
                              icon: Icon(Icons.photo_library_outlined),
                              text: 'Souvenirs',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_tabs.index == 2)
                        const AlumniMemoriesCard()
                      else if (_loading)
                        const _LoadingCard()
                      else if (_error != null)
                        _ErrorCard(message: _error!, onRetry: _loadAlumni)
                      else if (_tabs.index == 0) ...[
                        Text('Annuaire', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        _AlumniToolbar(
                          searchController: _searchController,
                          mentorsOnly: _mentorsOnly,
                          years: _years,
                          domains: _domains,
                          graduationYear: _graduationYear,
                          domain: _domain,
                          activeFilterCount: _directoryFilterCount,
                          onSearch: (_) => setState(() {}),
                          onMentorsOnlyChanged: (value) =>
                              setState(() => _mentorsOnly = value),
                          onYearChanged: (value) =>
                              setState(() => _graduationYear = value),
                          onDomainChanged: (value) =>
                              setState(() => _domain = value),
                          onReset: _resetDirectoryFilters,
                        ),
                        const SizedBox(height: 16),
                        _ProfilesGrid(
                          profiles: filterAlumniDirectory(
                            profiles: _profiles,
                            membersById: membersById,
                            availableMentorIds: _availableMentorIds,
                            search: _searchController.text,
                            mentorsOnly: _mentorsOnly,
                            graduationYear: _graduationYear,
                            domain: _domain,
                          ),
                          membersById: membersById,
                          availableMentorIds: _availableMentorIds,
                          onOpen: _openProfile,
                          onReset: _directoryFilterCount > 0
                              ? _resetDirectoryFilters
                              : null,
                        ),
                      ] else ...[
                        Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Mentorat', style: theme.textTheme.titleLarge),
                            if (_canCreateMentorship)
                              FilledButton.icon(
                                onPressed: _availableMentorIds.isEmpty
                                    ? null
                                    : _openCreateMentorshipSheet,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Créer un mentorat'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppFilterToolbar(
                          collapsible: false,
                          filters: [
                            DropdownButtonFormField<String>(
                              key: ValueKey(_mentorshipStatus),
                              initialValue: _mentorshipStatus,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Statut',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Tous'),
                                ),
                                DropdownMenuItem(
                                  value: 'active',
                                  child: Text('Actifs'),
                                ),
                                DropdownMenuItem(
                                  value: 'paused',
                                  child: Text('En pause'),
                                ),
                                DropdownMenuItem(
                                  value: 'completed',
                                  child: Text('Terminés'),
                                ),
                                DropdownMenuItem(
                                  value: 'cancelled',
                                  child: Text('Annulés'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _mentorshipStatus = value);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _MentorshipsGrid(
                          mentorships: _mentorships.where((mentorship) {
                            return _mentorshipStatus == 'all' ||
                                mentorship.status == _mentorshipStatus;
                          }).toList(),
                          membersById: membersById,
                          profiles: _profiles,
                          projectsById: _projectsById,
                          polesById: _polesById,
                          canManage: _canCreateMentorship,
                          onAction: _manageMentorship,
                          emptyState: _mentorshipStatus == 'all'
                              ? _EmptyCard(
                                  message: 'Aucun mentorat pour le moment.',
                                  actionLabel: 'Voir les mentors disponibles',
                                  onAction: () {
                                    _resetDirectoryFilters(mentorsOnly: true);
                                    _tabs.animateTo(0);
                                  },
                                )
                              : _EmptyCard(
                                  message: 'Aucun mentorat avec ce statut.',
                                  actionLabel: 'Afficher tous les mentorats',
                                  onAction: () =>
                                      setState(() => _mentorshipStatus = 'all'),
                                ),
                        ),
                      ],
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

class _AlumniProfilePrompt extends StatelessWidget {
  final VoidCallback onCreateProfile;

  const _AlumniProfilePrompt({required this.onCreateProfile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.enactusYellow,
              foregroundColor: AppTheme.softBlack,
              child: Icon(Icons.badge_rounded),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complétez votre profil Alumni',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ajoutez promotion, parcours, expertises et disponibilité mentorat.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: onCreateProfile,
              icon: Icon(Icons.edit_rounded),
              label: Text('Compléter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlumniToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final bool mentorsOnly;
  final List<int> years;
  final Map<String, String> domains;
  final int? graduationYear;
  final String? domain;
  final int activeFilterCount;
  final ValueChanged<String> onSearch;
  final ValueChanged<bool> onMentorsOnlyChanged;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<String?> onDomainChanged;
  final VoidCallback onReset;

  const _AlumniToolbar({
    required this.searchController,
    required this.mentorsOnly,
    required this.years,
    required this.domains,
    required this.graduationYear,
    required this.domain,
    required this.activeFilterCount,
    required this.onSearch,
    required this.onMentorsOnlyChanged,
    required this.onYearChanged,
    required this.onDomainChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) => AppFilterToolbar(
    search: TextField(
      controller: searchController,
      onChanged: onSearch,
      decoration: const InputDecoration(
        labelText: 'Rechercher un Alumni',
        prefixIcon: Icon(Icons.search_rounded),
      ),
    ),
    quickFiltersWidth: 208,
    quickFilters: [
      FilterChip(
        selected: mentorsOnly,
        onSelected: onMentorsOnlyChanged,
        avatar: const Icon(Icons.handshake_outlined),
        label: const Text('Mentors disponibles'),
      ),
    ],
    filters: [
      DropdownButtonFormField<int>(
        key: ValueKey(('promotion', graduationYear)),
        initialValue: graduationYear ?? 0,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Promotion'),
        items: [
          const DropdownMenuItem(value: 0, child: Text('Toutes')),
          for (final year in years)
            DropdownMenuItem(value: year, child: Text('$year')),
        ],
        onChanged: (value) => onYearChanged(value == 0 ? null : value),
      ),
      DropdownButtonFormField<String>(
        key: ValueKey(('domaine', domain)),
        initialValue: domain ?? '',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Domaine'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Tous')),
          for (final entry in domains.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) => onDomainChanged(value == '' ? null : value),
      ),
    ],
    activeFilterCount: activeFilterCount,
    onReset: onReset,
  );
}

class _ProfilesGrid extends StatelessWidget {
  final List<AlumniProfileModel> profiles;
  final Map<String, MemberModel> membersById;
  final Set<String> availableMentorIds;
  final ValueChanged<AlumniProfileModel> onOpen;
  final VoidCallback? onReset;

  const _ProfilesGrid({
    required this.profiles,
    required this.membersById,
    required this.availableMentorIds,
    required this.onOpen,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return _EmptyCard(
        message: onReset == null
            ? 'Aucun profil Alumni pour le moment.'
            : 'Aucun profil ne correspond à cette recherche.',
        actionLabel: 'Réinitialiser les filtres',
        onAction: onReset,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final cardWidth = constraints.maxWidth >= 740
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final profile in profiles)
              SizedBox(
                width: cardWidth,
                child: _ProfileCard(
                  profile: profile,
                  member: membersById[profile.userId],
                  mentorAvailable: availableMentorIds.contains(profile.userId),
                  onOpen: () => onOpen(profile),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AlumniProfileModel profile;
  final MemberModel? member;
  final bool mentorAvailable;
  final VoidCallback onOpen;

  const _ProfileCard({
    required this.profile,
    required this.member,
    required this.mentorAvailable,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final name = member?.displayName ?? profile.displayName;
    final company = profile.currentCompany?.trim();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AlumniAvatar(
                    name: name,
                    photoUrl: member?.photoUrl ?? profile.photoUrl,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _safeText(
                            profile.currentPosition,
                            fallback: 'Poste non renseigné',
                          ),
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        if (company != null && company.isNotEmpty)
                          Text(
                            company,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (profile.graduationYear != null)
                    AppStatusBadge(
                      label: 'Promotion ${profile.graduationYear}',
                    ),
                  AppStatusBadge(label: profile.visibilityLabel),
                  if (mentorAvailable)
                    const AppStatusBadge(
                      label: 'Mentorat disponible',
                      tone: AppStatusTone.success,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _safeText(profile.domain, fallback: 'Domaine non renseigné'),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 5),
              Text(
                _safeText(
                  profile.experienceSummary,
                  fallback: 'Parcours à compléter.',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Voir le profil',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentorshipsGrid extends StatelessWidget {
  final List<MentorshipModel> mentorships;
  final Map<String, MemberModel> membersById;
  final List<AlumniProfileModel> profiles;
  final Map<String, ProjectModel> projectsById;
  final Map<String, PoleModel> polesById;
  final bool canManage;
  final void Function(MentorshipModel, String) onAction;
  final Widget emptyState;

  const _MentorshipsGrid({
    required this.mentorships,
    required this.membersById,
    required this.profiles,
    required this.projectsById,
    required this.polesById,
    required this.canManage,
    required this.onAction,
    required this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    if (mentorships.isEmpty) return emptyState;

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 740 ? 2 : 1;

        const spacing = 14.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final mentorship in mentorships)
              SizedBox(
                width: cardWidth,
                child: _MentorshipCard(
                  mentorship: mentorship,
                  alumniName: _alumniName(mentorship.alumniId),
                  target: _targetName(mentorship, projectsById, polesById),
                  canManage: canManage,
                  onAction: onAction,
                ),
              ),
          ],
        );
      },
    );
  }

  String _alumniName(String userId) {
    final member = membersById[userId];
    if (member != null) return member.displayName;

    for (final profile in profiles) {
      if (profile.userId == userId) return profile.displayName;
    }
    return 'Alumni';
  }

  String _targetName(
    MentorshipModel mentorship,
    Map<String, ProjectModel> projectsById,
    Map<String, PoleModel> polesById,
  ) {
    if (mentorship.projectId != null) {
      return projectsById[mentorship.projectId]?.name ?? 'Projet';
    }

    if (mentorship.poleId != null) {
      return polesById[mentorship.poleId]?.name ?? 'Pôle';
    }

    return 'Cible à préciser';
  }
}

class _MentorshipCard extends StatelessWidget {
  final MentorshipModel mentorship;
  final String alumniName;
  final String target;
  final bool canManage;
  final void Function(MentorshipModel, String) onAction;

  const _MentorshipCard({
    required this.mentorship,
    required this.alumniName,
    required this.target,
    required this.canManage,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final started = DateFormat('dd/MM/yyyy').format(mentorship.startedAt);

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
                  decoration: BoxDecoration(
                    color: AppTheme.enactusYellow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.handshake_rounded,
                    color: AppTheme.softBlack,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _safeText(mentorship.title, fallback: 'Mentorat'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$alumniName • $started',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    tooltip: 'Gérer le mentorat',
                    onSelected: (value) => onAction(mentorship, value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: mentorship.status == 'paused'
                            ? 'resume'
                            : 'pause',
                        child: Text(
                          mentorship.status == 'paused'
                              ? 'Reprendre'
                              : 'Mettre en pause',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'complete',
                        child: Text('Terminer'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Supprimer'),
                      ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppStatusBadge(
                  label: mentorship.statusLabel,
                  tone: switch (mentorship.status) {
                    'active' => AppStatusTone.success,
                    'paused' => AppStatusTone.warning,
                    'cancelled' => AppStatusTone.error,
                    _ => AppStatusTone.neutral,
                  },
                ),
                _SoftChip(icon: Icons.flag_rounded, label: target),
              ],
            ),
            SizedBox(height: 16),
            Text(
              _safeText(mentorship.objective, fallback: 'Objectif à préciser.'),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateProfileSheet extends StatefulWidget {
  final AlumniGateway gateway;
  final List<MemberModel> members;
  final List<AlumniProfileModel> existingProfiles;
  final String? currentUserId;
  final bool canSelectUser;

  const _CreateProfileSheet({
    required this.gateway,
    required this.members,
    required this.existingProfiles,
    required this.currentUserId,
    required this.canSelectUser,
  });

  @override
  State<_CreateProfileSheet> createState() => _CreateProfileSheetState();
}

class _CreateProfileSheetState extends State<_CreateProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController();
  final _companyController = TextEditingController();
  final _positionController = TextEditingController();
  final _domainController = TextEditingController();
  final _skillsController = TextEditingController();
  final _summaryController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _portfolioController = TextEditingController();

  String? _userId;
  String _visibility = 'internal';
  bool _available = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (!widget.canSelectUser) {
      _userId = widget.currentUserId;
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    _domainController.dispose();
    _skillsController.dispose();
    _summaryController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    super.dispose();
  }

  List<MemberModel> get _availableMembers {
    final usedIds = widget.existingProfiles
        .map((profile) => profile.userId)
        .toSet();
    return widget.members
        .where(
          (member) => member.status == 'alumni' && !usedIds.contains(member.id),
        )
        .toList()
      ..sort(MemberModel.compareAlphabetically);
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await widget.gateway.createProfile(
        userId: _userId!,
        graduationYear: int.tryParse(_yearController.text.trim()),
        currentCompany: _companyController.text,
        currentPosition: _positionController.text,
        domain: _domainController.text,
        skills: _skillsController.text,
        experienceSummary: _summaryController.text,
        availableForMentoring: _available,
        linkedinUrl: _linkedinController.text,
        portfolioUrl: _portfolioController.text,
        visibility: _visibility,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(alumniErrorMessage(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Créer un profil alumni',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.canSelectUser)
              SearchableMemberPickerField(
                members: _availableMembers,
                value: _userId,
                label: 'Profil Alumni',
                hintText: 'Choisir un Alumni',
                emptyText: 'Tous les Alumni disposent déjà d’un profil.',
                onChanged: (value) => setState(() => _userId = value),
                validator: (value) =>
                    value == null ? 'Choisis un utilisateur.' : null,
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.enactusYellow,
                  child: Icon(Icons.person_rounded),
                ),
                title: Text('Mon profil Alumni'),
                subtitle: Text(
                  'Ce profil sera rattaché à votre compte validé.',
                ),
              ),
            SizedBox(height: 14),
            TextFormField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Année de promotion',
                prefixIcon: Icon(Icons.school_rounded),
              ),
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Entreprise',
                prefixIcon: Icon(Icons.business_rounded),
              ),
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _positionController,
              decoration: const InputDecoration(
                labelText: 'Poste',
                prefixIcon: Icon(Icons.work_rounded),
              ),
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _domainController,
              decoration: const InputDecoration(
                labelText: 'Domaine',
                prefixIcon: Icon(Icons.public_rounded),
              ),
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _skillsController,
              decoration: const InputDecoration(
                labelText: 'Compétences',
                prefixIcon: Icon(Icons.psychology_rounded),
              ),
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _summaryController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Résumé du parcours',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(
                labelText: 'Visibilité',
                prefixIcon: Icon(Icons.visibility_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'internal', child: Text('Membres')),
                DropdownMenuItem(value: 'alumni_only', child: Text('Alumni')),
                DropdownMenuItem(
                  value: 'enacchef_only',
                  child: Text('Responsables'),
                ),
                DropdownMenuItem(value: 'private', child: Text('Privé')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _visibility = value);
              },
            ),
            SwitchListTile(
              value: _available,
              onChanged: (value) => setState(() => _available = value),
              title: Text('Disponible pour mentorat'),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.person_add_alt_rounded),
              label: Text('Créer le profil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateMentorshipSheet extends StatefulWidget {
  final AlumniGateway gateway;
  final String? initialMentorId;
  final List<AlumniProfileModel> profiles;
  final Map<String, MemberModel> membersById;
  final List<ProjectModel> projects;
  final List<PoleModel> poles;

  const _CreateMentorshipSheet({
    required this.gateway,
    this.initialMentorId,
    required this.profiles,
    required this.membersById,
    required this.projects,
    required this.poles,
  });

  @override
  State<_CreateMentorshipSheet> createState() => _CreateMentorshipSheetState();
}

class _CreateMentorshipSheetState extends State<_CreateMentorshipSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _objectiveController = TextEditingController();

  late String? _alumniId = widget.initialMentorId;
  String? _projectId;
  String? _poleId;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await widget.gateway.createMentorship(
        alumniId: _alumniId!,
        projectId: _projectId,
        poleId: _poleId,
        title: _titleController.text,
        objective: _objectiveController.text,
        status: 'active',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(alumniErrorMessage(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Créer un mentorat',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _alumniId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Alumni mentor',
                prefixIcon: Icon(Icons.school_rounded),
              ),
              items: widget.profiles.map((profile) {
                final member = widget.membersById[profile.userId];
                return DropdownMenuItem(
                  value: profile.userId,
                  child: Text(member?.displayName ?? profile.displayName),
                );
              }).toList(),
              onChanged: (value) => setState(() => _alumniId = value),
              validator: (value) =>
                  value == null ? 'Choisis un alumni mentor.' : null,
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _objectiveController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Objectif',
                prefixIcon: Icon(Icons.flag_rounded),
              ),
            ),
            SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(('projet', _projectId)),
              initialValue: _projectId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Projet lié',
                prefixIcon: Icon(Icons.rocket_launch_rounded),
              ),
              items: widget.projects.map((project) {
                return DropdownMenuItem(
                  value: project.id,
                  child: Text(project.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _projectId = value;
                  if (value != null) _poleId = null;
                });
              },
            ),
            SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(('pole', _poleId)),
              initialValue: _poleId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Pôle lié',
                prefixIcon: Icon(Icons.hub_rounded),
              ),
              items: widget.poles.map((pole) {
                return DropdownMenuItem(value: pole.id, child: Text(pole.name));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _poleId = value;
                  if (value != null) _projectId = null;
                });
              },
              validator: (_) {
                if (_projectId == null && _poleId == null) {
                  return 'Lie le mentorat à un projet ou à un pôle.';
                }
                return null;
              },
            ),
            SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.handshake_rounded),
              label: Text('Créer le mentorat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final Widget child;

  const _SheetFrame({required this.title, required this.child});

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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      side: BorderSide(color: AppTheme.enactusYellow.withValues(alpha: 0.34)),
      labelStyle: TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
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
            SizedBox(height: 12),
            Text(
              'Erreur de chargement des alumni',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyCard({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 34),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (onAction != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

String _safeText(String? value, {required String fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  return value.trim();
}
