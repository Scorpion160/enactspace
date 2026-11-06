import 'package:flutter/material.dart';

import '../models/recruitment_schedule_model.dart';

class RecruitmentScheduleCard extends StatelessWidget {
  final RecruitmentScheduleModel schedule;
  final bool showFullSchedule;
  const RecruitmentScheduleCard({super.key, required this.schedule, this.showFullSchedule = false});

  @override
  Widget build(BuildContext context) {
    final rows = showFullSchedule ? {
      'Dépôt des candidatures': schedule.range('applications_open', 'applications_close'),
      'Étude des dossiers': schedule.range('screening_start', 'screening_end'),
      'Résultat du dossier': schedule.label('screening_results'),
      'Entretiens': schedule.range('interviews_start', 'interviews_end'),
      'Résultats finaux': schedule.label('final_results'),
    } : {
      'Ouverture des dépôts': schedule.label('applications_open'),
      'Clôture des dépôts': schedule.label('applications_close'),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calendar_month_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(showFullSchedule ? 'Calendrier du recrutement' : 'Dépôt des candidatures', style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 12),
          for (final row in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${row.key} : '),
                TextSpan(text: row.value, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]), style: const TextStyle(height: 1.5)),
            ),
          if (showFullSchedule) ...[
            const SizedBox(height: 8),
            const Text('L’étude peut commencer dès la réception des premiers dossiers, pendant que les candidatures restent ouvertes.', style: TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            const Text('Les résultats de chaque sélection sont publiés ensemble. Les mails sont préparés ensemble ; leur réception peut varier selon les messageries.',
              style: TextStyle(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class RecruitmentScheduleEditor extends StatefulWidget {
  final RecruitmentScheduleModel? schedule;
  final RecruitmentScheduleModel? template;
  final bool enabled;
  final Future<void> Function(RecruitmentScheduleModel value) onSave;
  const RecruitmentScheduleEditor({
    super.key, this.schedule, this.template, required this.enabled, required this.onSave,
  });

  @override
  State<RecruitmentScheduleEditor> createState() => _RecruitmentScheduleEditorState();
}

class _RecruitmentScheduleEditorState extends State<RecruitmentScheduleEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _dates;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dates = {for (final key in RecruitmentScheduleModel.labels.keys) key: TextEditingController()};
    _fill(widget.schedule);
  }

  @override
  void didUpdateWidget(RecruitmentScheduleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedule?.dates.toString() != widget.schedule?.dates.toString()) _fill(widget.schedule);
  }

  void _fill(RecruitmentScheduleModel? schedule) {
    for (final entry in _dates.entries) {
      entry.value.text = schedule?.date(entry.key) == null ? '' : schedule!.label(entry.key);
    }
    _error = null;
  }

  @override
  void dispose() {
    for (final controller in _dates.values) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _pick(String key) async {
    final initial = RecruitmentScheduleModel.parseFrench(_dates[key]!.text) ?? DateTime.now();
    final chosen = await showDatePicker(
      context: context, initialDate: initial,
      firstDate: DateTime(initial.year < 2020 ? initial.year : 2020),
      lastDate: DateTime(initial.year > 2100 ? initial.year + 1 : 2100, 12, 31),
    );
    if (chosen != null && mounted) {
      final value = RecruitmentScheduleModel({key: chosen.toIso8601String().split('T').first});
      setState(() => _dates[key]!.text = value.label(key));
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_form.currentState?.validate() != true) return;
    final value = RecruitmentScheduleModel({
      for (final entry in _dates.entries)
        entry.key: RecruitmentScheduleModel.parseFrench(entry.value.text)!.toIso8601String().split('T').first,
    });
    setState(() => _error = value.validationError);
    if (_error == null) await widget.onSave(value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled && widget.schedule != null) return RecruitmentScheduleCard(schedule: widget.schedule!, showFullSchedule: true);
    return ExpansionTile(
      title: const Text('Calendrier de la campagne'),
      subtitle: Text(widget.schedule == null ? 'À renseigner avant la diffusion' : 'Deux dates de résultats pour toute la campagne'),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.template != null) ...[
          OutlinedButton.icon(
            key: const Key('load-november-schedule'),
            onPressed: widget.enabled ? () => setState(() => _fill(widget.template)) : null,
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Charger le planning de novembre 2026'),
          ),
          const Text('Le modèle peut être ajusté selon les contraintes de la campagne. Toutes les dates restent modifiables.'),
          const SizedBox(height: 16),
        ],
        Form(key: _form, child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth >= 640 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
          return Wrap(spacing: 12, runSpacing: 14, children: [
            for (final field in RecruitmentScheduleModel.labels.entries)
              SizedBox(width: width, child: TextFormField(
                key: Key('schedule-${field.key}'),
                controller: _dates[field.key], enabled: widget.enabled,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: field.value, hintText: 'JJ/MM/AAAA',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  errorMaxLines: 3,
                  suffixIcon: IconButton(tooltip: 'Choisir une date',
                    onPressed: widget.enabled ? () => _pick(field.key) : null,
                    icon: const Icon(Icons.calendar_today_outlined)),
                ),
                validator: (value) => RecruitmentScheduleModel.parseFrench(value ?? '') == null
                    ? 'Renseigne une date valide : JJ/MM/AAAA.' : null,
              )),
          ]);
        })),
        const SizedBox(height: 14),
        FilledButton(
          key: const Key('save-recruitment-schedule'),
          onPressed: widget.enabled ? _save : null,
          child: const Text('Enregistrer le calendrier'),
        ),
        const SizedBox(height: 8),
        const Text('Avant la présélection, les dépôts suivent ces dates à l’heure de Dakar après activation de la campagne. Les évaluations peuvent commencer dès l’arrivée des dossiers ; la date de début de l’étude est indicative. La publication des résultats reste une action de l’équipe, après la clôture des dépôts, les évaluations et à partir de la date annoncée.'),
        const SizedBox(height: 8),
        const Text('Tu peux ajuster le calendrier à tout moment. Les changements sont conservés dans l’historique. Seules les dates d’ouverture et de clôture des dépôts sont visibles par les candidats ; le reste du planning est réservé à l’équipe. Reprogramme les entretiens séparément si nécessaire. Modifier le calendrier n’envoie pas de mail.'),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}
