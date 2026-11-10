import 'package:flutter/material.dart';

import '../../models/application_model.dart';
import '../../services/recruitment_message.dart';
import '../../services/recruitment_selection_api.dart';
import 'recruitment_comparison_panel.dart';
import '../../models/recruitment_schedule_model.dart';
import '../recruitment_schedule.dart';

class RecruitmentSelectionPanel extends StatefulWidget {
  final String campaignId;
  final int refreshToken;
  final VoidCallback onChanged;
  final ValueChanged<String>? onOpenApplication;
  const RecruitmentSelectionPanel({
    super.key,
    required this.campaignId,
    required this.refreshToken,
    required this.onChanged,
    this.onOpenApplication,
  });

  @override
  State<RecruitmentSelectionPanel> createState() => _RecruitmentSelectionPanelState();
}

class _RecruitmentSelectionPanelState extends State<RecruitmentSelectionPanel> {
  final _api = RecruitmentSelectionApi();
  Map<String, dynamic>? _report;
  String? _error;
  String? _feedback;
  bool _busy = false;
  int _minimum = 3;
  int _threshold = 20;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RecruitmentSelectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campaignId != widget.campaignId) {
      // Prevent displaying the previous campaign's progress or publish button
      // while the next campaign is loading.
      _report = null;
      _error = null;
      _feedback = null;
      _load();
    } else if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final report = await _api.request('campaigns/${widget.campaignId}/selection');
      if (!mounted || generation != _generation) return;
      setState(() {
        _report = report;
        _minimum = ((report['minimum_reviews'] as num?)?.toInt() ?? 3).clamp(3, 5).toInt();
        _threshold = (report['disagreement_threshold'] as num?)?.toInt() ?? 20;
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = recruitmentMessage(error, fallback: 'Impossible de charger le bilan de sélection.'));
      }
    }
  }

  Future<void> _act(String action, Map<String, dynamic> body) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.request('campaigns/${widget.campaignId}/selection/$action', body: body);
      if (!mounted) return;
      setState(() {
        _feedback = action == 'assign'
            ? '${result['created']} attribution(s) ajoutée(s). ${result['unfilled']} attribution(s) restent à pourvoir.'
            : action == 'reveal'
                ? 'Les identités et les documents sont accessibles au jury de cette campagne.'
                : action == 'planning'
                    ? 'Le calendrier de la campagne a été enregistré.'
                    : 'Les résultats ont été publiés et les mails ont été préparés pour tout le lot.';
      });
      await _load();
      widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = recruitmentMessage(error, fallback: 'Cette opération n’a pas abouti.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final report = _report;
    if (report == null) return;
    final count = (report['rows'] as List? ?? const []).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publier les résultats de ce lot ?'),
        content: Text(
          '$count candidat(s) pourront consulter leur résultat dès cette publication. '
          'Leurs mails seront préparés ensemble. Relis les décisions avant de confirmer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Relire')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publier le lot')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _act('publish', {'stage': report['stage'], 'revision': report['revision']});
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final rows = (report?['rows'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final ready = rows.where((row) => row['ready'] == true).length;
    final pending = rows.length - ready;
    final decided = rows.where((row) => row['decision'] != null).length;
    final reviews = rows.fold<int>(0, (sum, row) =>
        sum + ((row['review_count'] as num?)?.toInt() ?? 0));
    final screening = report?['stage'] != 'interview';
    final completed = report?['final_published_at'] != null;
    final canPublish = rows.isNotEmpty &&
        ready == rows.length &&
        decided == rows.length &&
        !completed &&
        report?['can_publish_on_date'] != false;
    final emails = report?['result_emails'] as Map? ?? const {};
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        key: const Key('selection-workspace'),
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          screening ? 'Présélection des dossiers' : 'Sélection après les entretiens',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$ready/${rows.length} dossiers prêts · $decided décisions préparées',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (report == null && _error == null)
            const LinearProgressIndicator()
          else if (report != null) ...[
            const SizedBox(height: 6),
            LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth >= 820
                  ? (constraints.maxWidth - 36) / 4
                  : constraints.maxWidth >= 430
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
              final metrics = <({String title, int value, IconData icon})>[
                (title: 'Dossiers prêts', value: ready, icon: Icons.task_alt_outlined),
                (title: 'À compléter', value: pending, icon: Icons.pending_actions_outlined),
                (title: 'Avis enregistrés', value: reviews, icon: Icons.edit_note_outlined),
                (title: 'Décisions préparées', value: decided, icon: Icons.fact_check_outlined),
              ];
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (final metric in metrics)
                  SizedBox(
                    width: width,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        border: Border.all(color: colors.outlineVariant),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Icon(metric.icon, color: colors.primary),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${metric.value}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800)),
                              Text(metric.title, style: theme.textTheme.bodySmall),
                            ],
                          )),
                        ]),
                      ),
                    ),
                  ),
              ]);
            }),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: rows.isEmpty ? 0 : ready / rows.length,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              screening
                  ? 'Les notes guident la délibération, sans sélectionner automatiquement '
                      'les candidats. Les dossiers incomplets restent prioritaires.'
                  : 'Chaque membre du jury prévu pour un entretien doit renseigner '
                      'son évaluation avant la publication.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            RecruitmentComparisonPanel(
              key: ValueKey('comparison-${widget.campaignId}'),
              rows: rows,
              screening: screening,
              onOpen: widget.onOpenApplication,
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: RecruitmentScheduleEditor(
                  schedule: RecruitmentScheduleModel.fromJson(
                    report['selection_schedule']),
                  template: RecruitmentScheduleModel.fromJson(
                    report['schedule_template']),
                  enabled: !_busy,
                  onSave: (value) => _act('planning', value.dates),
                ),
              ),
            ),
            if (screening && !completed) ...[
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  title: const Text('Paramètres des évaluations'),
                  subtitle: const Text(
                    'Répartition du jury et seuils · facultatif pour la campagne',
                  ),
                  childrenPadding: const EdgeInsets.all(14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ces paramètres s’appliquent uniquement à cette campagne. '
                      'Ne change pas les règles pendant la délibération sans accord '
                      'préalable du jury. Les notes existantes sont conservées.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey('selection-minimum-$_minimum'),
                      initialValue: _minimum,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Avis minimaux par dossier',
                      ),
                      items: [
                        for (var count = 3; count <= 5; count++)
                          DropdownMenuItem(
                            value: count,
                            child: Text('$count évaluations'),
                          ),
                      ],
                      onChanged: _busy ? null : (value) =>
                          setState(() => _minimum = value ?? 3),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey('selection-threshold-$_threshold'),
                      initialValue: _threshold,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Écart imposant un avis supplémentaire',
                      ),
                      items: [
                        for (final points in
                            ({10, 15, 20, 25, 30, _threshold}.toList()..sort()))
                          DropdownMenuItem(
                            value: points,
                            child: Text('$points points sur 100'),
                          ),
                      ],
                      onChanged: _busy ? null : (value) =>
                          setState(() => _threshold = value ?? 20),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${report['eligible_jurors'] ?? 0} jurés actifs. '
                      'La répartition complète les affectations manquantes.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _act('assign', {
                        'minimum_reviews': _minimum,
                        'disagreement_threshold': _threshold,
                      }),
                      icon: const Icon(Icons.shuffle_outlined),
                      label: const Text('Répartir ou compléter les attributions'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Publication des décisions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      'Les décisions préparées restent internes. La publication '
                      'informe tous les candidats du lot et prépare les courriels.',
                    ),
                    const SizedBox(height: 10),
                    if (!canPublish && !completed)
                      Text(
                        'Publication indisponible : vérifie les évaluations, '
                        'les décisions et les dates avant de confirmer.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    if (report['can_publish_on_date'] == false)
                      Text(
                        'Date de publication au plus tôt : '
                        '${RecruitmentScheduleModel({"date": report["result_available_from"].toString()}).label("date")}',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    if (!completed) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy || !canPublish ? null : _publish,
                        icon: const Icon(Icons.mark_email_read_outlined),
                        label: const Text('Publier les résultats et préparer les mails'),
                      ),
                    ],
                    if ((emails['total'] as num? ?? 0) > 0)
                      Text('Mails envoyés ${emails['sent'] ?? 0}/${emails['total']}. '
                          '${emails['retry'] ?? 0} en nouvelle tentative, '
                          '${emails['dead'] ?? 0} en échec.'),
                    if (report['screening_published_at'] != null &&
                        report['identities_revealed_at'] == null)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _act('reveal', {}),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Dévoiler les identités au jury'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_feedback != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_feedback!),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: TextStyle(color: colors.error)),
            ),
          TextButton.icon(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualiser le bilan'),
          ),
        ],
      ),
    );
  }

}

