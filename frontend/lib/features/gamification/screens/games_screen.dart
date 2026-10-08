import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../services/games_service.dart';

const _games = {
  'quiz': 'Quiz de culture générale',
  'undercover': 'Undercover',
  'icebreaker': 'Icebreakers',
  'werewolf': 'Loup garou',
};
const _gameDescriptions = {
  'quiz': 'Teste tes réflexes et ta culture avec le club.',
  'undercover': 'Repère l’intrus sans révéler ton mot.',
  'icebreaker': 'Des questions légères pour mieux se connaître.',
  'werewolf': 'Bluff, intuition et stratégie jusqu’au dernier tour.',
};
const _gameIcons = <String, IconData>{
  'quiz': Icons.quiz_rounded,
  'undercover': Icons.visibility_rounded,
  'icebreaker': Icons.celebration_rounded,
  'werewolf': Icons.nights_stay_rounded,
};
const _roleNames = {
  'wolf': 'Loup-garou',
  'cupid': 'Cupidon',
  'seer': 'Voyante',
  'villager': 'Villageois',
  'civil': 'Civil',
  'undercover': 'Undercover',
};
const _themes = {
  'quiz': ['mix', 'sciences', 'géographie', 'histoire', 'entrepreneuriat'],
  'undercover': ['mix', 'vie du club', 'quotidien', 'sciences'],
  'icebreaker': ['mix', 'rencontre', 'projets', 'fun'],
  'werewolf': ['mix'],
};

