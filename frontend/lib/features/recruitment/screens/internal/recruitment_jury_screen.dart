import 'package:flutter/material.dart';
import '../../models/recruitment_campaign_model.dart';
import '../../services/recruitment_campaign_tools.dart';
import '../../services/recruitment_message.dart';

class RecruitmentJuryScreen extends StatefulWidget {
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
    final confirmed = await showDialog<bool>(
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

  @override
  Widget build(BuildContext context) {
    final members = (_roster?['members'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final canManage = _roster?['can_manage'] == true;
    final appointed = members
        .where((row) => row['appointed'] == true)
        .map((row) => row['user_id'].toString())
        .toSet();
    return Scaffold(
      appBar: AppBar(title: const Text('Le jury de la campagne')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Des générations qui se rencontrent',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Enacteurs et alumni sélectionnés peuvent consulter et évaluer les dossiers de leur campagne. Les responsables gardent la gestion du planning et des décisions.',
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                key: ValueKey('jury-campaign-$_campaign'),
                initialValue: _campaign,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(labelText: 'Campagne'),
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
                        });
                        _load();
                      },
              ),
              if (widget.campaigns.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Crée une campagne avant de constituer son jury.',
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Réessayer'),
                ),
              ],
              if (_feedback != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_feedback!, semanticsLabel: _feedback),
                ),
              const SizedBox(height: 18),
              if ((_roster?['interviews_needing_reassignment'] as List? ??
                      const [])
                  .isNotEmpty) ...[
                Text(
                  'Entretiens à réattribuer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final row
                    in (_roster!['interviews_needing_reassignment'] as List)
                        .whereType<Map>())
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_busy_outlined),
                      title: Text(row['name'].toString()),
                      subtitle: Text(
                        '${row['interview_at'].toString().replaceAll('T', ' ').replaceAll('Z', '')} · Dakar',
                      ),
                      trailing: widget.onOpenApplication == null
                          ? null
                          : IconButton(
                              tooltip: 'Ouvrir le dossier',
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      await widget.onOpenApplication!(
                                        row['application_id'].toString(),
                                      );
                                      if (mounted) await _load();
                                    },
                            ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              Text(
                'Membres sélectionnés',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!_busy && members.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Le jury n’a pas encore été constitué.'),
                ),
              for (final member in members)
                Card(
                  child: ListTile(
                    leading: Icon(
                      member['status'] == 'alumni'
                          ? Icons.school_outlined
                          : Icons.person_outline,
                    ),
                    title: Text(member['name'].toString()),
                    subtitle: Text(
                      '${member['status'] == 'alumni' ? 'Alumni' : 'Enacteur'} · ${member['active'] == true
                          ? 'Sélectionné'
                          : member['appointed'] == true
                          ? 'Compte indisponible'
                          : 'Retiré du jury'}',
                    ),
                    trailing: canManage && member['appointed'] == true
                        ? IconButton(
                            tooltip: 'Retirer du jury',
                            onPressed: _busy ? null : () => _revoke(member),
                            icon: const Icon(Icons.person_remove_outlined),
                          )
                        : null,
                  ),
                ),
              if (canManage) ...[
                const SizedBox(height: 22),
                Text(
                  'Ajouter un membre',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  enabled: !_busy,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Chercher un enacteur ou un alumni…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Chercher',
                      onPressed: _busy ? null : _load,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Les comptes proposés sont actifs et leur adresse e-mail est vérifiée. Recherche par nom pour affiner la liste.',
                ),
                for (final person in _eligible.where(
                  (row) => !appointed.contains(row['id'].toString()),
                ))
                  ListTile(
                    title: Text(person['name'].toString()),
                    subtitle: Text(
                      person['status'] == 'alumni' ? 'Alumni' : 'Enacteur',
                    ),
                    trailing: IconButton(
                      tooltip: 'Ajouter au jury',
                      onPressed: _busy ? null : () => _appoint(person),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
