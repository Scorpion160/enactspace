import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/application_model.dart';
import '../models/recruitment_campaign_model.dart';
import '../services/recruitment_service.dart';

class RecruitmentScreen extends StatefulWidget {
  const RecruitmentScreen({super.key});

  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen> {
  final RecruitmentService _service = RecruitmentService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _poleFilterController = TextEditingController();
  final TextEditingController _projectFilterController =
      TextEditingController();
  final TextEditingController _departmentFilterController =
      TextEditingController();
  final TextEditingController _classFilterController = TextEditingController();

  bool _loading = true;
  bool _anonymousReview = false;
  String? _error;

  List<RecruitmentCampaignModel> _campaigns = [];
  List<ApplicationModel> _applications = [];

  String _selectedCampaign = 'all';
  String _selectedStatus = 'all';
  String _selectedGender = 'all';

  @override
  void initState() {
    super.initState();
    _loadRecruitment();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _poleFilterController.dispose();
    _projectFilterController.dispose();
    _departmentFilterController.dispose();
    _classFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadRecruitment() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final campaigns = await _service.getCampaigns();

      final applications = await _service.getApplications(
        campaignId: _selectedCampaign,
        status: _selectedStatus,
        search: _searchController.text,
        preferredPole: _poleFilterController.text,
        projectInterest: _projectFilterController.text,
        department: _departmentFilterController.text,
        className: _classFilterController.text,
        gender: _selectedGender,
        anonymized: _anonymousReview,
      );

      if (!mounted) return;

      setState(() {
        _campaigns = campaigns;
        _applications = applications;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _campaignTitle(String campaignId) {
    try {
      return _campaigns.firstWhere((c) => c.id == campaignId).title;
    } catch (_) {
      return 'Campagne inconnue';
    }
  }

  Future<void> _openCreateCampaignDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => CreateCampaignDialog(service: _service),
    );

    if (created == true) {
      await _loadRecruitment();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campagne créée avec succès.')),
      );
    }
  }

  Future<void> _openCreateApplicationDialog() async {
    if (_campaigns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Créez d’abord une campagne.')),
      );
      return;
    }

    final created = await showDialog<ApplicationModel>(
      context: context,
      builder: (context) {
        return CreateApplicationDialog(
          service: _service,
          campaigns: _campaigns,
        );
      },
    );

    if (created != null) {
      await _loadRecruitment();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Candidature enregistrée'),
          content: SelectableText(
            'Code de suivi : ${created.publicTrackingCode}\n\n'
            'Le candidat doit conserver ce code et utiliser son '
            'adresse email pour suivre son dossier.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _changeStatus(
    ApplicationModel application,
    String status,
  ) async {
    try {
      await _service.changeApplicationStatus(
        applicationId: application.id,
        status: status,
      );

      await _loadRecruitment();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Statut mis à jour.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openReviewDialog(ApplicationModel application) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ReviewApplicationDialog(
          service: _service,
          application: application,
        );
      },
    );

    if (created == true) {
      await _loadRecruitment();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Évaluation enregistrée.')));
    }
  }

  Future<void> _openInterviewDialog(ApplicationModel application) async {
    final scheduled = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ScheduleInterviewDialog(
          service: _service,
          application: application,
        );
      },
    );

