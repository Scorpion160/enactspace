import 'package:flutter/material.dart';

import '../../models/application_model.dart';
import '../../services/recruitment_message.dart';
import '../../services/recruitment_selection_api.dart';
import '../../models/recruitment_schedule_model.dart';
import '../recruitment_schedule.dart';

class RecruitmentSelectionPanel extends StatefulWidget {
  final String campaignId;
  final int refreshToken;
  final VoidCallback onChanged;
  const RecruitmentSelectionPanel({
    super.key,
    required this.campaignId,
    required this.refreshToken,
    required this.onChanged,
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
  int _minimum = 2;
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
    if (oldWidget.campaignId != widget.campaignId || oldWidget.refreshToken != widget.refreshToken) {
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
        _minimum = (report['minimum_reviews'] as num?)?.toInt() ?? 2;
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
                ? 'L’identité est accessible aux responsables habilités.'
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
    final rows = (report?['rows'] as List? ?? const []).whereType<Map>().toList();
    final ready = rows.where((row) => row['ready'] == true).length;
    final decided = rows.where((row) => row['decision'] != null).length;
    final screening = report?['stage'] != 'interview';
    final completed = report?['final_published_at'] != null;
    final canPublish = rows.isNotEmpty && ready == rows.length && decided == rows.length && !completed && report?['can_publish_on_date'] != false;
    final emails = report?['result_emails'] as Map? ?? const {};
    return Card(
      child: ExpansionTile(
        title: Text(screening ? 'Présélection des dossiers' : 'Sélection après les entretiens'),
        subtitle: Text('$ready/${rows.length} dossiers évalués · $decided décisions préparées'),
        childrenPadding: const EdgeInsets.all(18),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecruitmentScheduleEditor(
            schedule: RecruitmentScheduleModel.fromJson(report?['selection_schedule']),
            template: RecruitmentScheduleModel.fromJson(report?['schedule_template']),
            enabled: !_busy && report != null && report['screening_published_at'] == null,
            onSave: (value) => _act('planning', value.dates),
          ),
          const SizedBox(height: 14),
          const Text('Les décisions préparées restent internes jusqu’à la publication du lot.'),
          const SizedBox(height: 12),
          if (report == null && _error == null) const LinearProgressIndicator(),
          if (screening && !completed) ...[
            DropdownButtonFormField<int>(
              key: ValueKey('selection-minimum-$_minimum'),
              initialValue: _minimum,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Avis par dossier'),
              items: [
                for (var count = 2; count <= 5; count++)
                  DropdownMenuItem(value: count, child: Text('$count évaluations')),
              ],
              onChanged: _busy ? null : (value) => setState(() => _minimum = value ?? 2),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('selection-threshold-$_threshold'),
              initialValue: _threshold,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Écart pour un avis supplémentaire'),
              items: [
                for (final points in ({10, 15, 20, 25, 30, _threshold}.toList()..sort()))
                  DropdownMenuItem(value: points, child: Text('$points points sur 100')),
              ],
              onChanged: _busy ? null : (value) => setState(() => _threshold = value ?? 20),
            ),
            const SizedBox(height: 12),
            Text('${report?['eligible_jurors'] ?? 0} jurés actifs. Les dossiers sont attribués aléatoirement en équilibrant leur charge.'),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _act('assign', {'minimum_reviews': _minimum, 'disagreement_threshold': _threshold}),
              icon: const Icon(Icons.shuffle),
              label: const Text('Répartir ou compléter les attributions'),
            ),
          ],
          if (!completed)
            FilledButton.icon(
              onPressed: _busy || !canPublish ? null : _publish,
              icon: const Icon(Icons.mark_email_read_outlined),
              label: const Text('Publier les résultats et préparer les mails'),
            ),
          if (!canPublish && !completed)
            const Text('Chaque dossier doit avoir ses évaluations et sa décision. La campagne doit être clôturée avant publication.'),
          if (report?['can_publish_on_date'] == false)
            Text('La publication de ce lot sera possible à partir du ${RecruitmentScheduleModel({"date": report!["result_available_from"].toString()}).label("date")}, après validation des dossiers.'),
          if (report?['screening_published_at'] != null && report?['identities_revealed_at'] == null)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _act('reveal', {}),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Lever l’anonymat pour les responsables habilités'),
            ),
          if (_feedback != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(_feedback!)),
          if ((emails['total'] as num? ?? 0) > 0)
            Text('Mails envoyés ${emails['sent'] ?? 0}/${emails['total']}. '
                '${emails['retry'] ?? 0} en nouvelle tentative, ${emails['dead'] ?? 0} en échec.'),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
