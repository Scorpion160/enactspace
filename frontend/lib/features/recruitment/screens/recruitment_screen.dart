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

  bool _loading = true;
  String? _error;

  List<RecruitmentCampaignModel> _campaigns = [];
  List<ApplicationModel> _applications = [];

  String _selectedCampaign = 'all';
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadRecruitment();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CreateApplicationDialog(
          service: _service,
          campaigns: _campaigns,
        );
      },
    );

    if (created == true) {
      await _loadRecruitment();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidature créée avec succès.')),
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
        const SnackBar(content: Text('Compte membre créé ou associé.')),
      );
    }
  }

  int get _receivedCount {
    return _applications.where((a) => a.status == 'received').length;
  }

  int get _acceptedCount {
    return _applications.where((a) => a.status == 'accepted').length;
  }

  int get _interviewCount {
    return _applications.where((a) => a.status == 'interview').length;
  }

  double get _averageScore {
    final scored = _applications.where((a) => a.finalScore != null).toList();
    if (scored.isEmpty) return 0;

    final total = scored.fold<double>(0, (sum, a) => sum + a.finalScore!);
    return total / scored.length;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRecruitment,
      child: ListView(
        padding: const EdgeInsets.all(24),
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
            onCampaignChanged: (value) async {
              setState(() => _selectedCampaign = value);
              await _loadRecruitment();
            },
            onStatusChanged: (value) async {
              setState(() => _selectedStatus = value);
              await _loadRecruitment();
            },
            onSearch: _loadRecruitment,
          ),
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

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.7,
          ),
          itemBuilder: (context, index) {
            final stat = stats[index];

            return Container(
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    stat.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          },
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
  final ValueChanged<String> onCampaignChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onSearch;

  const _RecruitmentFilters({
    required this.searchController,
    required this.campaigns,
    required this.selectedCampaign,
    required this.selectedStatus,
    required this.onCampaignChanged,
    required this.onStatusChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Rechercher',
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
              width: 260,
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
              width: 230,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedStatus,
                decoration: const InputDecoration(labelText: 'Statut'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tous')),
                  DropdownMenuItem(value: 'received', child: Text('Reçues')),
                  DropdownMenuItem(
                    value: 'preselected',
                    child: Text('Présélectionnées'),
                  ),
                  DropdownMenuItem(
                    value: 'interview',
                    child: Text('Entretien'),
                  ),
                  DropdownMenuItem(value: 'accepted', child: Text('Acceptées')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejetées')),
                ],
                onChanged: (value) {
                  if (value != null) onStatusChanged(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationsGrid extends StatelessWidget {
  final List<ApplicationModel> applications;
  final String Function(String campaignId) campaignTitle;
  final void Function(ApplicationModel application, String status)
  onStatusChanged;
  final ValueChanged<ApplicationModel> onReview;
  final ValueChanged<ApplicationModel> onConvert;

  const _ApplicationsGrid({
    required this.applications,
    required this.campaignTitle,
    required this.onStatusChanged,
    required this.onReview,
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

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: applications.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.18,
          ),
          itemBuilder: (context, index) {
            final application = applications[index];

            return _ApplicationCard(
              application: application,
              campaignTitle: campaignTitle(application.campaignId),
              onStatusChanged: onStatusChanged,
              onReview: onReview,
              onConvert: onConvert,
            );
          },
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
  final ValueChanged<ApplicationModel> onConvert;

  const _ApplicationCard({
    required this.application,
    required this.campaignTitle,
    required this.onStatusChanged,
    required this.onReview,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
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
                    application.firstName.isEmpty
                        ? '?'
                        : application.firstName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    application.fullName,
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
              application.email,
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
                if (application.department != null)
                  Chip(label: Text(application.department!)),
                if (application.isConverted)
                  const Chip(label: Text('Compte créé')),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                application.motivation ?? 'Aucune motivation renseignée.',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, height: 1.35),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: application.status,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: const [
                DropdownMenuItem(value: 'received', child: Text('Reçue')),
                DropdownMenuItem(
                  value: 'preselected',
                  child: Text('Présélectionnée'),
                ),
                DropdownMenuItem(value: 'interview', child: Text('Entretien')),
                DropdownMenuItem(value: 'accepted', child: Text('Acceptée')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejetée')),
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
                ElevatedButton.icon(
                  onPressed:
                      application.status == 'accepted' &&
                          !application.isConverted
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
      title: const Text('Nouvelle campagne'),
      content: SizedBox(
        width: 520,
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

  final _firstNameController = TextEditingController(text: 'Alioune');
  final _lastNameController = TextEditingController(text: 'DIOP');
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController(text: 'Gestion');
  final _studyLevelController = TextEditingController(text: 'DIC1');
  final _motivationController = TextEditingController();
  final _knownFromController = TextEditingController();
  final _knowledgeController = TextEditingController();
  final _otherClubsController = TextEditingController();
  final _contributionController = TextEditingController();
  final _projectIdeasController = TextEditingController();
  final _leadershipController = TextEditingController();
  final _cvUrlController = TextEditingController();
  final _motivationLetterUrlController = TextEditingController();

  String? _campaignId;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _campaignId = widget.campaigns.isEmpty ? null : widget.campaigns.first.id;
    _emailController.text =
        'candidat${DateTime.now().millisecondsSinceEpoch}@example.com';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _studyLevelController.dispose();
    _motivationController.dispose();
    _knownFromController.dispose();
    _knowledgeController.dispose();
    _otherClubsController.dispose();
    _contributionController.dispose();
    _projectIdeasController.dispose();
    _leadershipController.dispose();
    _cvUrlController.dispose();
    _motivationLetterUrlController.dispose();
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
      await widget.service.createApplication(
        campaignId: _campaignId!,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        department: _departmentController.text,
        studyLevel: _studyLevelController.text,
        motivation: _motivationController.text,
        knownEnactusFrom: _knownFromController.text,
        enactusKnowledge: _knowledgeController.text,
        otherClubs: _otherClubsController.text,
        contribution: _contributionController.text,
        projectIdeas: _projectIdeasController.text,
        leadershipProfile: _leadershipController.text,
        cvUrl: _cvUrlController.text,
        motivationLetterUrl: _motivationLetterUrlController.text,
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
      title: const Text('Nouvelle candidature'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_error != null) _DialogError(message: _error!),
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
                const SizedBox(height: 14),
                Row(
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
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Email invalide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Département',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _studyLevelController,
                        decoration: const InputDecoration(labelText: 'Niveau'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _motivationController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motivation',
                    prefixIcon: Icon(Icons.psychology_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contributionController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Contribution possible',
                  ),
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
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _knowledgeController,
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
                  controller: _leadershipController,
                  decoration: const InputDecoration(
                    labelText: 'Profil leadership',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cvUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Lien CV',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _motivationLetterUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Lien lettre de motivation',
                    prefixIcon: Icon(Icons.link_rounded),
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
        recommendation: 'reserve',
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
      title: Text('Évaluer ${widget.application.fullName}'),
      content: SizedBox(
        width: 480,
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
  final _passwordController = TextEditingController(text: 'Enactus12345');

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
      await widget.service.convertToUser(
        applicationId: widget.application.id,
        password: _passwordController.text.trim(),
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
      title: const Text('Créer un compte membre'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Créer un compte pour ${widget.application.fullName}.'),
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
