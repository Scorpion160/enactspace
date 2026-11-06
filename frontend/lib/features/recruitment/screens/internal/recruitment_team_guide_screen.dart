import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecruitmentTeamGuideScreen extends StatefulWidget {
  final Map<String, dynamic>? content;
  const RecruitmentTeamGuideScreen({super.key, this.content});
  @override
  State<RecruitmentTeamGuideScreen> createState() => _RecruitmentTeamGuideScreenState();
}

class _RecruitmentTeamGuideScreenState extends State<RecruitmentTeamGuideScreen> {
  late final Future<Map<String, dynamic>> _guide = widget.content != null
      ? Future.value(widget.content!) : rootBundle
      .loadString('assets/documents/recruitment_team_guide.json')
      .then((value) => Map<String, dynamic>.from(jsonDecode(value) as Map));
  String _query = '';

  bool _matches(Map section) => _query.isEmpty ||
      '${section['title']} ${section['paragraphs'] ?? ''} ${section['body'] ?? ''} ${section['subject'] ?? ''}'
          .toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(title: const Text('Guide du recrutement', maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: const TabBar(tabs: [Tab(text: 'Le parcours'), Tab(text: 'Les mails')])),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _guide,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Padding(padding: EdgeInsets.all(24),
              child: Text('Le guide n’a pas pu être ouvert. Ferme cette page puis réessaie.')));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final guide = snapshot.data!;
          final sections = (guide['sections'] as List).cast<Map>().where(_matches).toList();
          final mails = (guide['mails'] as List).cast<Map>().where(_matches).toList();
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: TextField(
              decoration: const InputDecoration(labelText: 'Rechercher dans le guide', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            )),
            Expanded(child: TabBarView(children: [
              ListView(padding: const EdgeInsets.all(16), children: [
                Text(guide['title'].toString(), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(guide['introduction'].toString(), style: const TextStyle(height: 1.55)),
                const SizedBox(height: 18),
                if (sections.isEmpty) const Text('Aucune étape ne correspond à cette recherche.'),
                for (final section in sections) Card(child: ExpansionTile(
                  key: PageStorageKey('guide-${section['title']}'),
                  title: Text(section['title'].toString()),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final paragraph in section['paragraphs'] as List)
                    Padding(padding: const EdgeInsets.only(top: 12), child: SelectableText(
                      paragraph.toString(), style: const TextStyle(height: 1.55))),
                  ],
                )),
              ]),
              ListView(padding: const EdgeInsets.all(16), children: [
                const Text('Les éléments entre crochets sont remplacés par les informations du candidat et de son rendez-vous. Les messages de résultat sont préparés lors de la publication du lot.', style: TextStyle(height: 1.55)),
                const SizedBox(height: 16),
                if (mails.isEmpty) const Text('Aucun mail ne correspond à cette recherche.'),
                for (final mail in mails) Card(child: ExpansionTile(
                  key: PageStorageKey('mail-${mail['kind']}'),
                  title: Text(mail['title'].toString()),
                  subtitle: Text(mail['subject'].toString()),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [SelectableText(mail['body'].toString(), style: const TextStyle(height: 1.55))],
                )),
              ]),
            ])),
          ]);
        },
      ),
    ),
  );
}
