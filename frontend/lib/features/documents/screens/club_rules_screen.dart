import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lecture fidèle du règlement transmis par le club, disponible hors connexion.
class ClubRulesScreen extends StatelessWidget {
  const ClubRulesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Règlement intérieur')),
    body: FutureBuilder<String>(
      future: rootBundle.loadString(
        'assets/documents/reglement_interieur_enactus_esp.txt',
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Document indisponible.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final text = snapshot.data!.replaceAll('\f', '');
        final starts = RegExp(
          r'(?=Article \d+ :)',
        ).allMatches(text).map((match) => match.start).toList();
        final titles = RegExp(r'^Article \d+ :[^\n]*', multiLine: true);
        return SelectionArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: starts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Les règles de notre équipe',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enactus ESP · 13 articles · Source : texte fourni par le club. '
                              'La numérotation et les formulations originales sont conservées.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              final start = starts[index - 1];
              final end = index < starts.length ? starts[index] : text.length;
              final article = text.substring(start, end).trim();
              final title = titles.firstMatch(article)?.group(0) ?? 'Article';
              final body = article.substring(title.length).trim();
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 9),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 28),
                          Text(
                            body,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.65),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
