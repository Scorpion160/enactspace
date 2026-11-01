import '../../widgets/recruitment_style.dart';
import '../../widgets/recruitment_workspace.dart';
import '../../services/recruitment_message.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:flutter/material.dart';

import '../../models/application_model.dart';
import '../../models/recruitment_question_model.dart';
import '../../widgets/internal/questionnaire_editor.dart';
import '../../models/campaign_state_presentation.dart';
import '../../models/recruitment_campaign_model.dart';
import '../../services/internal_recruitment_gateway.dart';
import '../../widgets/internal/campaign_management_widgets.dart';

class CampaignManagementScreen extends StatefulWidget {
  final InternalRecruitmentGateway gateway;
  final DateTime? now;
  final ValueChanged<RecruitmentSection>? onSectionSelected;

  const CampaignManagementScreen({
    super.key,
    required this.gateway,
    this.now,
    this.onSectionSelected,
  });

  @override
  State<CampaignManagementScreen> createState() =>
      _CampaignManagementScreenState();
}

class _CampaignManagementScreenState extends State<CampaignManagementScreen> {
  List<RecruitmentCampaignModel> _campaigns = const [];
  Map<String, int> _counts = const {};
  bool _loading = true;
  bool _refreshing = false;
  int _generation = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({required bool initial}) async {
    final generation = ++_generation;
    setState(() {
      initial ? _loading = true : _refreshing = true;
      _error = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        widget.gateway.loadCampaigns(),
        widget.gateway.loadApplications(),
      ]);
      final campaigns = result[0] as List<RecruitmentCampaignModel>;
      final applications = result[1] as List<ApplicationModel>;
      final counts = <String, int>{};
      for (final application in applications) {
        counts.update(
          application.campaignId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _campaigns = campaigns;
        _counts = counts;
      });
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _replace(RecruitmentCampaignModel campaign) => setState(() {
    _generation++;
    _loading = false;
    _refreshing = false;
    final found = _campaigns.any((item) => item.id == campaign.id);
    _campaigns = found
        ? _campaigns
              .map((item) => item.id == campaign.id ? campaign : item)
              .toList()
        : [campaign, ..._campaigns];
  });

  Future<void> _create() async {
    final created = await Navigator.of(context).push<RecruitmentCampaignModel>(
      MaterialPageRoute(
        builder: (context) => _CampaignFormScreen(
          title: 'Créer une campagne',
          submitLabel: 'Créer la campagne',
          onSubmit: (value) => widget.gateway.createCampaign(
            applicationQuestions: value.applicationQuestions,
            title: value.title,
            description: value.description,
            startDate: value.startDate,
            endDate: value.endDate,
            isActive: value.isActive,
          ),
        ),
      ),
    );
    if (created == null || !mounted) return;
    _replace(created);
    _showFeedback('Campagne créée : ${created.title}.');
  }

  Future<void> _edit(RecruitmentCampaignModel campaign) async {
    final updated = await Navigator.of(context).push<RecruitmentCampaignModel>(
      MaterialPageRoute(
        builder: (context) => _CampaignFormScreen(
          title: 'Modifier la campagne',
          submitLabel: 'Enregistrer les modifications',
          campaign: campaign,
          onSubmit: (value) => widget.gateway.updateCampaign(
            campaignId: campaign.id,
            applicationQuestions: value.applicationQuestions,
            title: value.title,
            description: value.description,
            startDate: value.startDate,
            endDate: value.endDate,
          ),
        ),
      ),
    );
    if (updated == null || !mounted) return;
    _replace(updated);
    _showFeedback('Modifications enregistrées.');
  }

  Future<void> _toggle(RecruitmentCampaignModel campaign) async {
    final opening = !campaign.isActive;
    final updated = await showRecruitmentDialog<RecruitmentCampaignModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CampaignToggleDialog(
        campaign: campaign,
        opening: opening,
        now: widget.now,
        onConfirm: () => widget.gateway.updateCampaign(
          campaignId: campaign.id,
          isActive: opening,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    _replace(updated);
    final state = CampaignStatePresentation.fromCampaign(
      updated,
      now: widget.now,
    );
    _showFeedback('Campagne mise à jour : ${state.label}.');
  }

  Future<void> _delete(RecruitmentCampaignModel campaign) async {
    final result = await showRecruitmentDialog<_CampaignDeleteResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CampaignDeleteDialog(
        campaign: campaign,
        applicationCount: _counts[campaign.id] ?? 0,
        onConfirm: () => widget.gateway.deleteCampaign(campaign.id),
        onClose: campaign.isActive
            ? () async {
                final updated = await widget.gateway.updateCampaign(
                  campaignId: campaign.id,
                  isActive: false,
                );
                if (mounted) _replace(updated);
              }
            : null,
      ),
    );
    if (result == null || !mounted) return;
    if (result == _CampaignDeleteResult.closed) {
      _showFeedback('Campagne fermée. Les candidatures restent consultables.');
      return;
    }
    setState(() {
      _campaigns = _campaigns.where((item) => item.id != campaign.id).toList();
      _counts = Map.of(_counts)..remove(campaign.id);
    });
    _showFeedback('Campagne supprimée définitivement.');
  }

  void _view(RecruitmentCampaignModel campaign) {
    final state = CampaignStatePresentation.fromCampaign(
      campaign,
      now: widget.now,
    );
    showRecruitmentDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(campaign.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CampaignStateBadge(state: state),
              const SizedBox(height: 16),
              Text(campaign.description ?? 'Aucune description renseignée.'),
              const SizedBox(height: 12),
              Text('Période : ${campaign.periodLabel}'),
              Text('${_counts[campaign.id] ?? 0} candidatures associées'),
              Text(
                campaign.isActive
                    ? 'Activation : proposée selon sa période.'
                    : 'Activation : non proposée aux nouveaux candidats.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) =>
      RecruitmentStyle(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) => Scaffold(
    appBar: widget.onSectionSelected == null
        ? AppBar(title: const Text('Recrutement'))
        : null,
    body: RefreshIndicator(
      onRefresh: () => _load(initial: false),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.onSectionSelected != null) ...[
                        RecruitmentWorkspaceNav(
                          selected: RecruitmentSection.campaigns,
                          onSelected: widget.onSectionSelected!,
                        ),
                        const SizedBox(height: 22),
                      ],
                      RecruitmentPageHeading(
                        title: 'Gestion des campagnes',
                        subtitle:
                            'Prépare les inscriptions, adapte le questionnaire et garde le suivi de chaque promotion.',
                        actions: [
                          IconButton(
                            onPressed: _refreshing
                                ? null
                                : () => _load(initial: false),
                            tooltip: 'Actualiser les campagnes',
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                          FilledButton.icon(
                            key: const Key('create-campaign'),
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Créer une campagne'),
                          ),
                        ],
                      ),
                      if (!_loading && _error == null) ...[
                        const SizedBox(height: 20),
                        RecruitmentStats(
                          values: [
                            (
                              label: 'Campagnes',
                              count: _campaigns.length,
                              icon: Icons.campaign_outlined,
                            ),
                            (
                              label: 'Planifiées',
                              count: _campaigns
                                  .where(
                                    (c) =>
                                        CampaignStatePresentation.fromCampaign(
                                          c,
                                          now: widget.now,
                                        ).key ==
                                        'planned',
                                  )
                                  .length,
                              icon: Icons.schedule_outlined,
                            ),
                            (
                              label: 'Ouvertes',
                              count: _campaigns
                                  .where(
                                    (c) =>
                                        CampaignStatePresentation.fromCampaign(
                                          c,
                                          now: widget.now,
                                        ).key ==
                                        'open',
                                  )
                                  .length,
                              icon: Icons.lock_open_outlined,
                            ),
                            (
                              label: 'Candidatures',
                              count: _counts.values.fold<int>(
                                0,
                                (a, b) => a + b,
                              ),
                              icon: Icons.people_outline,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (_refreshing) const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: _body(),
          ),
        ],
      ),
    ),
  );

  Widget _body() {
    if (_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: CampaignManagementState(
          icon: Icons.cloud_off_outlined,
          title: 'Erreur de chargement',
          message: recruitmentMessage(
            _error!,
            fallback:
                'Impossible de charger les campagnes. Réessaie dans un instant.',
          ),
          actionLabel: 'Réessayer',
          onAction: () => _load(initial: true),
        ),
      );
    }
    if (_campaigns.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: CampaignManagementState(
          icon: Icons.campaign_outlined,
          title: 'Aucune campagne',
          message: 'Créez une campagne pour préparer le prochain recrutement.',
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaled = MediaQuery.textScalerOf(context).scale(14) > 21;
              final columns = !scaled && constraints.maxWidth >= 1050 ? 2 : 1;
              final width =
                  (constraints.maxWidth - 16 * (columns - 1)) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final campaign in _campaigns)
                    SizedBox(
                      width: width,
                      child: CampaignManagementCard(
                        campaign: campaign,
                        state: CampaignStatePresentation.fromCampaign(
                          campaign,
                          now: widget.now,
                        ),
                        applicationCount: _counts[campaign.id] ?? 0,
                        onView: () => _view(campaign),
                        onEdit: () => _edit(campaign),
                        onToggle: () => _toggle(campaign),
                        onDelete: () => _delete(campaign),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CampaignFormValue {
  final String title;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final List<Map<String, dynamic>> applicationQuestions;

  const _CampaignFormValue({
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    required this.isActive,
    required this.applicationQuestions,
  });
}

class _CampaignFormScreen extends StatefulWidget {
  final String title;
  final String submitLabel;
  final RecruitmentCampaignModel? campaign;
  final Future<RecruitmentCampaignModel> Function(_CampaignFormValue value)
  onSubmit;

  const _CampaignFormScreen({
    required this.title,
    required this.submitLabel,
    this.campaign,
    required this.onSubmit,
  });

  @override
  State<_CampaignFormScreen> createState() => _CampaignFormScreenState();
}

class _CampaignFormScreenState extends State<_CampaignFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late bool _active;
  late List<RecruitmentApplicationQuestion> _questions;
  bool _submitting = false;
  int _tab = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final campaign = widget.campaign;
    _title = TextEditingController(text: campaign?.title ?? '');
    _description = TextEditingController(text: campaign?.description ?? '');
    _start = TextEditingController(text: _formatDate(campaign?.startDateValue));
    _end = TextEditingController(text: _formatDate(campaign?.endDateValue));
    _active = campaign?.isActive ?? false;
    _questions = List.of(
      campaign?.applicationQuestions ?? defaultRecruitmentQuestions,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_questions.any((q) => q.label.trim().isEmpty)) {
      setState(() {
        _tab = 1;
        _error = 'Écris un libellé pour chaque question.';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) {
      setState(() => _tab = 0);
      return;
    }
    final start = _parseDate(_start.text);
    final end = _parseDate(_end.text);
    if (start != null && end != null && end.isBefore(start)) {
      setState(() {
        _tab = 0;
        _error = 'La date de fin doit suivre la date de début.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(
        _CampaignFormValue(
          title: _title.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          startDate: start,
          endDate: end,
          isActive: _active,
          applicationQuestions: _questions.map((q) => q.toJson()).toList(),
        ),
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = recruitmentMessage(
            error,
            fallback:
                'Impossible d’enregistrer cette action. Réessaie dans un instant.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RecruitmentStyle(
    child: Builder(
      builder: (context) => PopScope(
        canPop: !_submitting,
        child: Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1360),
                        child: Padding(
                          padding: EdgeInsets.all(
                            MediaQuery.sizeOf(context).width < 600 ? 14 : 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              RecruitmentPageHeading(
                                title: widget.campaign == null
                                    ? 'Prépare la prochaine génération.'
                                    : widget.campaign!.title,
                                subtitle:
                                    'Informations, questions et aperçu : tout le parcours de la campagne au même endroit.',
                              ),
                              const SizedBox(height: 18),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final tab in [
                                      (0, 'Informations'),
                                      (1, 'Questionnaire'),
                                      (2, 'Aperçu candidat'),
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(tab.$2),
                                          selected: _tab == tab.$1,
                                          onSelected: _submitting
                                              ? null
                                              : (_) => setState(
                                                  () => _tab = tab.$1,
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (_error != null) ...[
                                Text(
                                  _error!,
                                  key: const Key('campaign-form-error'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Visibility(
                                      visible: _tab == 0,
                                      maintainState: true,
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 820,
                                          ),
                                          child: Card(
                                            child: Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Semantics(
                                                    textField: true,
                                                    label:
                                                        'Titre de la campagne',
                                                    child: TextFormField(
                                                      key: const Key(
                                                        'campaign-title',
                                                      ),
                                                      controller: _title,
                                                      enabled: !_submitting,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Titre *',
                                                          ),
                                                      validator: (value) =>
                                                          value
                                                                  ?.trim()
                                                                  .isEmpty ==
                                                              true
                                                          ? 'Le titre est requis.'
                                                          : null,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  TextFormField(
                                                    key: const Key(
                                                      'campaign-description',
                                                    ),
                                                    controller: _description,
                                                    enabled: !_submitting,
                                                    minLines: 3,
                                                    maxLines: 5,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Description',
                                                        ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  TextFormField(
                                                    key: const Key(
                                                      'campaign-start-date',
                                                    ),
                                                    controller: _start,
                                                    enabled: !_submitting,
                                                    keyboardType:
                                                        TextInputType.datetime,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Date de début',
                                                          hintText:
                                                              'JJ/MM/AAAA',
                                                        ),
                                                    validator: _dateValidator,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  TextFormField(
                                                    key: const Key(
                                                      'campaign-end-date',
                                                    ),
                                                    controller: _end,
                                                    enabled: !_submitting,
                                                    keyboardType:
                                                        TextInputType.datetime,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Date de fin',
                                                          hintText:
                                                              'JJ/MM/AAAA',
                                                        ),
                                                    validator: _dateValidator,
                                                  ),
                                                  if (widget.campaign == null)
                                                    SwitchListTile.adaptive(
                                                      key: const Key(
                                                        'campaign-active',
                                                      ),
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      value: _active,
                                                      onChanged: (value) =>
                                                          setState(
                                                            () =>
                                                                _active = value,
                                                          ),
                                                      title: const Text(
                                                        'Activer après création',
                                                      ),
                                                      subtitle: const Text(
                                                        'Une date future gardera la campagne planifiée.',
                                                      ),
                                                    ),
                                                  const SizedBox(height: 14),
                                                  const RecruitmentNotice(
                                                    'Les dates sont interprétées à Dakar. La date de fin inclut toute la journée. Fermer une campagne conserve ses candidatures.',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Visibility(
                                      visible: _tab == 1,
                                      maintainState: true,
                                      child: RecruitmentQuestionnaireEditor(
                                        questions: _questions,
                                        onChanged: _submitting
                                            ? (_) {}
                                            : (value) => setState(
                                                () => _questions = value,
                                              ),
                                      ),
                                    ),
                                    if (_tab == 2)
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const RecruitmentNotice(
                                                'Aperçu de cette campagne. Aucune candidature ne sera envoyée depuis cet écran.',
                                              ),
                                              const SizedBox(height: 20),
                                              Text(
                                                _title.text.trim().isEmpty
                                                    ? 'Titre de la campagne'
                                                    : _title.text.trim(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              const SizedBox(height: 12),
                                              SelectableText(
                                                _description.text.trim().isEmpty
                                                    ? 'La description apparaîtra ici.'
                                                    : _description.text.trim(),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Inscriptions : ${_start.text.isEmpty ? 'À définir' : _start.text} → ${_end.text.isEmpty ? 'À définir' : _end.text} · Dakar',
                                              ),
                                              const Divider(height: 32),
                                              const Text(
                                                'Identité · Parcours · Motivations · Disponibilités · Documents · Vérification',
                                              ),
                                              const SizedBox(height: 12),
                                              RecruitmentQuestionnairePreview(
                                                questions: _questions,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Retour'),
                        ),
                        FilledButton(
                          key: const Key('campaign-form-submit'),
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(widget.submitLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  static String? _dateValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _parseDate(value) == null ? 'Saisissez une date valide.' : null;
  }
}

class _CampaignToggleDialog extends StatefulWidget {
  final RecruitmentCampaignModel campaign;
  final bool opening;
  final DateTime? now;
  final Future<RecruitmentCampaignModel> Function() onConfirm;

  const _CampaignToggleDialog({
    required this.campaign,
    required this.opening,
    required this.now,
    required this.onConfirm,
  });

  @override
  State<_CampaignToggleDialog> createState() => _CampaignToggleDialogState();
}

class _CampaignToggleDialogState extends State<_CampaignToggleDialog> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = recruitmentMessage(
            error,
            fallback:
                'Impossible d’enregistrer cette action. Réessaie dans un instant.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.campaign.startDateValue;
    final end = widget.campaign.endDateValue;
    final datesCoherent = start == null || end == null || !end.isBefore(start);
    final current = CampaignStatePresentation.fromCampaign(
      widget.campaign,
      now: widget.now,
    );
    final target = CampaignStatePresentation.fromCampaign(
      widget.campaign.copyWith(isActive: widget.opening),
      now: widget.now,
    );
    return AlertDialog(
      title: Text(
        widget.opening ? 'Ouvrir cette campagne ?' : 'Fermer cette campagne ?',
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Campagne : ${widget.campaign.title}'),
            Text('Période : ${widget.campaign.periodLabel}'),
            Text('État actuel : ${current.label}'),
            Text('Nouvel état attendu : ${target.label}'),
            const SizedBox(height: 12),
            if (!datesCoherent) ...[
              Text(
                'Corrigez la période avant d’activer cette campagne.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              widget.opening
                  ? target.key == 'planned'
                        ? 'La campagne sera activée mais restera planifiée jusqu’à sa date de début.'
                        : 'La campagne pourra être proposée aux nouveaux candidats pendant sa période.'
                  : 'Elle ne sera plus proposée aux nouveaux candidats. Les candidatures existantes resteront consultables dans le workbench.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const Key('campaign-toggle-submit'),
          onPressed: _submitting || !datesCoherent ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.opening ? 'Ouvrir la campagne' : 'Fermer la campagne',
                ),
        ),
      ],
    );
  }
}

enum _CampaignDeleteResult { deleted, closed }

class _CampaignDeleteDialog extends StatefulWidget {
  final RecruitmentCampaignModel campaign;
  final int applicationCount;
  final Future<void> Function() onConfirm;
  final Future<void> Function()? onClose;

  const _CampaignDeleteDialog({
    required this.campaign,
    required this.applicationCount,
    required this.onConfirm,
    this.onClose,
  });

  @override
  State<_CampaignDeleteDialog> createState() => _CampaignDeleteDialogState();
}

class _CampaignDeleteDialogState extends State<_CampaignDeleteDialog> {
  bool _confirmed = false;
  bool _submitting = false;
  bool _blockedByServer = false;
  String? _error;
  bool get _hasApplications => widget.applicationCount > 0 || _blockedByServer;

  Future<void> _submit() async {
    if (!_confirmed || _submitting || _hasApplications) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(_CampaignDeleteResult.deleted);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          if (error is ApiException && error.statusCode == 409) {
            _blockedByServer = true;
            _confirmed = false;
          }
          _error = recruitmentMessage(
            error,
            fallback:
                'Impossible d’enregistrer cette action. Réessaie dans un instant.',
          );
        });
      }
    }
  }

  Future<void> _close() async {
    if (_submitting || widget.onClose == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onClose!();
      if (mounted) Navigator.of(context).pop(_CampaignDeleteResult.closed);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = recruitmentMessage(
            error,
            fallback: 'La campagne n’a pas pu être fermée. Réessaie.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _hasApplications
          ? 'Cette campagne contient des candidatures'
          : 'Supprimer définitivement cette campagne ?',
    ),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Campagne : ${widget.campaign.title}'),
          if (widget.applicationCount > 0)
            Text(
              widget.applicationCount == 1
                  ? '1 candidature à conserver'
                  : '${widget.applicationCount} candidatures à conserver',
            )
          else if (_blockedByServer)
            const Text(
              'Des candidatures ont été déposées depuis l’ouverture de cette page.',
            )
          else
            const Text('Aucune candidature associée'),
          const SizedBox(height: 12),
          Text(
            _hasApplications
                ? 'Les dossiers, leur suivi et les évaluations doivent être conservés. Fermer la campagne arrête les inscriptions sans effacer ces informations.'
                : 'Seule cette campagne vide sera supprimée. Cette action est définitive.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_hasApplications && widget.onClose == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Cette campagne est déjà fermée. Les dossiers restent consultables.',
              ),
            ),
          if (!_hasApplications)
            CheckboxListTile(
              key: const Key('campaign-delete-confirmation'),
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _confirmed = value == true),
              title: Text(
                'Je confirme la suppression irréversible de « ${widget.campaign.title} ».',
              ),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        child: const Text('Retour'),
      ),
      if (_hasApplications && widget.onClose != null)
        FilledButton(
          key: const Key('campaign-delete-close'),
          onPressed: _submitting ? null : _close,
          child: Text(_submitting ? 'Fermeture…' : 'Fermer la campagne'),
        ),
      if (!_hasApplications)
        FilledButton(
          key: const Key('campaign-delete-submit'),
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
          onPressed: !_confirmed || _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Supprimer définitivement'),
        ),
    ],
  );
}

DateTime? _parseDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final parts = value.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
