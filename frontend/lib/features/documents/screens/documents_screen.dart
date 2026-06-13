import 'package:flutter/material.dart';
import '../../../shared/widgets/module_placeholder.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Documents',
      subtitle:
          'Documents officiels, modèles, ressources et fichiers partagés.',
      icon: Icons.folder_rounded,
    );
  }
}
