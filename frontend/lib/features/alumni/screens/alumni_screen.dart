import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/alumni_profile_model.dart';
import '../models/mentorship_model.dart';
import '../services/alumni_service.dart';

class AlumniScreen extends StatefulWidget {
  const AlumniScreen({super.key});

  @override
  State<AlumniScreen> createState() => _AlumniScreenState();
}

class _AlumniScreenState extends State<AlumniScreen> {
  final AlumniService _alumniService = AlumniService();
  final MembersService _membersService = MembersService();
  final ProjectsService _projectsService = ProjectsService();
  final PolesService _polesService = PolesService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  bool _mentorsOnly = false;
  String _mentorshipStatus = 'all';

  List<AlumniProfileModel> _profiles = [];
  List<MentorshipModel> _mentorships = [];
  List<MemberModel> _members = [];
  List<ProjectModel> _projects = [];
  List<PoleModel> _poles = [];

  @override
  void initState() {
    super.initState();
    _loadAlumni();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAlumni() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profiles = await _alumniService.getProfiles(
        search: _searchController.text,
        availableForMentoring: _mentorsOnly ? true : null,
      );
      final mentorships = await _alumniService.getMentorships(
        status: _mentorshipStatus,
      );

      final members = await _safe(() => _membersService.getMembers());
      final projects = await _safe(() => _projectsService.getProjects());
      final poles = await _safe(() => _polesService.getPoles());

      if (!mounted) return;

      setState(() {
        _profiles = profiles;
        _mentorships = mentorships;
        _members = members;
        _projects = projects;
        _poles = poles;
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

  Future<List<T>> _safe<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return [];
    }
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
          service: _alumniService,
          members: _members,
          existingProfiles: _profiles,
        );
      },
    );

    if (created == true) await _loadAlumni();
  }

  Future<void> _openCreateMentorshipSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _CreateMentorshipSheet(
          service: _alumniService,
          profiles: _profiles,
          membersById: _membersById,
          projects: _projects,
          poles: _poles,
        );
      },
    );

    if (created == true) await _loadAlumni();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: RefreshIndicator(
        onRefresh: _loadAlumni,
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
                        _AlumniHeader(
                          total: _profiles.length,
                          mentors: _profiles
                              .where((profile) => profile.availableForMentoring)
                              .length,
                          activeMentorships: _mentorships
                              .where(
                                (mentorship) => mentorship.status == 'active',
                              )
                              .length,
                          onCreateProfile: _openCreateProfileSheet,
                          onCreateMentorship: _openCreateMentorshipSheet,
                          onRefresh: _loadAlumni,
                        ),
                        const SizedBox(height: 18),
                        _AlumniToolbar(
                          searchController: _searchController,
                          mentorsOnly: _mentorsOnly,
                          mentorshipStatus: _mentorshipStatus,
                          onSearch: _loadAlumni,
                          onMentorsOnlyChanged: (value) async {
                            setState(() => _mentorsOnly = value);
                            await _loadAlumni();
                          },
                          onMentorshipStatusChanged: (value) async {
                            setState(() => _mentorshipStatus = value);
                            await _loadAlumni();
                          },
                        ),
                        const SizedBox(height: 18),
                        const Card(
                          child: TabBar(
                            tabs: [
                              Tab(
                                icon: Icon(Icons.school_rounded),
                                text: 'Annuaire',
                              ),
                              Tab(
                                icon: Icon(Icons.handshake_rounded),
                                text: 'Mentorat',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (_loading)
                          const _LoadingCard()
                        else if (_error != null)
                          _ErrorCard(message: _error!, onRetry: _loadAlumni)
                        else
                          SizedBox(
                            height: _tabHeight(
                              context,
                              _profiles.length,
                              _mentorships.length,
                            ),
                            child: TabBarView(
                              children: [
                                _ProfilesGrid(
                                  profiles: _profiles,
                                  membersById: _membersById,
                                ),
                                _MentorshipsGrid(
                                  mentorships: _mentorships,
                                  membersById: _membersById,
                                  projectsById: _projectsById,
                                  polesById: _polesById,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AlumniHeader extends StatelessWidget {
  final int total;
  final int mentors;
  final int activeMentorships;
  final VoidCallback onCreateProfile;
  final VoidCallback onCreateMentorship;
  final VoidCallback onRefresh;

  const _AlumniHeader({
    required this.total,
    required this.mentors,
    required this.activeMentorships,
    required this.onCreateProfile,
    required this.onCreateMentorship,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;

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
                  child: _HeaderText(
                    total: total,
                    mentors: mentors,
                    activeMentorships: activeMentorships,
                  ),
                ),
                const SizedBox(width: 18),
                _HeaderActions(
                  onCreateProfile: onCreateProfile,
                  onCreateMentorship: onCreateMentorship,
                  onRefresh: onRefresh,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderIcon(),
                const SizedBox(height: 18),
                _HeaderText(
                  total: total,
                  mentors: mentors,
                  activeMentorships: activeMentorships,
                ),
                const SizedBox(height: 18),
                _HeaderActions(
                  onCreateProfile: onCreateProfile,
                  onCreateMentorship: onCreateMentorship,
                  onRefresh: onRefresh,
                ),
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
      child: const Icon(
        Icons.school_rounded,
        color: AppTheme.softBlack,
        size: 36,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final int total;
  final int mentors;
  final int activeMentorships;

  const _HeaderText({
    required this.total,
    required this.mentors,
    required this.activeMentorships,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alumni & Mentorat',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Un pont vivant entre anciens, Enacteurs, projets et pôles.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeaderChip(label: '$total alumni'),
            _HeaderChip(label: '$mentors mentor(s)'),
            _HeaderChip(label: '$activeMentorships mentorat(s) actif(s)'),
          ],
        ),
      ],
    );
  }
}

class _HeaderActions extends StatelessWidget {
  final VoidCallback onCreateProfile;
  final VoidCallback onCreateMentorship;
  final VoidCallback onRefresh;

  const _HeaderActions({
    required this.onCreateProfile,
    required this.onCreateMentorship,
    required this.onRefresh,
  });

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
          onPressed: onCreateProfile,
          icon: const Icon(Icons.person_add_alt_rounded),
          label: const Text('Profil alumni'),
        ),
        ElevatedButton.icon(
          onPressed: onCreateMentorship,
          icon: const Icon(Icons.handshake_rounded),
          label: const Text('Mentorat'),
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

class _AlumniToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final bool mentorsOnly;
  final String mentorshipStatus;
  final VoidCallback onSearch;
  final ValueChanged<bool> onMentorsOnlyChanged;
  final ValueChanged<String> onMentorshipStatusChanged;

  const _AlumniToolbar({
    required this.searchController,
    required this.mentorsOnly,
    required this.mentorshipStatus,
    required this.onSearch,
    required this.onMentorsOnlyChanged,
    required this.onMentorshipStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final searchWidth = constraints.maxWidth >= 760
                ? 360.0
                : constraints.maxWidth;
            final filterWidth = constraints.maxWidth >= 520
                ? 240.0
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: searchWidth,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Rechercher alumni',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: onSearch,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                    onSubmitted: (_) => onSearch(),
                  ),
                ),
                FilterChip(
                  selected: mentorsOnly,
                  onSelected: onMentorsOnlyChanged,
                  avatar: const Icon(Icons.handshake_rounded),
                  label: const Text('Mentors disponibles'),
                ),
                SizedBox(
                  width: filterWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue: mentorshipStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Mentorats'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tous')),
                      DropdownMenuItem(value: 'active', child: Text('Actifs')),
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
                      if (value != null) onMentorshipStatusChanged(value);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfilesGrid extends StatelessWidget {
  final List<AlumniProfileModel> profiles;
  final Map<String, MemberModel> membersById;

  const _ProfilesGrid({required this.profiles, required this.membersById});

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const _EmptyCard(message: 'Aucun profil alumni pour le moment.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 740
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: profiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: count == 1 ? 0.88 : 0.82,
          ),
          itemBuilder: (context, index) {
            final profile = profiles[index];
            return _ProfileCard(
              profile: profile,
              member: membersById[profile.userId],
            );
          },
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AlumniProfileModel profile;
  final MemberModel? member;

  const _ProfileCard({required this.profile, required this.member});

  @override
  Widget build(BuildContext context) {
    final name = member?.displayName ?? 'Alumni';
    final skills = _splitSkills(profile.skills);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.enactusYellow,
                  foregroundColor: AppTheme.softBlack,
                  child: Text(_initials(name)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _safeText(
                          profile.currentPosition,
                          fallback: 'Position à préciser',
                        ),
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
                _SoftChip(
                  icon: Icons.business_rounded,
                  label: _safeText(
                    profile.currentCompany,
                    fallback: 'Entreprise',
                  ),
                ),
                if (profile.graduationYear != null)
                  _SoftChip(
                    icon: Icons.school_rounded,
                    label: 'Promo ${profile.graduationYear}',
                  ),
                if (profile.availableForMentoring)
                  const _SoftChip(
                    icon: Icons.handshake_rounded,
                    label: 'Mentorat',
                    highlighted: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _safeText(
                profile.experienceSummary,
                fallback: 'Parcours à compléter.',
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 14),
            if (skills.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills.take(5).map((skill) {
                  return Chip(label: Text(skill));
                }).toList(),
              ),
            const SizedBox(height: 16),
            const Divider(height: 26),
            Row(
              children: [
                const Icon(Icons.public_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _safeText(profile.domain, fallback: 'Domaine à préciser'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  profile.visibilityLabel,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MentorshipsGrid extends StatelessWidget {
  final List<MentorshipModel> mentorships;
  final Map<String, MemberModel> membersById;
  final Map<String, ProjectModel> projectsById;
  final Map<String, PoleModel> polesById;

  const _MentorshipsGrid({
    required this.mentorships,
    required this.membersById,
    required this.projectsById,
    required this.polesById,
  });

  @override
  Widget build(BuildContext context) {
    if (mentorships.isEmpty) {
      return const _EmptyCard(message: 'Aucun mentorat pour le moment.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 740
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: mentorships.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: count == 1 ? 1.15 : 0.95,
          ),
          itemBuilder: (context, index) {
            final mentorship = mentorships[index];
            return _MentorshipCard(
              mentorship: mentorship,
              alumniName:
                  membersById[mentorship.alumniId]?.displayName ?? 'Alumni',
              target: _targetName(mentorship, projectsById, polesById),
            );
          },
        );
      },
    );
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

  const _MentorshipCard({
    required this.mentorship,
    required this.alumniName,
    required this.target,
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
                  child: const Icon(
                    Icons.handshake_rounded,
                    color: AppTheme.softBlack,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _safeText(mentorship.title, fallback: 'Mentorat'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$alumniName • $started',
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
                _SoftChip(
                  icon: Icons.timeline_rounded,
                  label: mentorship.statusLabel,
                  highlighted: mentorship.status == 'active',
                ),
                _SoftChip(icon: Icons.flag_rounded, label: target),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _safeText(mentorship.objective, fallback: 'Objectif à préciser.'),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateProfileSheet extends StatefulWidget {
  final AlumniService service;
  final List<MemberModel> members;
  final List<AlumniProfileModel> existingProfiles;

  const _CreateProfileSheet({
    required this.service,
    required this.members,
    required this.existingProfiles,
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
        .where((member) => !usedIds.contains(member.id))
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await widget.service.createProfile(
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
          content: Text(e.toString().replaceAll('Exception: ', '')),
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
            DropdownButtonFormField<String>(
              initialValue: _userId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Utilisateur',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              items: _availableMembers.map((member) {
                return DropdownMenuItem(
                  value: member.id,
                  child: Text(member.displayName),
                );
              }).toList(),
              onChanged: (value) => setState(() => _userId = value),
              validator: (value) =>
                  value == null ? 'Choisis un utilisateur.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Année de promotion',
                prefixIcon: Icon(Icons.school_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Entreprise',
                prefixIcon: Icon(Icons.business_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _positionController,
              decoration: const InputDecoration(
                labelText: 'Poste',
                prefixIcon: Icon(Icons.work_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _domainController,
              decoration: const InputDecoration(
                labelText: 'Domaine',
                prefixIcon: Icon(Icons.public_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _skillsController,
              decoration: const InputDecoration(
                labelText: 'Compétences',
                prefixIcon: Icon(Icons.psychology_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _summaryController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Résumé du parcours',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(
                labelText: 'Visibilité',
                prefixIcon: Icon(Icons.visibility_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'internal', child: Text('Interne')),
                DropdownMenuItem(value: 'alumni_only', child: Text('Alumni')),
                DropdownMenuItem(value: 'enacchef_only', child: Text('Bureau')),
                DropdownMenuItem(value: 'private', child: Text('Privé')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _visibility = value);
              },
            ),
            SwitchListTile(
              value: _available,
              onChanged: (value) => setState(() => _available = value),
              title: const Text('Disponible pour mentorat'),
            ),
            const SizedBox(height: 16),
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
                  : const Icon(Icons.person_add_alt_rounded),
              label: const Text('Créer le profil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateMentorshipSheet extends StatefulWidget {
  final AlumniService service;
  final List<AlumniProfileModel> profiles;
  final Map<String, MemberModel> membersById;
  final List<ProjectModel> projects;
  final List<PoleModel> poles;

  const _CreateMentorshipSheet({
    required this.service,
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

  String? _alumniId;
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await widget.service.createMentorship(
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
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mentorProfiles = widget.profiles
        .where((profile) => profile.availableForMentoring)
        .toList();

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
              items: mentorProfiles.map((profile) {
                final member = widget.membersById[profile.userId];
                return DropdownMenuItem(
                  value: profile.userId,
                  child: Text(member?.displayName ?? 'Alumni'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _alumniId = value),
              validator: (value) =>
                  value == null ? 'Choisis un alumni mentor.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _objectiveController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Objectif',
                prefixIcon: Icon(Icons.flag_rounded),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
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
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
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
                  : const Icon(Icons.handshake_rounded),
              label: const Text('Créer le mentorat'),
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
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
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
  final bool highlighted;

  const _SoftChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: highlighted
          ? AppTheme.enactusYellow
          : AppTheme.enactusYellow.withValues(alpha: 0.14),
      side: BorderSide(color: AppTheme.enactusYellow.withValues(alpha: 0.34)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
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
              'Erreur de chargement des alumni',
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

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Center(child: Text(message, textAlign: TextAlign.center)),
      ),
    );
  }
}

double _tabHeight(BuildContext context, int profiles, int mentorships) {
  final width = MediaQuery.sizeOf(context).width;
  final maxItems = profiles > mentorships ? profiles : mentorships;
  final columns = width >= 1120
      ? 3
      : width >= 740
      ? 2
      : 1;
  final rows = (maxItems / columns).ceil().clamp(1, 20);
  final cardHeight = width >= 740 ? 450.0 : 390.0;

  return rows * cardHeight + (rows - 1) * 14;
}

String _safeText(String? value, {required String fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  return value.trim();
}

List<String> _splitSkills(String? value) {
  if (value == null || value.trim().isEmpty) return [];
  return value
      .split(RegExp(r'[,;]'))
      .map((skill) => skill.trim())
      .where((skill) => skill.isNotEmpty)
      .toList();
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
