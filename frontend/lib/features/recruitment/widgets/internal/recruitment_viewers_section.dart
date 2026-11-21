import 'package:flutter/material.dart';

import '../../services/recruitment_campaign_tools.dart';

/// Separate from jury membership: readers cannot evaluate or change decisions.
class RecruitmentViewersSection extends StatefulWidget {
  final String campaignId;
  final RecruitmentCampaignTools tools;
  const RecruitmentViewersSection({
    super.key,
    required this.campaignId,
    required this.tools,
  });

  @override
  State<RecruitmentViewersSection> createState() =>
      _RecruitmentViewersSectionState();
}

class _RecruitmentViewersSectionState extends State<RecruitmentViewersSection> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _eligible = const [];
  bool _busy = false;
  String? _message;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        widget.tools.loadReaders(widget.campaignId),
        widget.tools.eligibleReaders(widget.campaignId, _search.text),
      ]);
      if (!mounted || requestId != _generation) return;
      final roster = values[0] as Map<String, dynamic>;
      setState(() {
        _members = (roster['members'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _eligible = values[1] as List<Map<String, dynamic>>;
      });
    } catch (_) {
      if (mounted && requestId == _generation) {
        setState(
          () => _error =
              'Impossible de charger les accès. Actualisez pour réessayer.',
        );
      }
    } finally {
      if (mounted && requestId == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _grant(Map<String, dynamic> member) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      await widget.tools.grantReader(
        widget.campaignId,
        member['id'].toString(),
      );
      if (!mounted) return;
      setState(
        () => _message = 'Accès de consultation accordé à ${member['name']}.',
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = "L'accès n'a pas pu être accordé. Réessayez.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(Map<String, dynamic> member) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Retirer l'accès aux candidatures ?"),
        content: Text(
          "${member['name']} ne pourra plus consulter les dossiers grâce à "
          "cette autorisation. Aucun avis du jury ne sera effacé. "
          "Un accès lié à une responsabilité EnacChef ou à une désignation "
          "au jury restera applicable.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Retirer l'accès"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      await widget.tools.revokeReader(
        widget.campaignId,
        member['id'].toString(),
      );
      if (!mounted) return;
      setState(() => _message = "L'autorisation temporaire a été retirée.");
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = "L'autorisation n'a pas pu être retirée. Réessayez.",
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _members
        .where((member) => member['appointed'] == true)
        .toList();
    final ids = active.map((member) => member['user_id'].toString()).toSet();
    final suggestions = _eligible
        .where((member) => !ids.contains(member['id'].toString()))
        .take(12);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Accès temporaires aux candidatures',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualiser les autorisations',
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Choisissez un enacteur ou un alumni pour consulter les "
              "candidatures anonymisées durant la campagne. "
              "Cet accès est limité à la lecture : il ne permet ni de noter, "
              "ni de modifier les dossiers ou les décisions. "
              "Il peut être retiré à tout moment.",
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
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
            if (_message != null)
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            const SizedBox(height: 10),
            Text(
              'Autorisations actives (${active.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Aucun accès temporaire pour cette campagne.'),
              ),
            for (final member in active)
              ListTile(
                leading: Icon(
                  member['status'] == 'alumni'
                      ? Icons.school_outlined
                      : Icons.person_outline,
                ),
                title: Text(member['name'].toString()),
                subtitle: Text(
                  member['status'] == 'alumni'
                      ? 'Alumni · Consultation uniquement'
                      : 'Enacteur · Consultation uniquement',
                ),
                trailing: IconButton(
                  tooltip: "Retirer l'accès",
                  onPressed: _busy ? null : () => _revoke(member),
                  icon: const Icon(Icons.person_remove_outlined),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Accorder un accès',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              enabled: !_busy,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                labelText: 'Rechercher un enacteur ou un alumni',
                hintText: 'Nom ou adresse électronique',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Rechercher',
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            for (final person in suggestions)
              ListTile(
                title: Text(person['name'].toString()),
                subtitle: Text(
                  person['status'] == 'alumni' ? 'Alumni' : 'Enacteur',
                ),
                trailing: IconButton(
                  tooltip: "Donner l'accès de consultation",
                  onPressed: _busy ? null : () => _grant(person),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
