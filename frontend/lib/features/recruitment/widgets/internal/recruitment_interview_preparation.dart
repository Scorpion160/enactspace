import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/auth/auth_service.dart';

/// Staff and assigned jurors' private interview workspace. No candidate mail
/// or public interview state is changed by its read/note actions.
class RecruitmentInterviewPreparation extends StatefulWidget {
  final String campaignId;
  final Future<void> Function(String)? onOpenApplication;
  const RecruitmentInterviewPreparation({
    super.key,
    required this.campaignId,
    this.onOpenApplication,
  });

  @override
  State<RecruitmentInterviewPreparation> createState() =>
      _RecruitmentInterviewPreparationState();
}

class _RecruitmentInterviewPreparationState
    extends State<RecruitmentInterviewPreparation> {
  final _api = ApiClient();
  final _auth = AuthService();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _canManage = false;
  int _page = 0;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RecruitmentInterviewPreparation old) {
    super.didUpdateWidget(old);
    if (old.campaignId != widget.campaignId) _load();
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await _auth.getToken();
    if (token == null) {
      throw StateError('Connecte-toi pour consulter les entretiens.');
    }
    return token;
  }

  Future<void> _load() async {
    final current = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = Map<String, dynamic>.from(
        await _api.get(
              '/recruitment/campaigns/${widget.campaignId}/interviews/drafts',
              token: await _token(),
            )
            as Map,
      );
      if (!mounted || _generation != current) return;
      setState(() {
        _rows = (payload['rows'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _canManage = payload['can_manage'] == true;
        _page = 0;
      });
    } catch (_) {
      if (mounted && current == _generation) {
        setState(
          () =>
              _error = 'Impossible de charger les affectations en préparation.',
        );
      }
    } finally {
      if (mounted && current == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _editNotes(Map<String, dynamic> row) async {
    final applicationId = row['application_id']?.toString() ?? '';
    if (applicationId.isEmpty) return;
    final url =
        '/recruitment/applications/$applicationId/interview/preparation-note';
    final controller = TextEditingController();
    try {
      final data = Map<String, dynamic>.from(
        await _api.get(url, token: await _token()) as Map,
      );
      controller.text = data['body']?.toString() ?? '';
      if (!mounted) return;
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mes notes de préparation'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: TextField(
              key: const Key('juror-private-prep-notes'),
              controller: controller,
              minLines: 6,
              maxLines: 12,
              maxLength: 6000,
              decoration: const InputDecoration(
                hintText: 'Questions à poser, points à approfondir…',
                border: OutlineInputBorder(),
                helperText:
                    'Privées, accessibles uniquement depuis ton compte.',
                helperMaxLines: 2,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enregistrer mes notes'),
            ),
          ],
        ),
      );
      if (save == true) {
        await _api.putJson(
          url,
          token: await _token(),
          data: {'body': controller.text},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notes de préparation enregistrées.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d’enregistrer les notes.')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = _search.text.trim().toLowerCase();
    final visible = _rows
        .where(
          (row) =>
              search.isEmpty ||
              [
                row['candidate_name'],
                row['candidate_department'],
              ].join(' ').toLowerCase().contains(search),
        )
        .toList();
    const perPage = 10;
    final pageCount = (visible.length / perPage).ceil();
    final currentPage = pageCount == 0 ? 0 : _page.clamp(0, pageCount - 1);
    final shown = visible.skip(currentPage * perPage).take(perPage).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_ind_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mes entretiens à préparer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Actualiser les affectations',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Répartition interne. Les horaires ne sont pas encore '
              'communiqués aux candidats.',
            ),
            if (_canManage)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Vue responsable : ensemble des affectations en préparation.',
                ),
              ),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Aucune affectation en préparation pour cette campagne.',
                ),
              )
            else ...[
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Rechercher un candidat',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _page = 0),
              ),
              const SizedBox(height: 8),
              Text('${visible.length} candidat(s)'),
              for (final row in shown)
                Card(
                  margin: const EdgeInsets.only(top: 7),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          row['candidate_name']?.toString() ?? 'Candidat',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${row['candidate_department'] ?? ''} · ${(row['starts_at'] ?? '').toString().replaceAll('T', ' ').replaceAll('Z', '')} · ${row['mode'] == 'online'
                              ? 'En ligne'
                              : row['mode'] == 'hybrid'
                              ? 'Mixte'
                              : 'Présentiel'}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Avec : ${(row['jury'] as List? ?? const []).whereType<Map>().map((person) => person['name']?.toString() ?? '').join(', ')}',
                        ),
                        Text(
                          'Questionnaire : ${switch (row['personality_status']) {
                            'submitted' => 'Terminé',
                            'in_progress' => 'En cours',
                            'declined' => 'Non complété',
                            _ => 'Non disponible',
                          }}',
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (widget.onOpenApplication != null)
                              TextButton.icon(
                                onPressed: () => widget.onOpenApplication!(
                                  row['application_id'].toString(),
                                ),
                                icon: const Icon(Icons.folder_open_outlined),
                                label: const Text('Consulter le dossier'),
                              ),
                            if ((row['jury'] as List? ?? const [])
                                .whereType<Map>()
                                .any((member) => member['is_me'] == true))
                              TextButton.icon(
                                onPressed: () => _editNotes(row),
                                icon: const Icon(Icons.edit_note_outlined),
                                label: const Text('Mes notes'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (pageCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Page précédente',
                        onPressed: currentPage == 0
                            ? null
                            : () => setState(() => _page = currentPage - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Page ${currentPage + 1} / $pageCount'),
                      IconButton(
                        tooltip: 'Page suivante',
                        onPressed: currentPage + 1 >= pageCount
                            ? null
                            : () => setState(() => _page = currentPage + 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
