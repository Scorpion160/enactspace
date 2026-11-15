import '../../widgets/recruitment_style.dart';
import '../../widgets/recruitment_workspace.dart';
import 'package:flutter/material.dart';

import '../../models/recruitment_campaign_model.dart';
import '../../services/recruitment_campaign_tools.dart';
import '../../services/recruitment_message.dart';
import '../../widgets/internal/jury_teams_section.dart';
import '../../widgets/internal/recruitment_interview_preparation.dart';
import '../../widgets/internal/recruitment_jury_policy_panel.dart';
import '../../widgets/internal/recruitment_viewers_section.dart';

class RecruitmentJuryScreen extends StatefulWidget {
  final ValueChanged<RecruitmentSection>? onSectionSelected;
  final bool canManageCampaigns;
  final bool enableInterviewPreparation;
  final RecruitmentCampaignTools tools;
  final List<RecruitmentCampaignModel> campaigns;
  final String? initialCampaignId;
  final Future<void> Function(String)? onOpenApplication;
  const RecruitmentJuryScreen({
    super.key,
    required this.tools,
    required this.campaigns,
    this.initialCampaignId,
    this.onOpenApplication,
    this.onSectionSelected,
    this.canManageCampaigns = true,
    this.enableInterviewPreparation = true,
  });
  @override
  State<RecruitmentJuryScreen> createState() => _RecruitmentJuryScreenState();
}

