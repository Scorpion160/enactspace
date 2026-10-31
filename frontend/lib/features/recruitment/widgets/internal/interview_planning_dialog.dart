import 'package:flutter/material.dart';
import '../../models/application_model.dart';
import '../../services/recruitment_campaign_tools.dart';
import '../../services/recruitment_message.dart';

class InterviewPlanningDialog extends StatefulWidget {
  final ApplicationModel application;
  final RecruitmentCampaignTools tools;
  final ValueChanged<ApplicationModel> onSaved;
  const InterviewPlanningDialog({
    super.key,
    required this.application,
    required this.tools,
    required this.onSaved,
  });
  @override
  State<InterviewPlanningDialog> createState() =>
      _InterviewPlanningDialogState();
}

class _InterviewPlanningDialogState extends State<InterviewPlanningDialog> {
  final _form = GlobalKey<FormState>();
  final _date = TextEditingController(),
      _time = TextEditingController(),
      _duration = TextEditingController();
  final _location = TextEditingController(),
      _link = TextEditingController(),
      _note = TextEditingController();
  final Set<String> _selected = {};
  List<Map<String, dynamic>> _members = [];
  String _mode = 'in_person';
  bool _loading = true, _sending = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final app = widget.application;
    final start = app.interviewAt?.toUtc();
    _date.text = start == null
        ? ''
        : '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
    _time.text = start == null
        ? '12:00'
        : '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    _duration.text = app.interviewEndAt != null && start != null
        ? app.interviewEndAt!.difference(start).inMinutes.toString()
        : '20';
    _mode =
        app.interviewMode ??
        (app.interviewLink?.isNotEmpty == true ? 'online' : 'in_person');
    _location.text = app.interviewLocation ?? '';
    _link.text = app.interviewLink ?? '';
    _note.text = app.interviewNote ?? '';
    _selected.addAll(
      app.interviewJurors
          .where((row) => row['active'] == true)
          .map((row) => row['member_id'].toString()),
    );
    _load();
  }

  @override
  void dispose() {
    for (final value in [_date, _time, _duration, _location, _link, _note]) {
      value.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.tools.loadJury(widget.application.campaignId);
      if (!mounted) return;
      setState(
        () => _members = (result['members'] as List)
            .whereType<Map>()
            .where((row) => row['active'] == true)
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = recruitmentMessage(
            error,
            fallback: 'Le jury n’a pas pu être chargé.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _start() {
    final day = _date.text.trim().split('/').map(int.tryParse).toList();
    final time = _time.text.trim().split(':').map(int.tryParse).toList();
    if (day.length != 3 ||
        time.length != 2 ||
        [...day, ...time].contains(null)) {
      return null;
    }
    if (day[0]! < 1 ||
        day[0]! > 31 ||
        day[1]! < 1 ||
        day[1]! > 12 ||
        day[2]! < 2000 ||
        day[2]! > 2100) {
      return null;
    }
    if (time[0]! < 0 || time[0]! > 23 || time[1]! < 0 || time[1]! > 59) {
      return null;
    }
    final value = DateTime.utc(day[2]!, day[1]!, day[0]!, time[0]!, time[1]!);
    return value.day == day[0] && value.month == day[1] && value.year == day[2]
        ? value
        : null;
  }

  Future<void> _save() async {
    if (_sending || !_form.currentState!.validate()) return;
    if (_selected.isEmpty) {
      setState(() => _error = 'Choisis au moins un membre du jury.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final start = _start()!;
      final updated = await widget.tools
          .scheduleWithJury(widget.application.id, {
            'interview_at': start.toIso8601String(),
            'interview_end_at': start
                .add(Duration(minutes: int.parse(_duration.text)))
                .toIso8601String(),
            'interview_mode': _mode,
            'interview_location': _mode == 'online'
                ? null
                : _location.text.trim(),
            'interview_link': _mode == 'in_person' ? null : _link.text.trim(),
            'interview_note': _note.text.trim(),
            'jury_member_ids': _selected.toList(),
          });
      if (!mounted) return;
      widget.onSaved(updated);
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = recruitmentMessage(
            error,
            fallback: 'Cet entretien n’a pas pu être enregistré.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Organiser l’entretien'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.application.fullName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Heure de Dakar. Priorité aux pauses de 12 h à 14 h 30 ; les soirées restent possibles. La durée et le jury se choisissent pour chaque entretien.',
              ),
              if (widget.application.interviewAvailability?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Disponibilités indiquées : ${widget.application.interviewAvailability}',
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _date,
                enabled: !_sending,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  hintText: 'JJ/MM/AAAA',
                ),
                validator: (_) =>
                    _start() == null ? 'Vérifie la date et l’heure.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _time,
                enabled: !_sending,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Heure de Dakar *',
                  hintText: '12:30 ou 19:00',
                ),
                validator: (_) =>
                    _start() == null ? 'Vérifie la date et l’heure.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _duration,
                enabled: !_sending,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durée en minutes *',
                ),
                validator: (raw) {
                  final value = int.tryParse(raw ?? '');
                  return value == null || value < 5 || value > 180
                      ? 'Choisis une durée entre 5 et 180 minutes.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Format'),
                items: const [
                  DropdownMenuItem(
                    value: 'in_person',
                    child: Text('En présentiel'),
                  ),
                  DropdownMenuItem(value: 'online', child: Text('En ligne')),
                  DropdownMenuItem(
                    value: 'hybrid',
                    child: Text('Mixte : sur place et en ligne'),
                  ),
                ],
                onChanged: _sending
                    ? null
                    : (value) => setState(() => _mode = value!),
              ),
              if (_mode != 'online') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  enabled: !_sending,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Lieu confirmé *',
                  ),
                  validator: (value) => value?.trim().isEmpty != false
                      ? 'Précise le lieu.'
                      : null,
                ),
              ],
              if (_mode != 'in_person') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _link,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                    labelText: 'Lien de l’entretien *',
                    hintText: 'https://…',
                  ),
                  validator: (value) {
                    final uri = Uri.tryParse(value?.trim() ?? '');
                    return uri?.scheme != 'https' || uri!.host.isEmpty
                        ? 'Indique un lien HTTPS.'
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Membres du jury',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && _members.isEmpty)
                const Text(
                  'Aucun membre disponible. Constitue d’abord le jury de cette campagne.',
                ),
              for (final member in _members)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(member['id']),
                  title: Text(member['name'].toString()),
                  subtitle: Text(
                    member['status'] == 'alumni' ? 'Alumni' : 'Enacteur',
                  ),
                  onChanged: _sending
                      ? null
                      : (value) => setState(() {
                          value == true
                              ? _selected.add(member['id'].toString())
                              : _selected.remove(member['id'].toString());
                        }),
                ),
              TextFormField(
                controller: _note,
                enabled: !_sending,
                maxLines: 3,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Note interne — facultatif',
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
      ),
    ),
    actions: [
      TextButton(
        onPressed: _sending ? null : () => Navigator.pop(context),
        child: const Text('Retour'),
      ),
      if (_error != null && _members.isEmpty)
        TextButton(
          onPressed: _loading ? null : _load,
          child: const Text('Recharger le jury'),
        ),
      FilledButton(
        onPressed: _loading || _sending ? null : _save,
        child: Text(_sending ? 'Enregistrement…' : 'Confirmer l’entretien'),
      ),
    ],
  );
}
