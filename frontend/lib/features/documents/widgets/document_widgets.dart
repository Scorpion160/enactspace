import 'package:flutter/material.dart';

import '../models/document_center_models.dart';
import '../models/document_model.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final DocumentReferenceData references;
  final VoidCallback onOpen;
  const DocumentCard({
    super.key,
    required this.document,
    required this.references,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scope =
        references.projectName(document.projectId) ??
        references.poleName(document.poleId) ??
        references.eventName(document.eventId) ??
        'Club';
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.description_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${document.fileTypeLabel} · ${document.categoryLabel}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  Chip(label: Text(document.statusLabel)),
                  Chip(label: Text(document.visibilityLabel)),
                  if (document.isOfficial)
                    const Chip(
                      avatar: Icon(Icons.verified_rounded, size: 17),
                      label: Text('Officiel'),
                    ),
                  if (document.isTemplate) const Chip(label: Text('Modèle')),
                ],
              ),
              const SizedBox(height: 10),
              _Line(Icons.account_tree_rounded, scope),
              _Line(Icons.calendar_today_rounded, document.createdAtLabel),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ouvrir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Line(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 7),
        Expanded(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}