class GamesScreen extends StatefulWidget {
  final GamesService? service;
  const GamesScreen({super.key, this.service});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  late final GamesService _service = widget.service ?? GamesService();
  final _code = TextEditingController();
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _ranking = [];
  String _game = 'quiz', _mode = 'individual', _theme = 'mix', _team = 'A';
  String? _rankingGame;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.mine(),
        _service.leaderboard(game: _rankingGame),
      ]);
      if (mounted) {
        setState(() {
          _rooms = results[0];
          _ranking = results[1];
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _open(Future<Map<String, dynamic>> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final room = await operation();
      if (mounted) context.push('/gamification/games/${room['id']}');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jeux du club')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.softBlack, Color(0xFF25313A)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.enactusYellow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.sports_esports_rounded,
                              color: AppTheme.softBlack,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'À vous de jouer !',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Lance une partie, partage le code et profite d’un moment de club depuis ton téléphone ou ton PC.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Choisis ton jeu',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Chaque format a son ambiance. Tu pourras régler le thème juste après.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth >= 620
                                    ? (constraints.maxWidth - 12) / 2
                                    : constraints.maxWidth;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    for (final entry in _games.entries)
                                      SizedBox(
                                        width: width,
                                        child: _GameChoiceTile(
                                          title: entry.value,
                                          description:
                                              _gameDescriptions[entry.key] ??
                                              '',
                                          icon:
                                              _gameIcons[entry.key] ??
                                              Icons.sports_esports_rounded,
                                          selected: _game == entry.key,
                                          onTap: () => setState(() {
                                            _game = entry.key;
                                            _theme = 'mix';
                                            if (_game != 'quiz') {
                                              _mode = 'individual';
                                            }
                                          }),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            if (_game == 'quiz')
                              DropdownButtonFormField<String>(
                                initialValue: _mode,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Mode',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'individual',
                                    child: Text('Individuel'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'team',
                                    child: Text('Équipes A et B'),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _mode = value ?? 'individual',
                                ),
                              ),
                            if (_game == 'quiz') const SizedBox(height: 12),
                            if (_game == 'quiz' && _mode == 'individual')
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'En solo, seul ton meilleur score compte au classement. Les badges récompensent aussi les parties à plusieurs.',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            if (_game == 'quiz' && _mode == 'individual')
                              const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_game),
                              initialValue: _theme,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Thème',
                              ),
                              items: _themes[_game]!
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _theme = value ?? 'mix'),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _open(
                                      () => _service.create(
                                        _game,
                                        _mode,
                                        _theme,
                                        5,
                                      ),
                                    ),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Créer la session'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Tu as déjà un code ?',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Entre le code partagé par l’hôte pour rejoindre directement la partie.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _code,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Code à 6 caractères',
                                prefixIcon: Icon(Icons.key_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _team,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Équipe si quiz en groupe',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'A',
                                  child: Text('Équipe A'),
                                ),
                                DropdownMenuItem(
                                  value: 'B',
                                  child: Text('Équipe B'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _team = value ?? 'A'),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _open(
                                      () => _service.join(
                                        _code.text.trim(),
                                        team: _team,
                                      ),
                                    ),
                              icon: const Icon(Icons.login_rounded),
                              label: const Text('Rejoindre'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!.replaceAll('Exception: ', ''),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Mes parties',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_rooms.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Aucune partie récente. Crée-en une ou rejoins tes coéquipiers avec un code.',
                        ),
                      ),
                    for (final room in _rooms)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${_games[room['game']]} · ${room['code']}',
                          ),
                          subtitle: Text(
                            '${_gameRoomStatusLabel(room['status'])} · ${(room['players'] as List).length} joueur(s)',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push('/gamification/games/${room['id']}'),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Classement du club',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Marque des points, gagne des parties et grimpe dans le classement du club.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _rankingGame ?? 'all',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Classement par jeu',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('Tous les jeux'),
                        ),
                        ..._games.entries.map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(
                          () => _rankingGame = value == 'all' ? null : value,
                        );
                        _load();
                      },
                    ),
                    for (var i = 0; i < _ranking.length; i++)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text('${_ranking[i]['name']}'),
                          subtitle: Text(
                            '${_ranking[i]['wins']} victoire(s) · ${_ranking[i]['games']} partie(s)',
                          ),
                          trailing: Text('${_ranking[i]['points']} pts'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameChoiceTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GameChoiceTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.secondaryContainer
          : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppTheme.enactusYellow : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.enactusYellow : colors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected ? AppTheme.softBlack : colors.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 2),
                  child: Icon(Icons.check_circle_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _gameRoomStatusLabel(Object? status) {
  switch (status?.toString()) {
    case 'lobby':
      return 'En attente';
    case 'playing':
      return 'En cours';
    case 'finished':
      return 'Terminée';
    default:
      return status?.toString() ?? 'Partie';
  }
}

class GameRoomScreen extends StatefulWidget {
  final String roomId;
  final GamesService? service;
  const GameRoomScreen({super.key, required this.roomId, this.service});

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  late final GamesService _service = widget.service ?? GamesService();
  final _reply = TextEditingController();
  Timer? _poller;
  Map<String, dynamic>? _room;
  String? _error;
  bool _busy = false;
  final Set<String> _lovers = {};

  @override
  void initState() {
    super.initState();
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final result = await _service.room(widget.roomId);
      if (mounted) {
        setState(() {
          _room = result;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _act(String verb, [String? answer]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _service.action(widget.roomId, verb, answer);
      if (mounted) {
        setState(() {
          _room = result;
          _error = null;
          _reply.clear();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final players = room == null
        ? <Map<String, dynamic>>[]
        : (room['players'] as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
    final game = room?['game'] as String?;
    final phase = room?['phase'] as String?;
    final prompt = room?['prompt'] as Map?;
    final answered = room?['answered'] == true;
    final active = players.where((p) => p['eliminated'] != true).toList();
    final myId = room?['my_id'] as String?;
    final loverNames = (room?['lovers'] as List? ?? [])
        .map(
          (id) =>
              players
                  .where((player) => player['id'] == id)
                  .map((player) => player['name'])
                  .firstOrNull ??
              'Joueur',
        )
        .join(' et ');
    final canVote =
        room?['status'] == 'playing' &&
        !answered &&
        active.any((player) => player['id'] == myId) &&
        (game == 'undercover' ||
            game == 'werewolf' &&
                (phase == 'day' ||
                    phase == 'night' && room?['my_role'] == 'wolf'));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          room == null ? 'Partie' : '${_games[game]} · ${room['code']}',
        ),
      ),
      body: room == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _refresh,
                      child: Text('Réessayer : $_error'),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Code : ${room['code']}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Copier le code',
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(
                                              text: '${room['code']}',
                                            ),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Code copié.'),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.copy_rounded),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    game == 'werewolf'
                                        ? 'Statut : ${room['status']} · ${room['phase']}'
                                        : 'Statut : ${room['status']} · Manche ${room['round']}/${room['rounds']}',
                                  ),
                                  Text(
                                    'Les écrans se mettent à jour toutes les 3 secondes.',
                                  ),
                                  if (room['status'] == 'lobby' &&
                                      room['host'] == true)
                                    FilledButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _act('start'),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Démarrer la partie'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (room['status'] != 'lobby')
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (room['my_role'] != null)
                                      Text(
                                        'Votre rôle : ${_roleNames[room['my_role']] ?? room['my_role']}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    if (room['my_secret'] != null)
                                      Text(
                                        'Votre mot ou rôle secret : ${room['my_secret']}',
                                      ),
                                    if (room['lovers'] is List &&
                                        (room['lovers'] as List).isNotEmpty)
                                      Text('Amoureux : $loverNames'),
                                    if (prompt != null)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          '${prompt['question']}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                    if (room['result'] != null)
                                      Text('${room['result']}'),
                                    if (room['reveal'] != null)
                                      Text('Bonne réponse : ${room['reveal']}'),
                                    if (game == 'icebreaker')
                                      for (final response
                                          in (room['shared_answers'] as List))
                                        ListTile(
                                          title: Text('${response['name']}'),
                                          subtitle: Text(
                                            '${response['answer']}',
                                          ),
                                        ),
                                    if (room['status'] == 'finished' &&
                                        room['my_won'] == true)
                                      const Chip(
                                        label: Text(
                                          '🏆 Victoire · badge sur votre profil',
                                        ),
                                      ),
                                    if (room['status'] == 'playing' && answered)
                                      Text(
                                        'Réponse enregistrée · ${room['responses']} réponse(s) reçue(s).',
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          if (room['status'] == 'playing' && !answered) ...[
                            if (game == 'quiz' && prompt?['choices'] is List)
                              for (
                                var i = 0;
                                i < (prompt!['choices'] as List).length;
                                i++
                              )
                                Card(
                                  child: ListTile(
                                    title: Text(
                                      '${(prompt['choices'] as List)[i]}',
                                    ),
                                    onTap: _busy
                                        ? null
                                        : () => _act('answer', '$i'),
                                  ),
                                ),
                            if (game == 'icebreaker')
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _reply,
                                        maxLines: 3,
                                        maxLength: 150,
                                        decoration: const InputDecoration(
                                          labelText: 'Votre réponse',
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _act('answer', _reply.text),
                                        child: const Text('Envoyer'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (game == 'werewolf' &&
                                phase == 'cupid' &&
                                room['my_role'] == 'cupid') ...[
                              Text(
                                'Choisissez deux amoureux',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              for (final player in players)
                                CheckboxListTile(
                                  title: Text('${player['name']}'),
                                  value: _lovers.contains('${player['id']}'),
                                  onChanged: (selected) => setState(() {
                                    final id = '${player['id']}';
                                    if (selected == true &&
                                        _lovers.length < 2) {
                                      _lovers.add(id);
                                    }
                                    if (selected == false) {
                                      _lovers.remove(id);
                                    }
                                  }),
                                ),
                              FilledButton(
                                onPressed: _busy || _lovers.length != 2
                                    ? null
                                    : () => _act('answer', _lovers.join(',')),
                                child: const Text('Lier les amoureux'),
                              ),
                            ],
                            if (canVote) ...[
                              Text(
                                phase == 'night'
                                    ? 'Le loup choisit une cible'
                                    : 'Votez pour un suspect',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              for (final player in active)
                                if (player['id'] != myId)
                                  Card(
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.how_to_vote_outlined,
                                      ),
                                      title: Text('${player['name']}'),
                                      onTap: _busy
                                          ? null
                                          : () => _act(
                                              'answer',
                                              '${player['id']}',
                                            ),
                                    ),
                                  ),
                            ],
                          ],
                          if (room['host'] == true &&
                              room['status'] == 'playing')
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : () => _act('next'),
                                icon: const Icon(Icons.skip_next),
                                label: const Text(
                                  'Terminer la manche / poursuivre',
                                ),
                              ),
                            ),
                          if (_error != null)
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          const SizedBox(height: 18),
                          Text(
                            'Joueurs · ${players.length}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          for (final player in players)
                            Card(
                              child: ListTile(
                                leading: Icon(
                                  player['eliminated'] == true
                                      ? Icons.person_off_outlined
                                      : Icons.person_outline,
                                ),
                                title: Text('${player['name']}'),
                                subtitle: Text(
                                  [
                                    if (player['team'] != null)
                                      'Équipe ${player['team']}',
                                    if (player['eliminated'] == true) 'Éliminé',
                                    if (room['status'] == 'finished' &&
                                        player['role'] != null)
                                      'Rôle : ${_roleNames[player['role']] ?? player['role']}',
                                  ].join(' · '),
                                ),
                                trailing: Text('${player['score']} pts'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