    if (scheduled == true) {
      await _loadRecruitment();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entretien programmé.')));
    }
  }

  Future<void> _openConvertDialog(ApplicationModel application) async {
    if (application.status != 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La candidature doit être acceptée avant conversion.'),
        ),
      );
      return;
    }

    final converted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ConvertApplicationDialog(
          service: _service,
          application: application,
        );
      },
    );

    if (converted == true) {
      await _loadRecruitment();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Compte membre créé ou associé. Parcours Academy Nouveau membre préparé.',
          ),
        ),
      );
    }
  }

  int get _receivedCount {
    return _applications
        .where((a) => a.status == 'submitted' || a.status == 'received')
        .length;
  }

  int get _acceptedCount {
    return _applications.where((a) => a.status == 'accepted').length;
  }

  int get _interviewCount {
    return _applications
        .where(
          (a) => a.status == 'interview_scheduled' || a.status == 'interview',
        )
        .length;
  }

  double get _averageScore {
    final scored = _applications.where((a) => a.finalScore != null).toList();
    if (scored.isEmpty) return 0;

    final total = scored.fold<double>(0, (sum, a) => sum + a.finalScore!);
    return total / scored.length;
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 560
        ? 14.0
        : 24.0;

    return RefreshIndicator(
      onRefresh: _loadRecruitment,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          20,
          horizontalPadding,
          28,
        ),
        children: [
          _RecruitmentHeader(
            campaigns: _campaigns.length,
            applications: _applications.length,
            received: _receivedCount,
            interview: _interviewCount,
            accepted: _acceptedCount,
            averageScore: _averageScore,
            onRefresh: _loadRecruitment,
            onCreateCampaign: _openCreateCampaignDialog,
            onCreateApplication: _openCreateApplicationDialog,
          ),
          const SizedBox(height: 18),
          _RecruitmentFilters(
            searchController: _searchController,
            campaigns: _campaigns,
            selectedCampaign: _selectedCampaign,
            selectedStatus: _selectedStatus,
            selectedGender: _selectedGender,
            poleController: _poleFilterController,
            projectController: _projectFilterController,
            departmentController: _departmentFilterController,
            classController: _classFilterController,
            anonymousReview: _anonymousReview,
            onCampaignChanged: (value) async {
              setState(() => _selectedCampaign = value);
              await _loadRecruitment();
            },
            onStatusChanged: (value) async {
              setState(() => _selectedStatus = value);
              await _loadRecruitment();
            },
            onGenderChanged: (value) async {
              setState(() => _selectedGender = value);
              await _loadRecruitment();
            },
            onAnonymousChanged: (value) async {
              setState(() {
                _anonymousReview = value;
                if (value) _searchController.clear();
              });
              await _loadRecruitment();
            },
            onSearch: _loadRecruitment,
          ),
          const SizedBox(height: 16),
          _RecruitmentMethodPanel(anonymousReview: _anonymousReview),
          const SizedBox(height: 22),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _loadRecruitment)
          else if (_applications.isEmpty)
            const _EmptyRecruitmentCard()
          else
            _ApplicationsGrid(
              applications: _applications,
              campaignTitle: _campaignTitle,
              onStatusChanged: _changeStatus,
              onReview: _openReviewDialog,
              onInterview: _openInterviewDialog,
              onConvert: _openConvertDialog,
            ),
        ],
      ),
    );
  }
}

class _RecruitmentHeader extends StatelessWidget {
  final int campaigns;
  final int applications;
  final int received;
  final int interview;
  final int accepted;
  final double averageScore;
  final VoidCallback onRefresh;
  final VoidCallback onCreateCampaign;
  final VoidCallback onCreateApplication;