class _RecruitmentJuryScreenState extends State<RecruitmentJuryScreen> {
  final _search = TextEditingController();
  String? _campaign;
  Map<String, dynamic>? _roster;
  List<Map<String, dynamic>> _eligible = [];
  bool _busy = false;
  String? _error, _feedback;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _campaign =
        widget.campaigns.any((row) => row.id == widget.initialCampaignId)
        ? widget.initialCampaignId
        : widget.campaigns.firstOrNull?.id;
    if (_campaign != null) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final campaign = _campaign;
    if (campaign == null) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final roster = await widget.tools.loadJury(campaign);
      final eligible = roster['can_manage'] == true
          ? await widget.tools.eligibleJury(campaign, _search.text)
          : <Map<String, dynamic>>[];
      if (!mounted || generation != _generation) return;
      setState(() {
        _roster = roster;
        _eligible = eligible;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = recruitmentMessage(
            error,
            fallback: 'Le jury n’a pas pu être chargé.',
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _appoint(Map<String, dynamic> person) async {
    final campaign = _campaign;
    if (_busy || campaign == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
    });
    try {
      await widget.tools.appointJury(campaign, person['id'].toString());
      if (!mounted) return;
      setState(
        () => _feedback =
            '${person['name']} fait maintenant partie du jury de cette campagne.',
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = recruitmentMessage(
            error,
            fallback: 'La nomination n’a pas pu être enregistrée.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(Map<String, dynamic> person) async {
    final campaign = _campaign;
    if (_busy || campaign == null) return;
    final confirmed = await showRecruitmentDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce membre du jury ?'),
        content: Text(
          '${person['name']} perdra l’accès lié à cette nomination. Les accès liés à ses éventuelles responsabilités de recrutement resteront applicables. Ses avis resteront dans l’historique. Vérifie les entretiens déjà prévus après ce retrait.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conserver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer du jury'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
    });
    try {
      final receipt = await widget.tools.revokeJury(
        campaign,
        person['id'].toString(),
      );
      if (!mounted) return;
      final count =
          (receipt['interviews_to_reassign'] as List? ?? const []).length;
      setState(
        () => _feedback = count == 0
            ? 'Membre retiré. Les avis précédents sont conservés.'
            : 'Membre retiré. $count entretien(s) à réattribuer depuis les fiches des candidats.',
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = recruitmentMessage(
            error,
            fallback: 'Le retrait n’a pas pu être enregistré.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _initialPanel => widget.enableInterviewPreparation ? 0 : 2;
  int? _panel;

  @override
  Widget build(BuildContext context) =>
      RecruitmentStyle(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    final members =
        (_roster?['members'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
          ..sort(
            (a, b) => a['name'].toString().toLowerCase().compareTo(
              b['name'].toString().toLowerCase(),
            ),
          );
    final canManage = _roster?['can_manage'] == true;
    final teams = (_roster?['teams'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final active = members.where((row) => row['active'] == true).toList();
    final appointed = members
        .where((row) => row['appointed'] == true)
        .map((row) => row['user_id'].toString())
        .toSet();
    final groupNames =
        active
            .map((row) => row['department']?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final allPanels = <(int, String, IconData)>[
      if (widget.enableInterviewPreparation)
        (0, 'Mes entretiens', Icons.assignment_ind_outlined),
      (1, 'Équipes', Icons.groups_outlined),
      (2, 'Membres', Icons.people_outline_rounded),
      if (canManage) (4, 'Organisation', Icons.calendar_month_outlined),
      if (canManage) (3, 'Accès', Icons.admin_panel_settings_outlined),
    ];
    final selected = allPanels.any((row) => row.$1 == (_panel ?? _initialPanel))
        ? (_panel ?? _initialPanel)
        : allPanels.first.$1;
    return Scaffold(
      appBar: widget.onSectionSelected == null
          ? AppBar(title: const Text('Recrutement'))
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1260),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              if (widget.onSectionSelected != null) ...[
                RecruitmentWorkspaceNav(
                  selected: RecruitmentSection.jury,
                  onSelected: widget.onSectionSelected!,
                  canManageCampaigns: widget.canManageCampaigns,
                ),
                const SizedBox(height: 18),
              ],
              const RecruitmentPageHeading(
                title: 'Le jury',
                subtitle:
                    'Retrouvez vos entretiens, vos équipes et les membres du jury.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('jury-campaign-$_campaign'),
                initialValue: _campaign,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(
                  labelText: 'Campagne',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                items: [
                  for (final row in widget.campaigns)
                    DropdownMenuItem(value: row.id, child: Text(row.title)),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() {
                          _campaign = value;
                          _roster = null;
                          _feedback = null;
                          _panel = null;
                        });
                        _load();
                      },
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              if (_feedback != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_feedback!),
                ),
              if (widget.campaigns.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Aucune campagne disponible.'),
                  ),
                ),
              if (_roster != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _JuryCount(
                      label: 'Jurés',
                      count: active.length,
                      icon: Icons.people_outline,
                    ),
                    _JuryCount(
                      label: 'Équipes',
                      count: teams
                          .where((team) => team['active'] == true)
                          .length,
                      icon: Icons.groups_outlined,
                    ),
                    if (members.any(
                      (row) =>
                          row['appointed'] == true && row['active'] != true,
                    ))
                      _JuryCount(
                        label: 'À régulariser',
                        count: members
                            .where(
                              (row) =>
                                  row['appointed'] == true &&
                                  row['active'] != true,
                            )
                            .length,
                        icon: Icons.person_off_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final panel in allPanels)
                        ChoiceChip(
                          key: Key('jury-panel-${panel.$1}'),
                          selected: selected == panel.$1,
                          avatar: Icon(panel.$3, size: 17),
                          label: Text(panel.$2),
                          onSelected: (_) => setState(() => _panel = panel.$1),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (selected == 0 && _campaign != null)
                  RecruitmentInterviewPreparation(
                    key: ValueKey('interview-drafts-$_campaign'),
                    campaignId: _campaign!,
                    onOpenApplication: widget.onOpenApplication,
                  ),
                if (selected == 1 && _campaign != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: JuryTeamsSection(
                        campaignId: _campaign!,
                        teams: teams,
                        members: members,
                        canManage: canManage,
                        tools: widget.tools,
                        busy: _busy,
                        onChanged: _load,
                        onOpenApplication: widget.onOpenApplication,
                      ),
                    ),
                  ),
                  if ((_roster?['interviews_needing_reassignment'] as List? ??
                          const [])
                      .isNotEmpty)
                    Card(
                      child: Column(
                        children: [
                          const ListTile(
                            leading: Icon(Icons.event_busy_outlined),
                            title: Text('Entretiens à réattribuer'),
                          ),
                          for (final row
                              in (_roster!['interviews_needing_reassignment']
                                      as List)
                                  .whereType<Map>())
                            ListTile(
                              title: Text(row['name'].toString()),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: widget.onOpenApplication == null
                                  ? null
                                  : () => widget.onOpenApplication!(
                                      row['application_id'].toString(),
                                    ),
                            ),
                        ],
                      ),
                    ),
                ],
                if (selected == 2) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Membres sélectionnés',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${active.length} juré(s) dans ${groupNames.length} département(s).',
                          ),
                          if (members.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Aucun membre sélectionné.'),
                            ),
                          for (final department in groupNames)
                            ExpansionTile(
                              key: Key('jury-department-$department'),
                              initiallyExpanded:
                                  !widget.enableInterviewPreparation ||
                                  groupNames.length == 1,
                              tilePadding: EdgeInsets.zero,
                              title: Text(department),
                              subtitle: Text(
                                '${active.where((row) => row['department'] == department).length} membre(s)',
                              ),
                              children: [
                                for (final member in active.where(
                                  (row) => row['department'] == department,
                                ))
                                  _jurorRow(member, canManage),
                              ],
                            ),
                          for (final member in members.where(
                            (row) => row['active'] != true,
                          ))
                            _jurorRow(member, canManage),
                        ],
                      ),
                    ),
                  ),
                  if (canManage)
                    Card(
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        title: const Text('Ajouter un membre'),
                        subtitle: const Text(
                          'Rechercher un enacteur ou un alumni',
                        ),
                        leading: const Icon(Icons.person_add_alt_1_outlined),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          TextField(
                            controller: _search,
                            enabled: !_busy,
                            onSubmitted: (_) => _load(),
                            decoration: InputDecoration(
                              labelText: 'Rechercher un membre',
                              hintText: 'Nom ou prénom',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: IconButton(
                                tooltip: 'Chercher',
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: _busy ? null : _load,
                              ),
                            ),
                          ),
                          for (final person in _eligible.where(
                            (row) => !appointed.contains(row['id'].toString()),
                          ))
                            ListTile(
                              title: Text(person['name'].toString()),
                              subtitle: Text(
                                person['status'] == 'alumni'
                                    ? 'Alumni'
                                    : 'Enacteur',
                              ),
                              trailing: IconButton(
                                tooltip: 'Ajouter au jury',
                                onPressed: _busy
                                    ? null
                                    : () => _appoint(person),
                                icon: const Icon(
                                  Icons.person_add_alt_1_outlined,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
                if (selected == 4 && canManage && _campaign != null)
                  RecruitmentJuryPolicyPanel(
                    key: ValueKey('policy-$_campaign'),
                    campaignId: _campaign!,
                    members: members,
                  ),
                if (selected == 3 && canManage && _campaign != null)
                  RecruitmentViewersSection(
                    key: ValueKey('readers-$_campaign'),
                    campaignId: _campaign!,
                    tools: widget.tools,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _jurorRow(Map<String, dynamic> member, bool canManage) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        radius: 17,
        child: Text(
          member['name'].toString().trim().isEmpty
              ? 'J'
              : member['name'].toString().trim().substring(0, 1).toUpperCase(),
        ),
      ),
      title: Text(member['name'].toString()),
      subtitle: member['active'] == true
          ? Text(member['status'] == 'alumni' ? 'Alumni' : 'Enacteur')
          : const Text('Compte indisponible'),
      trailing: canManage && member['appointed'] == true
          ? IconButton(
              tooltip: 'Retirer du jury',
              onPressed: _busy ? null : () => _revoke(member),
              icon: const Icon(Icons.person_remove_outlined),
            )
          : null,
    );
  }
}

class _JuryCount extends StatelessWidget {
  const _JuryCount({
    required this.label,
    required this.count,
    required this.icon,
  });
  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 132),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 9),
        Text('$count', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
