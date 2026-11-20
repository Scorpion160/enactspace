import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/help_guide_panel.dart';

class HelpGuideScreen extends StatelessWidget {
  const HelpGuideScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Guide et FAQ'),
      leading: BackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/login'),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          key: const Key('help-guide-scroll'),
          padding: const EdgeInsets.all(20),
          children: const [
            Text(
              'Vos premiers pas dans EnactSpace',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Retrouvez les repères pour activer votre accès, contribuer avec l’équipe et obtenir de l’aide.',
              style: TextStyle(height: 1.6),
            ),
            SizedBox(height: 24),
            HelpGuidePanel(),
          ],
        ),
      ),
    ),
  );
}