  const _RecruitmentHeader({
    required this.campaigns,
    required this.applications,
    required this.received,
    required this.interview,
    required this.accepted,
    required this.averageScore,
    required this.onRefresh,
    required this.onCreateCampaign,
    required this.onCreateApplication,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 860;

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
        ElevatedButton.icon(
          onPressed: onCreateCampaign,
          icon: const Icon(Icons.campaign_rounded),
          label: const Text('Nouvelle campagne'),
        ),
        ElevatedButton.icon(
          onPressed: onCreateApplication,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Nouvelle candidature'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          isWide
              ? Row(
                  children: [
                    _HeaderIcon(),
                    const SizedBox(width: 18),
                    const Expanded(child: _HeaderText()),
                    actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _HeaderIcon(),
                        const SizedBox(width: 18),
                        const Expanded(child: _HeaderText()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    actions,
                  ],
                ),
          const SizedBox(height: 20),
          _StatsGrid(
            campaigns: campaigns,
            applications: applications,
            received: received,
            interview: interview,
            accepted: accepted,
            averageScore: averageScore,
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.how_to_reg_rounded,
        color: AppTheme.softBlack,
        size: 34,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recrutement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Campagnes, candidatures, entretiens, évaluations et conversion en membres.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int campaigns;
  final int applications;
  final int received;
  final int interview;
  final int accepted;
  final double averageScore;

  const _StatsGrid({
    required this.campaigns,
    required this.applications,
    required this.received,
    required this.interview,
    required this.accepted,
    required this.averageScore,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem('Campagnes', campaigns.toString(), Icons.campaign_rounded),
      _StatItem('Candidatures', applications.toString(), Icons.people_rounded),
      _StatItem('Reçues', received.toString(), Icons.inbox_rounded),
      _StatItem(
        'Entretiens',
        interview.toString(),
        Icons.record_voice_over_rounded,
      ),
      _StatItem('Acceptées', accepted.toString(), Icons.verified_rounded),
      _StatItem(
        'Score moyen',
        '${averageScore.toStringAsFixed(1)}/20',
        Icons.star_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1100
            ? 6
            : constraints.maxWidth >= 760
            ? 3
            : 2;
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final stat in stats)
              SizedBox(
                width: itemWidth,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 116),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(stat.icon, color: AppTheme.enactusYellow),
                      const SizedBox(height: 8),
                      Text(
                        stat.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        stat.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem(this.label, this.value, this.icon);
}

class _RecruitmentFilters extends StatelessWidget {
  final TextEditingController searchController;
  final List<RecruitmentCampaignModel> campaigns;
  final String selectedCampaign;
  final String selectedStatus;
  final String selectedGender;
  final TextEditingController poleController;
  final TextEditingController projectController;
  final TextEditingController departmentController;
  final TextEditingController classController;
  final bool anonymousReview;
  final ValueChanged<String> onCampaignChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<bool> onAnonymousChanged;
  final VoidCallback onSearch;

  const _RecruitmentFilters({
    required this.searchController,
    required this.campaigns,
    required this.selectedCampaign,
    required this.selectedStatus,
    required this.selectedGender,
    required this.poleController,
    required this.projectController,
    required this.departmentController,
    required this.classController,
    required this.anonymousReview,
    required this.onCampaignChanged,
    required this.onStatusChanged,
    required this.onGenderChanged,
    required this.onAnonymousChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 760;
            final searchWidth = isCompact ? constraints.maxWidth : 280.0;
            final campaignWidth = isCompact ? constraints.maxWidth : 260.0;
            final statusWidth = isCompact ? constraints.maxWidth : 230.0;
            final textFilterWidth = isCompact ? constraints.maxWidth : 180.0;
            final switchWidth = isCompact ? constraints.maxWidth : 250.0;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: searchWidth,
                  child: TextField(
                    controller: searchController,
                    enabled: !anonymousReview,
                    decoration: InputDecoration(
                      labelText: anonymousReview
                          ? 'Recherche désactivée en mode anonymisé'
                          : 'Rechercher',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: onSearch,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                    onSubmitted: (_) => onSearch(),
                  ),
                ),
                SizedBox(
                  width: campaignWidth,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedCampaign,
                    decoration: const InputDecoration(labelText: 'Campagne'),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Toutes les campagnes'),
                      ),
                      ...campaigns.map(
                        (campaign) => DropdownMenuItem(
                          value: campaign.id,
                          child: Text(campaign.title),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onCampaignChanged(value);
                    },
                  ),
                ),
                SizedBox(
                  width: statusWidth,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tous')),
                      DropdownMenuItem(
                        value: 'submitted',
                        child: Text('Reçues'),
                      ),
                      DropdownMenuItem(
                        value: 'under_review',
                        child: Text('En étude'),
                      ),
                      DropdownMenuItem(
                        value: 'interview_scheduled',
                        child: Text('Entretiens'),
                      ),
                      DropdownMenuItem(
                        value: 'accepted',
                        child: Text('Acceptées'),
                      ),
                      DropdownMenuItem(
                        value: 'waiting_list',
                        child: Text('Liste d’attente'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejetées'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Clôturées'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onStatusChanged(value);
                    },
                  ),
                ),
                SizedBox(
                  width: statusWidth,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedGender,
                    decoration: const InputDecoration(labelText: 'Genre'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tous')),
                      DropdownMenuItem(value: 'femme', child: Text('Femme')),
                      DropdownMenuItem(value: 'homme', child: Text('Homme')),
                      DropdownMenuItem(value: 'autre', child: Text('Autre')),
                    ],
                    onChanged: (value) {
                      if (value != null) onGenderChanged(value);
                    },
                  ),
                ),
                _RecruitmentTextFilter(
                  width: textFilterWidth,
                  controller: poleController,
                  label: 'Pôle souhaité',
                  onSearch: onSearch,
                ),
                _RecruitmentTextFilter(
                  width: textFilterWidth,
                  controller: projectController,
                  label: 'Projet',
                  onSearch: onSearch,
                ),
                _RecruitmentTextFilter(
                  width: textFilterWidth,
                  controller: departmentController,
                  label: 'Département',
                  onSearch: onSearch,
                ),
                _RecruitmentTextFilter(
                  width: textFilterWidth,
                  controller: classController,
                  label: 'Classe',
                  onSearch: onSearch,
                ),
                SizedBox(
                  width: switchWidth,
                  child: SwitchListTile(
                    value: anonymousReview,
                    onChanged: onAnonymousChanged,
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text(
                      'Mode anonymisé',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Masquer identité pendant le tri'),
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

class _RecruitmentTextFilter extends StatelessWidget {
  final double width;
  final TextEditingController controller;
  final String label;
  final VoidCallback onSearch;

  const _RecruitmentTextFilter({
    required this.width,
    required this.controller,
    required this.label,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            tooltip: 'Filtrer',
            onPressed: onSearch,
            icon: const Icon(Icons.filter_alt_rounded),
          ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSearch(),
      ),
    );
  }
}

class _RecruitmentMethodPanel extends StatelessWidget {
  final bool anonymousReview;

  const _RecruitmentMethodPanel({required this.anonymousReview});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 860;
            final panelWidth = twoColumns
                ? (constraints.maxWidth - 14) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: panelWidth,
                  child: _MethodBlock(
                    icon: Icons.diversity_3_rounded,
                    title: 'Besoins RH par pôle',
                    children: const [
                      _NeedRow(
                        pole: 'Veille',
                        target: '4 profils',
                        detail: 'Analyse, enquête terrain, reporting.',
                      ),
                      _NeedRow(
                        pole: 'Projets',
                        target: '6 profils',
                        detail: 'Gestion projet, suivi impact, terrain.',
                      ),
                      _NeedRow(
                        pole: 'Communication',
                        target: '3 profils',
                        detail: 'Design, réseaux, photo/vidéo.',
                      ),
                      _NeedRow(
                        pole: 'Finance',
                        target: '2 profils',
                        detail: 'Budget, caisse, reçus, reporting.',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _MethodBlock(
                    icon: Icons.fact_check_rounded,
                    title: 'Tri objectif',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _CriterionChip('Motivation', '20%'),
                          _CriterionChip('Compréhension Enactus', '15%'),
                          _CriterionChip('Disponibilité', '15%'),
                          _CriterionChip('Compétences', '15%'),
                          _CriterionChip('Leadership', '10%'),
                          _CriterionChip('Esprit d’équipe', '10%'),
                          _CriterionChip('Potentiel', '10%'),
                          _CriterionChip('Stabilité club', '5%'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _AnonymityNotice(enabled: anonymousReview),
                    ],
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: const _RecruitmentFlowNotice(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MethodBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _MethodBlock({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.enactusYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.enactusYellow,
                foregroundColor: AppTheme.softBlack,
                child: Icon(icon),
              ),
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
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _NeedRow extends StatelessWidget {
  final String pole;
  final String target;
  final String detail;

  const _NeedRow({
    required this.pole,
    required this.target,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              pole,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  detail,
                  style: const TextStyle(color: Colors.black54, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CriterionChip extends StatelessWidget {
  final String label;
  final String weight;

  const _CriterionChip(this.label, this.weight);

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.check_circle_outline_rounded, size: 16),
      label: Text('$label · $weight'),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _AnonymityNotice extends StatelessWidget {
  final bool enabled;

  const _AnonymityNotice({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? Colors.green.shade200 : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: enabled ? Colors.green.shade700 : AppTheme.softBlack,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              enabled
                  ? 'Anonymisation active: les évaluateurs voient les codes candidat.'
                  : 'Anonymisation inactive: les identités restent visibles.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecruitmentFlowNotice extends StatelessWidget {
  const _RecruitmentFlowNotice();

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', 'Besoins pôle'),
      ('2', 'Campagne'),
      ('3', 'Tri anonyme'),
      ('4', 'Entretien'),
      ('5', 'Décision'),
      ('6', 'Compte + Academy'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Parcours recommandé',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          for (final step in steps)
            Chip(
              avatar: CircleAvatar(
                backgroundColor: AppTheme.enactusYellow,
                foregroundColor: AppTheme.softBlack,
                child: Text(step.$1),
              ),
              label: Text(step.$2),
              backgroundColor: Colors.white,
            ),
        ],
      ),
    );
  }
}

double _dialogWidth(BuildContext context, double maxWidth) {
  return (MediaQuery.sizeOf(context).width - 32).clamp(280.0, maxWidth);
}

class _ApplicationsGrid extends StatelessWidget {
  final List<ApplicationModel> applications;
  final String Function(String campaignId) campaignTitle;
  final void Function(ApplicationModel application, String status)
  onStatusChanged;
  final ValueChanged<ApplicationModel> onReview;
  final ValueChanged<ApplicationModel> onInterview;
  final ValueChanged<ApplicationModel> onConvert;

  const _ApplicationsGrid({
    required this.applications,
    required this.campaignTitle,
    required this.onStatusChanged,
    required this.onReview,
    required this.onInterview,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 780
            ? 2
            : 1;
        const spacing = 14.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final application in applications)
              SizedBox(
                width: itemWidth,
                child: _ApplicationCard(
                  application: application,
                  campaignTitle: campaignTitle(application.campaignId),
                  onStatusChanged: onStatusChanged,
                  onReview: onReview,
                  onInterview: onInterview,
                  onConvert: onConvert,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final ApplicationModel application;
  final String campaignTitle;
  final void Function(ApplicationModel application, String status)
  onStatusChanged;
  final ValueChanged<ApplicationModel> onReview;
  final ValueChanged<ApplicationModel> onInterview;
  final ValueChanged<ApplicationModel> onConvert;

  const _ApplicationCard({
    required this.application,
    required this.campaignTitle,
    required this.onStatusChanged,
    required this.onReview,
    required this.onInterview,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = application.isAnonymized
        ? application.anonymousCode
        : application.fullName;
    final avatarLabel = application.isAnonymized
        ? '#'
        : application.firstName.isEmpty
        ? '?'
        : application.firstName[0].toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.enactusYellow,
                  foregroundColor: AppTheme.softBlack,
                  child: Text(
                    avatarLabel,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              application.isAnonymized
                  ? 'Identité masquée pendant l’évaluation.'
                  : application.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              campaignTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(application.statusLabel)),
                Chip(label: Text(application.scoreLabel)),
                Chip(label: Text(application.stabilityLabel)),
                if (application.department != null)
                  Chip(label: Text(application.department!)),
                if (application.className?.trim().isNotEmpty == true)
                  Chip(label: Text(application.className!.trim())),
                if (application.preferredPole?.trim().isNotEmpty == true)
                  Chip(label: Text(application.preferredPole!.trim())),
                if (application.projectInterest?.trim().isNotEmpty == true)
                  Chip(label: Text(application.projectInterest!.trim())),
                if (application.interviewAt != null)
                  Chip(label: Text(application.interviewLabel)),
                if (application.isConverted)
                  const Chip(label: Text('Compte créé')),
              ],
            ),
            const SizedBox(height: 10),
            _ApplicationProgress(status: application.status),
            const SizedBox(height: 10),
            _ScreeningScoreBar(application: application),
            const SizedBox(height: 10),
            Text(
              application.motivation ?? 'Aucune motivation renseignée.',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: application.status,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: const [
                DropdownMenuItem(value: 'submitted', child: Text('Reçue')),
                DropdownMenuItem(
                  value: 'under_review',
                  child: Text('En étude'),
                ),
                DropdownMenuItem(
                  value: 'interview_scheduled',
                  child: Text('Entretien programmé'),
                ),
                DropdownMenuItem(value: 'accepted', child: Text('Acceptée')),
                DropdownMenuItem(
                  value: 'waiting_list',
                  child: Text('Liste d’attente'),
                ),
                DropdownMenuItem(value: 'rejected', child: Text('Rejetée')),
                DropdownMenuItem(value: 'cancelled', child: Text('Clôturée')),
              ],
              onChanged: (value) {
                if (value == null || value == application.status) return;
                onStatusChanged(application, value);
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onReview(application),
                  icon: const Icon(Icons.rate_review_rounded),
                  label: const Text('Évaluer'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onInterview(application),
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text('Entretien'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      application.status == 'accepted' &&
                          !application.isConverted &&
                          application.canConvert
                      ? () => onConvert(application)
                      : null,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Créer compte'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationProgress extends StatelessWidget {
  final String status;

  const _ApplicationProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    const steps = [
      _RecruitmentStep('submitted', 'Reçue'),
      _RecruitmentStep('under_review', 'Étude'),
      _RecruitmentStep('interview_scheduled', 'Entretien'),
      _RecruitmentStep('accepted', 'Acceptée'),
    ];

    final normalizedStatus = switch (status) {
      'received' => 'submitted',
      'preselected' => 'under_review',
      'interview' => 'interview_scheduled',
      _ => status,
    };
    final activeIndex =
        {'rejected', 'waiting_list', 'cancelled'}.contains(normalizedStatus)
        ? 3
        : steps.indexWhere((step) => step.value == normalizedStatus);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var index = 0; index < steps.length; index++)
          _ProgressChip(
            label: status == 'rejected' && index == steps.length - 1
                ? 'Rejetée'
                : status == 'waiting_list' && index == steps.length - 1
                ? 'Attente'
                : status == 'cancelled' && index == steps.length - 1
                ? 'Clôturée'
                : steps[index].label,
            active: index <= activeIndex,
            rejected:
                {'rejected', 'cancelled'}.contains(status) &&
                index == steps.length - 1,
          ),
      ],
    );
  }
}

class _ScreeningScoreBar extends StatelessWidget {
  final ApplicationModel application;

  const _ScreeningScoreBar({required this.application});

  @override
  Widget build(BuildContext context) {
    final score = application.screeningScore;
    final progress = score / 100;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  application.screeningLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '$score/100',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppTheme.enactusYellow,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecruitmentStep {
  final String value;
  final String label;

  const _RecruitmentStep(this.value, this.label);
}

class _ProgressChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool rejected;

  const _ProgressChip({
    required this.label,
    required this.active,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = rejected
        ? Colors.red.shade100
        : active
        ? AppTheme.enactusYellow.withValues(alpha: 0.34)
        : Colors.black.withValues(alpha: 0.06);
    final foregroundColor = rejected ? Colors.red.shade800 : AppTheme.softBlack;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class CreateCampaignDialog extends StatefulWidget {
  final RecruitmentService service;

  const CreateCampaignDialog({super.key, required this.service});

  @override
  State<CreateCampaignDialog> createState() => _CreateCampaignDialogState();
}

class _CreateCampaignDialogState extends State<CreateCampaignDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(
    text: 'Recrutement Enactus ESP',
  );
  final _descriptionController = TextEditingController();

  bool _isActive = true;
  bool _loading = false;
  String? _error;

  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now().add(const Duration(days: 30))),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (selected == null) return;

    setState(() {
      if (isStart) {
        _startDate = selected;
      } else {
        _endDate = selected;
      }
    });
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Non définie';

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.service.createCampaign(
        title: _titleController.text,
        description: _descriptionController.text,
        startDate: _startDate,
        endDate: _endDate,
        isActive: _isActive,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Nouvelle campagne'),
      content: SizedBox(
        width: _dialogWidth(context, 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_error != null) _DialogError(message: _error!),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    prefixIcon: Icon(Icons.campaign_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le titre est obligatoire.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.event_rounded),
                        title: const Text('Date début'),
                        subtitle: Text(_dateLabel(_startDate)),
                        trailing: TextButton(
                          onPressed: _loading
                              ? null
                              : () => _pickDate(isStart: true),
                          child: const Text('Choisir'),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.event_available_rounded),
                        title: const Text('Date fin'),
                        subtitle: Text(_dateLabel(_endDate)),
                        trailing: TextButton(
                          onPressed: _loading
                              ? null
                              : () => _pickDate(isStart: false),
                          child: const Text('Choisir'),
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  value: _isActive,
                  title: const Text('Campagne active'),
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _isActive = value);
                        },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_loading ? 'Création...' : 'Créer'),
        ),
      ],
    );
  }
}

class CreateApplicationDialog extends StatefulWidget {
  final RecruitmentService service;
  final List<RecruitmentCampaignModel> campaigns;

  const CreateApplicationDialog({
    super.key,
    required this.service,
    required this.campaigns,
  });

  @override
  State<CreateApplicationDialog> createState() =>
      _CreateApplicationDialogState();
}

class _CreateApplicationDialogState extends State<CreateApplicationDialog> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _genderController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _studyLevelController = TextEditingController();
  final _classNameController = TextEditingController();
  final _motivationController = TextEditingController();
  final _knownFromController = TextEditingController();
  final _knowledgeController = TextEditingController();
  final _otherClubsController = TextEditingController();
  final _contributionController = TextEditingController();
  final _projectIdeasController = TextEditingController();
  final _leadershipController = TextEditingController();
  final _preferredPoleController = TextEditingController();
  final _projectInterestController = TextEditingController();
  final _associativeExperienceController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _publicCommentController = TextEditingController();
  final _cvUrlController = TextEditingController();
  final _motivationLetterUrlController = TextEditingController();
  final _attachmentUrlController = TextEditingController();

  String? _campaignId;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _campaignId = widget.campaigns.isEmpty ? null : widget.campaigns.first.id;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _genderController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _studyLevelController.dispose();
    _classNameController.dispose();
    _motivationController.dispose();
    _knownFromController.dispose();
    _knowledgeController.dispose();
    _otherClubsController.dispose();
    _contributionController.dispose();
    _projectIdeasController.dispose();
    _leadershipController.dispose();
    _preferredPoleController.dispose();
    _projectInterestController.dispose();
    _associativeExperienceController.dispose();
    _availabilityController.dispose();
    _publicCommentController.dispose();
    _cvUrlController.dispose();
    _motivationLetterUrlController.dispose();
    _attachmentUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_campaignId == null) {
      setState(() {
        _error = 'Aucune campagne sélectionnée.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final application = await widget.service.createApplication(
        campaignId: _campaignId!,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        gender: _genderController.text,
        phone: _phoneController.text,
        department: _departmentController.text,
        studyLevel: _studyLevelController.text,
        className: _classNameController.text,
        motivation: _motivationController.text,
        knownEnactusFrom: _knownFromController.text,
        enactusKnowledge: _knowledgeController.text,
        otherClubs: _otherClubsController.text,
        contribution: _contributionController.text,
        projectIdeas: _projectIdeasController.text,
        leadershipProfile: _leadershipController.text,
        preferredPole: _preferredPoleController.text,
        projectInterest: _projectInterestController.text,
        associativeExperience: _associativeExperienceController.text,
        availability: _availabilityController.text,
        publicComment: _publicCommentController.text,
        cvUrl: _cvUrlController.text,
        motivationLetterUrl: _motivationLetterUrlController.text,
        attachmentUrl: _attachmentUrlController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(application);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Obligatoire.';
    return null;
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Obligatoire.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Email invalide.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Nouvelle candidature'),
      content: SizedBox(
        width: _dialogWidth(context, 620),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) _DialogError(message: _error!),
                const _ApplicationSectionHeader(
                  icon: Icons.flag_rounded,
                  title: 'Campagne',
                  subtitle:
                      'Associez la candidature a la bonne campagne active.',
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _campaignId,
                  decoration: const InputDecoration(
                    labelText: 'Campagne',
                    prefixIcon: Icon(Icons.campaign_rounded),
                  ),
                  items: widget.campaigns.map((campaign) {
                    return DropdownMenuItem(
                      value: campaign.id,
                      child: Text(campaign.title),
                    );
                  }).toList(),
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _campaignId = value);
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sélectionnez une campagne.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const _ApplicationSectionHeader(
                  icon: Icons.badge_rounded,
                  title: 'Identite',
                  subtitle:
                      'Ces informations servent au suivi, puis seront masquees en mode anonymise.',
                ),
                _AdaptiveFieldRow(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Obligatoire.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Obligatoire.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _genderController,
                        decoration: const InputDecoration(labelText: 'Genre'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _emailValidator,
                ),
                const SizedBox(height: 18),
                const _ApplicationSectionHeader(
                  icon: Icons.school_rounded,
                  title: 'Parcours',
                  subtitle:
                      'Le niveau aide a constituer une equipe stable et durable.',
                ),
                _AdaptiveFieldRow(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                        ),
                        validator: _requiredText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Département',
                        ),
                        validator: _requiredText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _studyLevelController,
                        decoration: const InputDecoration(labelText: 'Niveau'),
                        validator: _requiredText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AdaptiveFieldRow(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _classNameController,
                        decoration: const InputDecoration(labelText: 'Classe'),
                        validator: _requiredText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _preferredPoleController,
                        decoration: const InputDecoration(
                          labelText: 'Pôle souhaité',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _projectInterestController,
                        decoration: const InputDecoration(
                          labelText: 'Projet d’intérêt',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _ApplicationSectionHeader(
                  icon: Icons.psychology_rounded,
                  title: 'Motivation',
                  subtitle:
                      'Des reponses completes facilitent le tri objectif et la preparation des entretiens.',
                ),
                TextFormField(
                  controller: _motivationController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motivation',
                    prefixIcon: Icon(Icons.psychology_rounded),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contributionController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Contribution possible',
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _projectIdeasController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Idées de projet',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _knownFromController,
                  decoration: const InputDecoration(
                    labelText: 'Comment a-t-il connu Enactus ?',
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _knowledgeController,
                  validator: _requiredText,
                  decoration: const InputDecoration(
                    labelText: 'Connaissance d’Enactus',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _otherClubsController,
                  decoration: const InputDecoration(labelText: 'Autres clubs'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _associativeExperienceController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Expérience associative',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _leadershipController,
                  decoration: const InputDecoration(
                    labelText: 'Profil leadership',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _availabilityController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Disponibilité'),
                  validator: _requiredText,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _publicCommentController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire complémentaire',
                  ),
                ),
                const SizedBox(height: 18),
                const _ApplicationSectionHeader(
                  icon: Icons.attach_file_rounded,
                  title: 'Documents',
                  subtitle:
                      'Optionnel maintenant, utile si le pole veille veut approfondir le dossier.',
                ),
                TextFormField(
                  controller: _cvUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Lien CV',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _motivationLetterUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Lien lettre de motivation',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _attachmentUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Lien pièce jointe complémentaire',
                    prefixIcon: Icon(Icons.attach_file_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_loading ? 'Création...' : 'Créer'),
        ),
      ],
    );
  }
}

class _ApplicationSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ApplicationSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.22),
            foregroundColor: AppTheme.softBlack,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveFieldRow extends StatelessWidget {
  final List<Widget> children;

  const _AdaptiveFieldRow({required this.children});

  Widget _unwrapFlex(Widget child) {
    if (child is Expanded) return child.child;
    if (child is Flexible) return child.child;
    return child;
  }

  bool _isHorizontalSpacer(Widget child) {
    return child is SizedBox && child.width != null && child.height == null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        if (!compact) return Row(children: children);

        final fields = children
            .where((child) => !_isHorizontalSpacer(child))
            .map(_unwrapFlex)
            .toList();

        return Column(
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              fields[index],
            ],
          ],
        );
      },
    );
  }
}

class ScheduleInterviewDialog extends StatefulWidget {
  final RecruitmentService service;
  final ApplicationModel application;

  const ScheduleInterviewDialog({
    super.key,
    required this.service,
    required this.application,
  });

  @override
  State<ScheduleInterviewDialog> createState() =>
      _ScheduleInterviewDialogState();
}

class _ScheduleInterviewDialogState extends State<ScheduleInterviewDialog> {
  final _locationController = TextEditingController();
  final _linkController = TextEditingController();
  final _juryController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.application.interviewAt;
    if (existing != null) {
      final local = existing.toLocal();
      _selectedDate = DateTime(local.year, local.month, local.day);
      _selectedTime = TimeOfDay(hour: local.hour, minute: local.minute);
    }
    _locationController.text = widget.application.interviewLocation ?? '';
    _linkController.text = widget.application.interviewLink ?? '';
    _juryController.text = widget.application.interviewJury ?? '';
    _noteController.text = widget.application.interviewNote ?? '';
  }

  @override
  void dispose() {
    _locationController.dispose();
    _linkController.dispose();
    _juryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedTime == null) {
      setState(() => _error = 'Choisissez une date et une heure.');
      return;
    }

    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.service.scheduleInterview(
        applicationId: widget.application.id,
        interviewAt: scheduledAt,
        location: _locationController.text,
        link: _linkController.text,
        jury: _juryController.text,
        note: _noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _dateLabel {
    if (_selectedDate == null) return 'Date';
    final date = _selectedDate!;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String get _timeLabel {
    if (_selectedTime == null) return 'Heure';
    final hour = _selectedTime!.hour.toString().padLeft(2, '0');
    final minute = _selectedTime!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('Entretien - ${widget.application.fullName}'),
      content: SizedBox(
        width: _dialogWidth(context, 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) _DialogError(message: _error!),
              _AdaptiveFieldRow(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pickDate,
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(_dateLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pickTime,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(_timeLabel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Lieu',
                  prefixIcon: Icon(Icons.place_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Lien visio',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _juryController,
                decoration: const InputDecoration(
                  labelText: 'Jury / responsables',
                  prefixIcon: Icon(Icons.groups_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Note interne',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: const Icon(Icons.event_available_rounded),
          label: Text(_loading ? 'Programmation...' : 'Programmer'),
        ),
      ],
    );
  }
}

class ReviewApplicationDialog extends StatefulWidget {
  final RecruitmentService service;
  final ApplicationModel application;

  const ReviewApplicationDialog({
    super.key,
    required this.service,
    required this.application,
  });

  @override
  State<ReviewApplicationDialog> createState() =>
      _ReviewApplicationDialogState();
}

class _ReviewApplicationDialogState extends State<ReviewApplicationDialog> {
  final _scoreController = TextEditingController(text: '15');
  final _commentController = TextEditingController();
  String _recommendation = 'reserve';

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _scoreController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final score = double.tryParse(_scoreController.text.trim());

    if (score == null || score < 0 || score > 20) {
      setState(() {
        _error = 'Le score doit être compris entre 0 et 20.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.service.createReview(
        applicationId: widget.application.id,
        score: score,
        comment: _commentController.text,
        recommendation: _recommendation,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('Évaluer ${widget.application.fullName}'),
      content: SizedBox(
        width: _dialogWidth(context, 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) _DialogError(message: _error!),
            TextFormField(
              controller: _scoreController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Score',
                suffixText: '/20',
                prefixIcon: Icon(Icons.star_rounded),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _recommendation,
              decoration: const InputDecoration(
                labelText: 'Avis',
                prefixIcon: Icon(Icons.how_to_vote_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'favorable', child: Text('Favorable')),
                DropdownMenuItem(value: 'reserve', child: Text('Réservé')),
                DropdownMenuItem(
                  value: 'defavorable',
                  child: Text('Défavorable'),
                ),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _recommendation = value);
                      }
                    },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _commentController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                prefixIcon: Icon(Icons.comment_rounded),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: const Icon(Icons.save_rounded),
          label: Text(_loading ? 'Enregistrement...' : 'Enregistrer'),
        ),
      ],
    );
  }
}

class ConvertApplicationDialog extends StatefulWidget {
  final RecruitmentService service;
  final ApplicationModel application;

  const ConvertApplicationDialog({
    super.key,
    required this.service,
    required this.application,
  });

  @override
  State<ConvertApplicationDialog> createState() =>
      _ConvertApplicationDialogState();
}

class _ConvertApplicationDialogState extends State<ConvertApplicationDialog> {
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text.trim().length < 8) {
      setState(() {
        _error = 'Le mot de passe doit contenir au moins 8 caractères.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await widget.service.convertToUser(
        applicationId: widget.application.id,
        password: _passwordController.text.trim(),
      );
      final userId = response['user_id']?.toString();

      if (userId != null && userId.isNotEmpty) {
        await widget.service.prepareOnboardingAcademyPath(
          applicationId: widget.application.id,
          userId: userId,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Créer un compte membre'),
      content: SizedBox(
        width: _dialogWidth(context, 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Créer un compte pour ${widget.application.fullName}.'),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.enactusYellow.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.school_rounded, color: AppTheme.softBlack),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Le parcours Academy "Nouveau membre" sera préparé avec notification et email si le backend est disponible.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null) _DialogError(message: _error!),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe initial',
                prefixIcon: Icon(Icons.lock_rounded),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text(_loading ? 'Création...' : 'Créer'),
        ),
      ],
    );
  }
}

class _DialogError extends StatelessWidget {
  final String message;

  const _DialogError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade700)),
    );
  }
}

class _EmptyRecruitmentCard extends StatelessWidget {
  const _EmptyRecruitmentCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(26),
        child: Center(
          child: Text(
            'Aucune candidature trouvée.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
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
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement',
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
