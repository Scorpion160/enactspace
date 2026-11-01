import '../recruitment_style.dart';
import 'package:flutter/material.dart';
import '../../models/application_model.dart';
import '../../services/recruitment_campaign_tools.dart';
import '../../services/recruitment_message.dart';

class PersonalityReviewCard extends StatefulWidget {
  final ApplicationModel application;
  final RecruitmentCampaignTools tools;
  const PersonalityReviewCard({
    super.key,
    required this.application,
    required this.tools,
  });
  @override
  State<PersonalityReviewCard> createState() => _PersonalityReviewCardState();
}

class _PersonalityReviewCardState extends State<PersonalityReviewCard> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.tools.loadPersonality(widget.application.id);
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = recruitmentMessage(
            error,
            fallback: 'Le questionnaire n’a pas pu être chargé.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final controller = TextEditingController();
    final existing = DateTime.tryParse(_data?['due_at']?.toString() ?? '');
    if (existing != null) {
      controller.text =
          '${existing.day.toString().padLeft(2, '0')}/${existing.month.toString().padLeft(2, '0')}/${existing.year}';
    }
    DateTime? due;
    final form = GlobalKey<FormState>();
    final confirmed = await showRecruitmentDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Préparer l’entretien'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Le candidat retrouvera le questionnaire dans le suivi de sa candidature et recevra une invitation par e-mail. Une réponse déjà terminée restera conservée.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Date limite — facultatif',
                  hintText: 'JJ/MM/AAAA, à 23 h 59 à Dakar',
                ),
                validator: (raw) {
                  if (raw == null || raw.trim().isEmpty) {
                    due = null;
                    return null;
                  }
                  final parts = raw
                      .trim()
                      .split('/')
                      .map(int.tryParse)
                      .toList();
                  if (parts.length != 3 || parts.contains(null)) {
                    return 'Indique une date valide.';
                  }
                  if (parts[0]! < 1 ||
                      parts[0]! > 31 ||
                      parts[1]! < 1 ||
                      parts[1]! > 12 ||
                      parts[2]! < 2000 ||
                      parts[2]! > 2100) {
                    return 'Indique une date valide.';
                  }
                  final parsed = DateTime.utc(
                    parts[2]!,
                    parts[1]!,
                    parts[0]!,
                    23,
                    59,
                  );
                  if (parsed.day != parts[0] ||
                      parsed.month != parts[1] ||
                      parsed.year != parts[2] ||
                      !parsed.isAfter(DateTime.now().toUtc())) {
                    return 'Choisis une date à venir.';
                  }
                  due = parsed;
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Confirmer l’invitation'),
          ),
        ],
      ),
    );
    // Dialog route disposal completes after the closing animation.
    Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.tools.invitePersonality(widget.application.id, due);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = recruitmentMessage(
            error,
            fallback: 'L’invitation n’a pas pu être enregistrée.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _data?['status'];
    final results = _data?['results'] as Map?;
    final dimensions = (results?['dimensions'] as List? ?? const [])
        .whereType<Map>();
    final scenarios = (_data?['discussion_guide'] as List? ?? const [])
        .whereType<Map>();
    final answers = _data?['scenario_answers'] as Map? ?? const {};
    final mayInvite =
        widget.application.permissions['can_decide'] == true &&
        const {
          'under_review',
          'interview_scheduled',
          'waiting_list',
        }.contains(widget.application.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mieux connaître le candidat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Un support d’échange : cinq tendances déclarées et des situations Enactus. Les moyennes ne servent ni au classement ni à la note d’admission. La traduction de travail n’est pas validée localement.',
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(onPressed: _load, child: const Text('Réessayer')),
            ],
            if (!_busy && _error == null) ...[
              Text(switch (status) {
                'submitted' => 'Réponses terminées',
                'declined' => 'Le candidat préfère en parler en entretien',
                'invited' => 'Questionnaire proposé au candidat',
                _ => 'Questionnaire non proposé',
              }),
              if (status == 'invited')
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Les réponses en cours restent privées jusqu’à leur confirmation par le candidat.',
                  ),
                ),
              if (_data?['due_at'] != null)
                Text(
                  'Échéance : ${_data!['due_at'].toString().split('T').first} · heure de Dakar',
                ),
              if (mayInvite && status != 'submitted' && status != 'declined')
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _invite,
                    icon: const Icon(Icons.mail_outline),
                    label: Text(
                      status == 'invited'
                          ? 'Modifier l’échéance'
                          : 'Proposer le questionnaire',
                    ),
                  ),
                ),
              for (final dimension in dimensions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${dimension['label']} · ${dimension['mean']}/5',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(dimension['discussion'].toString()),
                    ],
                  ),
                ),
              if (scenarios.isNotEmpty) const Divider(),
              for (final scenario in scenarios)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(scenario['title'].toString()),
                  childrenPadding: const EdgeInsets.only(bottom: 18),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(scenario['question'].toString()),
                          const SizedBox(height: 10),
                          SelectableText(
                            answers[scenario['id']]?.toString() ?? '',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'À approfondir : ${scenario['observe']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
