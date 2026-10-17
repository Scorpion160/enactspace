import 'package:flutter/material.dart';

String veilleLabel(String? value) =>
    const {
      'a_faire': 'À faire',
      'en_cours': 'En cours',
      'bloque': 'Bloqué',
      'termine': 'À relire',
      'valide': 'Accepté',
      'annule': 'Annulé',
      'active': 'En cours',
      'completed': 'Réalisé',
      'cancelled': 'Annulé',
      'open': 'Aide attendue',
      'resolved': 'Résolu',
      'requested': 'À examiner',
      'approved': 'Approuvé',
      'rejected': 'Non retenu',
      'draft': 'En préparation',
      'notified': 'Réponse attendue',
      'response_received': 'Réponse reçue',
      'proposed': 'Proposition à examiner',
      'decided': 'Décision communiquée',
      'appealed': 'Réexamen demandé',
      'review_proposed': 'Nouvelle proposition',
      'reviewed': 'Décision réexaminée',
      'closed': 'Clôturé',
      'accompagnement': 'Accompagnement',
      'clarification': 'Clarification',
      'avertissement': 'Avertissement',
      'penalite_financiere': 'Pénalité financière',
      'classement_sans_suite': 'Classement sans suite',
      'dependance': 'Dépendance externe',
      'ressources': 'Moyens nécessaires',
      'technique': 'Difficulté technique',
      'disponibilite': 'Disponibilité',
      'autre': 'Autre difficulté',
      'notify': 'Informer le membre',
      'respond': 'Apporter ma réponse',
      'propose': 'Préparer une proposition',
      'endorse': 'Donner l’avis d’EnacChef',
      'decide': 'Prendre la décision',
      'appeal': 'Demander un réexamen',
      'propose_review': 'Préparer le réexamen',
      'review_decide': 'Décider après réexamen',
      'accept': 'Accepter la décision',
      'close': 'Clôturer le dossier',
      'comment': 'Ajouter une précision',
      'weekly': 'Point hebdomadaire',
      'monthly': 'Bilan mensuel',
      'handover': 'Passation',
      'basse': 'Basse',
      'normale': 'Normale',
      'haute': 'Haute',
      'urgente': 'Urgente',
    }[value] ??
    value ??
    '';

String veilleDate(dynamic value, {bool withTime = false}) {
  final date = value is DateTime
      ? value
      : DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'À préciser';
  final d = date.toLocal();
  final text =
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  return withTime
      ? '$text à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
      : text;
}

class VeilleCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  const VeilleCard({super.key, this.title, this.icon, required this.child});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    ),
  );
}

class VeilleStatus extends StatelessWidget {
  final String status;
  const VeilleStatus(this.status, {super.key});
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(veilleLabel(status), softWrap: true),
    visualDensity: VisualDensity.compact,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
  );
}

class VeilleEmpty extends StatelessWidget {
  final String message;
  const VeilleEmpty(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
    ),
  );
}
