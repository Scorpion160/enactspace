import 'package:flutter/material.dart';

class ApplicationStatusPresentation {
  final String status;
  final String title;
  final String explanation;
  final String nextAction;
  final int timelineStep;
  final IconData icon;
  final bool terminalException;

  const ApplicationStatusPresentation({
    required this.status,
    required this.title,
    required this.explanation,
    required this.nextAction,
    required this.timelineStep,
    required this.icon,
    this.terminalException = false,
  });

  static const supportedStatuses = <String>{
    'submitted',
    'under_review',
    'interview_scheduled',
    'accepted',
    'rejected',
    'waiting_list',
    'cancelled',
  };

  static ApplicationStatusPresentation fromStatus(String rawStatus) {
    final status = switch (rawStatus) {
      'received' => 'submitted',
      'preselected' => 'under_review',
      'interview' => 'interview_scheduled',
      _ => rawStatus,
    };

    return switch (status) {
      'under_review' => const ApplicationStatusPresentation(
        status: 'under_review',
        title: 'En cours d’étude',
        explanation: 'L’équipe examine ton parcours et tes motivations.',
        nextAction:
            'Reste attentif à l’adresse e-mail indiquée dans ton dossier.',
        timelineStep: 1,
        icon: Icons.fact_check_outlined,
      ),
      'interview_scheduled' => const ApplicationStatusPresentation(
        status: 'interview_scheduled',
        title: 'Entretien programmé',
        explanation: 'Ton dossier avance vers un échange avec l’équipe.',
        nextAction:
            'Consulte les informations de l’entretien et prépare tes questions.',
        timelineStep: 2,
        icon: Icons.record_voice_over_outlined,
      ),
      'accepted' => const ApplicationStatusPresentation(
        status: 'accepted',
        title: 'Candidature retenue',
        explanation: 'Félicitations, ta candidature a été retenue.',
        nextAction: 'L’équipe te contactera pour la suite de ton intégration.',
        timelineStep: 3,
        icon: Icons.verified_outlined,
      ),
      'rejected' => const ApplicationStatusPresentation(
        status: 'rejected',
        title: 'Candidature non retenue',
        explanation: 'Cette campagne ne se poursuit pas avec ta candidature.',
        nextAction:
            'Merci pour ton intérêt. Tu pourras suivre les prochaines campagnes.',
        timelineStep: 3,
        icon: Icons.info_outline_rounded,
        terminalException: true,
      ),
      'waiting_list' => const ApplicationStatusPresentation(
        status: 'waiting_list',
        title: 'Liste d’attente',
        explanation: 'Ton dossier reste considéré si une place se libère.',
        nextAction: 'Aucune action n’est nécessaire pour le moment.',
        timelineStep: 2,
        icon: Icons.hourglass_top_rounded,
        terminalException: true,
      ),
      'cancelled' => const ApplicationStatusPresentation(
        status: 'cancelled',
        title: 'Candidature clôturée',
        explanation: 'Le traitement de cette candidature est terminé.',
        nextAction:
            'Tu peux consulter les prochaines campagnes depuis l’espace candidat.',
        timelineStep: 0,
        icon: Icons.cancel_outlined,
        terminalException: true,
      ),
      _ => const ApplicationStatusPresentation(
        status: 'submitted',
        title: 'Reçue',
        explanation: 'Ta candidature a bien été transmise à l’équipe.',
        nextAction:
            'Conserve ton code de suivi et attends la prochaine mise à jour.',
        timelineStep: 0,
        icon: Icons.inbox_outlined,
      ),
    };
  }
}
