import 'package:flutter/material.dart';

import '../../models/application_model.dart';
import '../../models/campaign_state_presentation.dart';
import '../../models/recruitment_campaign_model.dart';
import '../../services/internal_recruitment_gateway.dart';
import '../../widgets/internal/campaign_management_widgets.dart';

class CampaignManagementScreen extends StatefulWidget {
  final InternalRecruitmentGateway gateway;
  final DateTime? now;

  const CampaignManagementScreen({super.key, required this.gateway, this.now});

  @override
  State<CampaignManagementScreen> createState() =>
      _CampaignManagementScreenState();
}

class _CampaignManagementScreenState extends State<CampaignManagementScreen> {
  List<RecruitmentCampaignModel> _campaigns = const [];
  Map<String, int> _counts = const {};
  bool _loading = true;
  bool _refreshing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({required bool initial}) async {
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
      if (!mounted) return;
      setState(() {
        _campaigns = campaigns;
        _counts = counts;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _replace(RecruitmentCampaignModel campaign) => setState(() {
    final found = _campaigns.any((item) => item.id == campaign.id);
    _campaigns = found
        ? _campaigns
              .map((item) => item.id == campaign.id ? campaign : item)
              .toList()
        : [campaign, ..._campaigns];
  });

  Future<void> _create() async {
    final created = await showDialog<RecruitmentCampaignModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CampaignFormDialog(
        title: 'Créer une campagne',
        submitLabel: 'Créer la campagne',
        onSubmit: (value) => widget.gateway.createCampaign(
          title: value.title,
          description: value.description,
          startDate: value.startDate,
          endDate: value.endDate,
          isActive: value.isActive,
        ),
      ),
    );
    if (created == null || !mounted) return;
    _replace(created);
    _showFeedback('Campagne créée : ${created.title}.');
  }

  Future<void> _edit(RecruitmentCampaignModel campaign) async {
    final updated = await showDialog<RecruitmentCampaignModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CampaignFormDialog(
        title: 'Modifier la campagne',
        submitLabel: 'Enregistrer les modifications',
        campaign: campaign,
        onSubmit: (value) => widget.gateway.updateCampaign(
          campaignId: campaign.id,
          title: value.title,
          description: value.description,
          startDate: value.startDate,
          endDate: value.endDate,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    _replace(updated);
    _showFeedback('Modifications enregistrées.');
  }

  Future<void> _toggle(RecruitmentCampaignModel campaign) async {
    final opening = !campaign.isActive;
    final updated = await showDialog<RecruitmentCampaignModel>(
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
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CampaignDeleteDialog(
        campaign: campaign,
        applicationCount: _counts[campaign.id] ?? 0,
        onConfirm: () => widget.gateway.deleteCampaign(campaign.id),
      ),
    );
    if (deleted != true || !mounted) return;
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
    showDialog<void>(
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des campagnes'),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : () => _load(initial: false),
            tooltip: 'Actualiser les campagnes',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create-campaign'),
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Créer une campagne'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(initial: false),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              sliver: _body(),
            ),
          ],
        ),
      ),
    );
  }

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
          message: _error.toString().replaceAll('Exception: ', ''),
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
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.crossAxisExtent >= 1180
            ? 3
            : constraints.crossAxisExtent >= 720
            ? 2
            : 1;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 450,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final campaign = _campaigns[index];
            final state = CampaignStatePresentation.fromCampaign(
              campaign,
              now: widget.now,
            );
            return CampaignManagementCard(
              campaign: campaign,
              state: state,
              applicationCount: _counts[campaign.id] ?? 0,
              onView: () => _view(campaign),
              onEdit: () => _edit(campaign),
              onToggle: () => _toggle(campaign),
              onDelete: () => _delete(campaign),
            );
          }, childCount: _campaigns.length),
        );
      },
    );
  }
}

class _CampaignFormValue {
  final String title;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  const _CampaignFormValue({
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    required this.isActive,
  });
}

class _CampaignFormDialog extends StatefulWidget {
  final String title;
  final String submitLabel;
  final RecruitmentCampaignModel? campaign;
  final Future<RecruitmentCampaignModel> Function(_CampaignFormValue value)
  onSubmit;

  const _CampaignFormDialog({
    required this.title,
    required this.submitLabel,
    this.campaign,
    required this.onSubmit,
  });

  @override
  State<_CampaignFormDialog> createState() => _CampaignFormDialogState();
}

class _CampaignFormDialogState extends State<_CampaignFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late bool _active;
  bool _submitting = false;
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
    if (_submitting || !_formKey.currentState!.validate()) return;
    final start = _parseDate(_start.text);
    final end = _parseDate(_end.text);
    if (start != null && end != null && end.isBefore(start)) {
      setState(() => _error = 'La date de fin doit suivre la date de début.');
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
        ),
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                textField: true,
                label: 'Titre de la campagne',
                child: TextFormField(
                  key: const Key('campaign-title'),
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Titre *'),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'Le titre est requis.'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('campaign-description'),
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('campaign-start-date'),
                controller: _start,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Date de début',
                  hintText: 'JJ/MM/AAAA',
                ),
                validator: _dateValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('campaign-end-date'),
                controller: _end,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Date de fin',
                  hintText: 'JJ/MM/AAAA',
                ),
                validator: _dateValidator,
              ),
              if (widget.campaign == null)
                SwitchListTile.adaptive(
                  key: const Key('campaign-active'),
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: const Text('Activer après création'),
                  subtitle: const Text(
                    'Une date future gardera la campagne planifiée.',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        child: const Text('Retour'),
      ),
      FilledButton(
        key: const Key('campaign-form-submit'),
        onPressed: _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(widget.submitLabel),
      ),
    ],
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
          _error = error.toString().replaceAll('Exception: ', '');
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

class _CampaignDeleteDialog extends StatefulWidget {
  final RecruitmentCampaignModel campaign;
  final int applicationCount;
  final Future<void> Function() onConfirm;

  const _CampaignDeleteDialog({
    required this.campaign,
    required this.applicationCount,
    required this.onConfirm,
  });

  @override
  State<_CampaignDeleteDialog> createState() => _CampaignDeleteDialogState();
}

class _CampaignDeleteDialogState extends State<_CampaignDeleteDialog> {
  bool _confirmed = false;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (!_confirmed || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Supprimer définitivement cette campagne ?'),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Campagne : ${widget.campaign.title}'),
          Text('${widget.applicationCount} candidatures concernées'),
          const SizedBox(height: 12),
          Text(
            'Cette suppression est irréversible. Le contrat backend supprime également en cascade toutes les candidatures associées.',
            style: TextStyle(
              color: Colors.red.shade800,
              fontWeight: FontWeight.w700,
            ),
          ),
          CheckboxListTile(
            key: const Key('campaign-delete-confirmation'),
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            onChanged: _submitting
                ? null
                : (value) => setState(() => _confirmed = value == true),
            title: Text(
              'Je confirme la suppression irréversible de « ${widget.campaign.title} » et de ses candidatures.',
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