class RecruitmentSelectionDecisionCard extends StatefulWidget {
  final ApplicationModel application;
  final VoidCallback onSaved;
  const RecruitmentSelectionDecisionCard({
    super.key, required this.application, required this.onSaved,
  });

  @override
  State<RecruitmentSelectionDecisionCard> createState() => _RecruitmentSelectionDecisionCardState();
}

class _RecruitmentSelectionDecisionCardState extends State<RecruitmentSelectionDecisionCard> {
  final _api = RecruitmentSelectionApi();
  String? _decision;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _decision = widget.application.assessmentStage == 'screening'
        ? widget.application.screeningDecision : widget.application.pendingFinalDecision;
  }

  Future<void> _save() async {
    final decision = _decision;
    if (decision == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _api.request('applications/${widget.application.id}/selection-decision', body: {
        'stage': widget.application.assessmentStage,
        'decision': decision,
      });
      if (mounted) widget.onSaved();
    } catch (error) {
      if (mounted) setState(() => _error = recruitmentMessage(error, fallback: 'La décision n’a pas été enregistrée.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screening = widget.application.assessmentStage == 'screening';
    final options = screening
        ? const {'shortlisted': 'Dossier retenu pour un entretien', 'not_shortlisted': 'Dossier non retenu'}
        : const {'accepted': 'Candidature retenue', 'rejected': 'Candidature non retenue', 'waiting_list': 'Liste d’attente'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Prépare la décision de ce dossier. Elle sera communiquée lors de la publication de toute la sélection.'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _decision,
          isExpanded: true,
          itemHeight: null,
          decoration: const InputDecoration(labelText: 'Décision à préparer'),
          items: [
            for (final entry in options.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: _busy ? null : (value) => setState(() => _decision = value),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || _decision == null ? null : _save,
          child: Text(_busy ? 'Enregistrement…' : 'Enregistrer pour le lot'),
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}
