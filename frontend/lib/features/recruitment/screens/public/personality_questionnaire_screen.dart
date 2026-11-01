import '../../widgets/recruitment_style.dart';
import 'package:flutter/material.dart';
import '../../services/recruitment_campaign_tools.dart';
import '../../services/recruitment_message.dart';
import '../../widgets/public/public_recruitment_widgets.dart';

class PersonalityQuestionnaireScreen extends StatefulWidget {
  final String code, email;
  final PublicPersonalityGateway gateway;
  const PersonalityQuestionnaireScreen({
    super.key,
    required this.code,
    required this.email,
    required this.gateway,
  });
  @override
  State<PersonalityQuestionnaireScreen> createState() =>
      _PersonalityQuestionnaireScreenState();
}

class _PersonalityQuestionnaireScreenState
    extends State<PersonalityQuestionnaireScreen> {
  Map<String, dynamic>? _state;
  final Map<String, int> _answers = {};
  final Map<String, TextEditingController> _scenarios = {};
  final _scroll = ScrollController();
  bool _loading = true, _busy = false, _consent = false, _dirty = false;
  int _page = 0;
  String? _error, _saved;
  Map<String, dynamic> get _credentials => {
    'application_id': widget.code,
    'email': widget.email,
  };
  List<Map> get _items => (_state?['instrument']?['items'] as List? ?? const [])
      .whereType<Map>()
      .toList();
  List<Map> get _situations =>
      (_state?['instrument']?['scenarios'] as List? ?? const [])
          .whereType<Map>()
          .toList();
  bool get _finished =>
      const {'submitted', 'declined'}.contains(_state?['status']);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _scenarios.values) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.gateway.request('load', _credentials);
      if (!mounted) return;
      setState(() {
        _state = data;
        _answers.addAll(
          (data['answers'] as Map? ?? const {}).map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
          ),
        );
        for (final row in _situations) {
          final key = row['id'].toString();
          _scenarios[key] = TextEditingController(
            text:
                (data['scenario_answers'] as Map? ?? const {})[key]
                    ?.toString() ??
                '',
          );
        }
        _consent =
            _answers.isNotEmpty ||
            _scenarios.values.any((value) => value.text.isNotEmpty);
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = recruitmentMessage(
            error,
            fallback: 'Le questionnaire n’a pas pu être ouvert.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    setState(() => _error = message);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<bool> _save(String action) async {
    if (_busy || _state == null) return false;
    if (action != 'decline' && !_consent) {
      _showError(
        'Prends connaissance de l’utilisation des réponses avant de continuer.',
      );
      return false;
    }
    if (action == 'submit' &&
        (_answers.length != _items.length ||
            _scenarios.values.any((value) => value.text.trim().isEmpty))) {
      _showError(
        'Certaines affirmations ou situations restent sans réponse. Vérifie les étapes avant de terminer.',
      );
      return false;
    }
    setState(() {
      _busy = true;
      _error = null;
      _saved = null;
    });
    try {
      final data = await widget.gateway.request(action, {
        ..._credentials,
        if (action != 'decline') ...{
          'version': _state!['version'],
          'revision': _state!['revision'],
          'consent': _consent,
          'answers': _answers,
          'scenario_answers': _scenarios.map(
            (key, value) => MapEntry(key, value.text.trim()),
          ),
        },
      });
      if (!mounted) return false;
      setState(() {
        _state = data;
        _dirty = false;
        _saved = action == 'save'
            ? 'Tes réponses sont enregistrées. Tu pourras les retrouver depuis ton suivi.'
            : null;
      });
      return true;
    } catch (error) {
      if (mounted) {
        _showError(
          recruitmentMessage(
            error,
            fallback:
                'L’enregistrement n’a pas abouti. Ta saisie reste sur cette page ; réessaie avant de la quitter.',
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (await _save('save') && mounted) {
      setState(() => _page++);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  Future<void> _finish() async {
    final confirmed = await showRecruitmentDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Partager tes réponses avec le jury ?'),
        content: const Text(
          'Tu pourras consulter ta synthèse dans ton suivi. Tes réponses seront conservées telles quelles pour préparer l’entretien. Elles ne décideront pas de ton admission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Relire'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminer et partager'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _save('submit');
  }

  Future<void> _decline() async {
    final confirmed = await showRecruitmentDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('En parler pendant l’entretien ?'),
        content: const Text(
          'Tes éventuelles réponses enregistrées à ce questionnaire seront effacées. Ta candidature poursuit son parcours et le jury pourra aborder ces sujets avec toi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuer le questionnaire'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Je préfère en parler'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _save('decline');
  }

  @override
  Widget build(BuildContext context) =>
      RecruitmentStyle(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final currentItems = _page < 5
        ? _items.skip(_page * 4).take(4).toList()
        : <Map>[];
    final completeCount =
        _answers.length +
        _scenarios.values.where((value) => value.text.trim().isNotEmpty).length;
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _busy) return;
        final leave = await showRecruitmentDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enregistrer avant de partir ?'),
            content: const Text(
              'Les dernières modifications ne sont pas encore enregistrées.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Rester'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enregistrer et quitter'),
              ),
            ],
          ),
        );
        if (leave == true &&
            mounted &&
            await _save('save') &&
            context.mounted) {
          Navigator.pop(context);
        }
      },
      child: PublicRecruitmentShell(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.all(narrow ? 16 : 28),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Mon suivi'),
                  ),
                ),
                Text(
                  'Préparons notre échange',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          if (_state == null)
                            TextButton(
                              onPressed: _load,
                              child: const Text('Réessayer'),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_saved != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_saved!),
                    ),
                  ),
                if (_state != null && _finished) ...[
                  const SizedBox(height: 16),
                  Icon(
                    _state!['status'] == 'submitted'
                        ? Icons.check_circle_outline
                        : Icons.forum_outlined,
                    size: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _state!['status'] == 'submitted'
                        ? 'Merci, tes réponses sont partagées.'
                        : 'Nous en parlerons pendant l’entretien.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text(
                    'Ce questionnaire ne donne pas de note d’admission et ne remplace pas l’échange avec le jury.',
                  ),
                  if (_state!['results'] is Map) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Tes tendances déclarées',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Moyennes sur 5, sans seuil ni classement. Ce sont des pistes à discuter, pas des étiquettes.',
                    ),
                    for (final row
                        in ((_state!['results'] as Map)['dimensions'] as List)
                            .whereType<Map>())
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${row['label']} · ${row['mean']}/5',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(row['discussion'].toString()),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
                if (_state != null && !_finished) ...[
                  Text(_state!['instrument']['notice'].toString()),
                  if (_state!['due_at'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Échéance : ${_state!['due_at'].toString().split('T').first} · heure de Dakar',
                      ),
                    ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consent,
                    title: const Text(
                      'J’ai compris à quoi servent mes réponses et qui pourra les lire.',
                    ),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _consent = value == true;
                            _dirty = true;
                          }),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: completeCount / 25),
                  const SizedBox(height: 6),
                  Text(
                    '$completeCount réponses sur 25 · Étape ${_page + 1} sur 6',
                  ),
                  const SizedBox(height: 14),
                  if (_page < 5) ...[
                    const Text(
                      'Réponds selon ce qui te ressemble habituellement, plutôt que selon ce que tu voudrais montrer.',
                    ),
                    for (final item in currentItems)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                item['label'].toString(),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (var value = 1; value <= 5; value++)
                                    ChoiceChip(
                                      label: Text(
                                        (_state!['instrument']['scale']
                                                as List)[value - 1]
                                            .toString(),
                                      ),
                                      selected: _answers[item['id']] == value,
                                      onSelected: _busy
                                          ? null
                                          : (_) => setState(() {
                                              _answers[item['id'].toString()] =
                                                  value;
                                              _dirty = true;
                                              _saved = null;
                                            }),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ] else ...[
                    Text(
                      'À toi de jouer, avec Enactus',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Explique ton raisonnement avec tes mots. Un exemple vécu est bienvenu ; ces situations n’ont pas de note automatique.',
                    ),
                    for (final scenario in _situations)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                scenario['title'].toString(),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(scenario['question'].toString()),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _scenarios[scenario['id']],
                                enabled: !_busy,
                                minLines: 3,
                                maxLines: 8,
                                maxLength: 2000,
                                decoration: const InputDecoration(
                                  labelText: 'Ta réponse',
                                  alignLabelWithHint: true,
                                ),
                                onChanged: (_) => setState(() {
                                  _dirty = true;
                                  _saved = null;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      if (_page > 0)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  setState(() => _page--);
                                  if (_scroll.hasClients) _scroll.jumpTo(0);
                                },
                          child: const Text('Précédent'),
                        ),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _save('save'),
                        child: const Text('Enregistrer pour plus tard'),
                      ),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : _page < 5
                            ? _next
                            : _finish,
                        child: Text(
                          _busy
                              ? 'Enregistrement…'
                              : _page < 5
                              ? 'Enregistrer et continuer'
                              : 'Terminer et partager',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _busy ? null : _decline,
                    child: const Text('Je préfère en parler en entretien'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
