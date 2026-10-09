import '../../models/application_history_model.dart';
import '../../models/application_status_presentation.dart';
import '../../services/recruitment_message.dart';
import 'package:flutter/material.dart';
import '../../../../shared/attachments/attachment_picker.dart';
import '../../models/application_model.dart';
import '../../models/application_review_model.dart';
import '../../services/internal_recruitment_gateway.dart';
import '../../widgets/internal/candidate_actions.dart';
import '../../widgets/internal/candidate_review_dialog.dart';
import '../../widgets/internal/candidate_conversion.dart';
import '../../widgets/internal/recruitment_internal_widgets.dart';

class ApplicationDetailPanel extends StatefulWidget {
  final ApplicationModel summary;
  final String campaignTitle;
  final bool anonymized;
  final InternalRecruitmentGateway gateway;
  final ValueChanged<ApplicationModel>? onApplicationChanged;
  final VoidCallback onClose;

  const ApplicationDetailPanel({
    super.key,
    required this.summary,
    required this.campaignTitle,
    required this.anonymized,
    required this.gateway,
    this.onApplicationChanged,
    required this.onClose,
  });

  @override
  State<ApplicationDetailPanel> createState() => _ApplicationDetailPanelState();
}

class _ApplicationDetailPanelState extends State<ApplicationDetailPanel> {
  ApplicationModel? _application;
  List<ApplicationReviewModel> _reviews = const [];
  Object? _error;
  String? _actionFeedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.gateway.loadApplication(
          widget.summary.id,
          anonymized: widget.anonymized,
        ),
        widget.gateway.loadReviews(widget.summary.id),
      ]);
      if (!mounted) return;
      setState(() {
        _application = results[0] as ApplicationModel;
        _reviews = results[1] as List<ApplicationReviewModel>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = _application;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            _PanelHeader(
              title: widget.anonymized
                  ? (_application ?? widget.summary).anonymousCode
                  : (_application ?? widget.summary).fullName,
              status: (_application ?? widget.summary).status,
              onClose: widget.onClose,
            ),
            Expanded(
              child: _error != null
                  ? Center(
                      child: InternalRecruitmentState(
                        icon: Icons.error_outline_rounded,
                        title: 'Dossier indisponible',
                        message: recruitmentMessage(
                          _error!,
                          fallback:
                              'Impossible de charger ce dossier. Réessaie dans un instant.',
                        ),
                        actionLabel: 'Réessayer',
                        onAction: () {
                          setState(() => _error = null);
                          _load();
                        },
                      ),
                    )
                  : application == null
                  ? const Center(child: CircularProgressIndicator())
                  : _DetailBody(
                      application: application,
                      reviews: _reviews,
                      campaignTitle: widget.campaignTitle,
                      anonymized: widget.anonymized,
                      actionFeedback: _actionFeedback,
                      gateway: widget.gateway,
                      onReview: _openReview,
                      onStatusChange: _changeStatus,
                      onInterview: _scheduleInterview,
                      onConversionCompleted: _refreshAfterMutation,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReview() async {
    final application = _application;
    if (application == null || application.screeningRubric == null) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CandidateReviewDialog(
        application: application,
        gateway: widget.gateway,
      ),
    );
    if (saved == true && mounted) {
      setState(
        () => _actionFeedback =
            'Votre avis a été enregistré. Le statut de la candidature reste inchangé.',
      );
      await _refreshAfterMutation();
    }
  }

  Future<void> _changeStatus(String status) async {
    final updated = await widget.gateway.changeStatus(
      applicationId: widget.summary.id,
      status: status,
    );
    if (!mounted) return;
    setState(() {
      _application = updated;
      _actionFeedback =
          'Statut mis à jour : ${updated.statusLabel}. Le dossier a été actualisé.';
    });
    widget.onApplicationChanged?.call(updated);
    await _refreshAfterMutation();
  }

  Future<void> _scheduleInterview({
    required DateTime interviewAt,
    String? location,
    String? link,
    String? jury,
    String? note,
  }) async {
    final updated = await widget.gateway.scheduleInterview(
      applicationId: widget.summary.id,
      interviewAt: interviewAt,
      location: location,
      link: link,
      jury: jury,
      note: note,
    );
    if (!mounted) return;
    setState(() {
      _application = updated;
      _actionFeedback =
          'Entretien enregistré. Le statut et les informations ont été actualisés.';
    });
    widget.onApplicationChanged?.call(updated);
    await _refreshAfterMutation();
  }

  Future<void> _refreshAfterMutation() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.gateway.loadApplication(
          widget.summary.id,
          anonymized: widget.anonymized,
        ),
        widget.gateway.loadReviews(widget.summary.id),
      ]);
      if (!mounted) return;
      final refreshed = results[0] as ApplicationModel;
      setState(() {
        _application = refreshed;
        _reviews = results[1] as List<ApplicationReviewModel>;
      });
      widget.onApplicationChanged?.call(refreshed);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _actionFeedback =
            '${_actionFeedback ?? 'Action enregistrée.'} '
            'Le rafraîchissement complet pourra être relancé.';
      });
    }
  }
}

class _PanelHeader extends StatelessWidget {
  final String title;
  final String status;
  final VoidCallback onClose;

  const _PanelHeader({
    required this.title,
    required this.status,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fiche candidat',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              tooltip: 'Fermer la fiche candidat',
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InternalStatusBadge(status: status),
      ],
    ),
  );
}

class _DetailBody extends StatelessWidget {
  final ApplicationModel application;
  final List<ApplicationReviewModel> reviews;
  final String campaignTitle;
  final bool anonymized;
  final String? actionFeedback;
  final InternalRecruitmentGateway gateway;
  final VoidCallback onReview;
  final CandidateStatusCallback onStatusChange;
  final CandidateInterviewCallback onInterview;
  final Future<void> Function() onConversionCompleted;

  const _DetailBody({
    required this.application,
    required this.reviews,
    required this.campaignTitle,
    required this.anonymized,
    required this.actionFeedback,
    required this.gateway,
    required this.onReview,
    required this.onStatusChange,
    required this.onInterview,
    required this.onConversionCompleted,
  });

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('application-detail-scroll'),
    padding: const EdgeInsets.all(18),
    children: [
      _Section(
        title: 'Résumé',
        icon: Icons.badge_outlined,
        children: [
          _InfoGrid(
            values: {
              'Identité': anonymized
                  ? application.anonymousCode
                  : application.fullName,
              'E-mail': anonymized ? 'Identité masquée' : application.email,
              'Téléphone': anonymized
                  ? 'Identité masquée'
                  : _value(application.phone),
              'Campagne': campaignTitle,
              'Statut': application.statusLabel,
              'Soumise le': _dateTime(application.createdAt),
              'Département / classe':
                  '${_value(application.department)} · ${_value(application.className)}',
              'Niveau': _value(application.studyLevel),
              if (!anonymized &&
                  application.knownEnactusFrom?.trim().isNotEmpty == true)
                'Découverte d’Enactus ESP': application.knownEnactusFrom!,
              if (application.preferredPole?.trim().isNotEmpty == true)
                'Préférence de pôle indiquée auparavant':
                    application.preferredPole!,
              if (application.projectInterest?.trim().isNotEmpty == true)
                'Projet évoqué auparavant': application.projectInterest!,
              'Disponibilité': _value(application.availability),
              'Évaluation selon la grille': application.screeningScore == null
                  ? 'À réaliser'
                  : '${application.screeningScore!.toStringAsFixed(1)}/100',
              'Avis enregistrés': '${application.screeningReviewCount}',
            },
          ),
        ],
      ),
      _Section(
        title: 'Réponses',
        icon: Icons.forum_outlined,
        children: [
          if (application.questionnaireAnswers.isNotEmpty) ...[
            const Text(
              'Questionnaire de candidature',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final q in application.questionnaireAnswers)
              _Answer(q['question']?.toString() ?? '', q['answer']?.toString()),
          ] else ...[
            _Answer('Motivations', application.motivation),
            _Answer(
              'Votre connaissance d’Enactus',
              application.enactusKnowledge,
            ),
            _Answer('Autres clubs ou associations', application.otherClubs),
            _Answer('Contribution envisagée', application.contribution),
            _Answer('Idées de projets', application.projectIdeas),
            _Answer('Profil de leadership', application.leadershipProfile),
            _Answer(
              'Expérience associative',
              application.associativeExperience,
            ),
            _Answer('Commentaire candidat', application.publicComment),
          ],
        ],
      ),
      _Section(
        title: 'Documents',
        icon: Icons.folder_open_outlined,
        children: [
          if (anonymized)
            const Text(
              'Les pièces jointes sont masquées pendant la lecture anonymisée.',
            )
          else ...[
            _DocumentRow(label: 'CV', url: application.cvUrl),
            _DocumentRow(
              label: 'Lettre de motivation',
              url: application.motivationLetterUrl,
            ),
            _DocumentRow(
              label: 'Document complémentaire',
              url: application.attachmentUrl,
            ),
          ],
        ],
      ),
      _Section(
        title: 'Évaluations',
        icon: Icons.rate_review_outlined,
        children: [
          FilledButton.icon(
            key: const Key('candidate-review-action'),
            onPressed: application.screeningRubric == null ? null : onReview,
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(
              application.myReview == null ? 'Évaluer' : 'Modifier mon avis',
            ),
          ),
          if (application.screeningRubric == null)
            const Text(
              'Actualisez le dossier pour charger la grille d’évaluation.',
            ),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            Text('Aucune évaluation officielle enregistrée.')
          else ...[
            Text(
              application.screeningScore == null
                  ? 'La grille reste à renseigner. Les notes antérieures sont conservées ci-dessous.'
                  : 'Indice du jury : ${application.screeningScore!.toStringAsFixed(1)}/100 · ${application.screeningReviewCount} avis',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (application.screeningSpread != null &&
                application.screeningReviewCount > 1)
              Text(
                'Écart entre les avis : ${application.screeningSpread!.toStringAsFixed(1)} points. Discutez les observations avant de décider.',
              ),
            const SizedBox(height: 10),
            ...reviews.map(
              (review) => _ReviewCard(review, application.screeningRubric),
            ),
          ],
        ],
      ),
      if (application.interviewAt != null ||
          application.interviewLocation?.trim().isNotEmpty == true ||
          application.interviewNote?.trim().isNotEmpty == true)
        _Section(
          title: 'Entretien',
          icon: Icons.record_voice_over_outlined,
          children: [
            _InfoGrid(
              values: {
                'Date': application.interviewLabel,
                'Lieu': _value(application.interviewLocation),
                'Jury': _value(application.interviewJury),
                'Détails': _value(application.interviewNote),
              },
            ),
          ],
        ),
      _Section(
        title: 'Historique',
        icon: Icons.history_rounded,
        children: [
          if (application.history.isEmpty)
            Text('Candidature reçue · ${_dateTime(application.createdAt)}')
          else
            ...application.history.map(_HistoryEntry.new),
        ],
      ),
      _Section(
        title: 'Actions sur la candidature',
        icon: Icons.admin_panel_settings_outlined,
        children: [
          CandidateActionsSection(
            application: application,
            campaignTitle: campaignTitle,
            reviewCount: application.screeningReviewCount,
            reviewAverage: application.screeningScore == null
                ? null
                : application.screeningScore! / 5,
            onStatusChange: onStatusChange,
            onInterview: onInterview,
            feedback: actionFeedback,
          ),
        ],
      ),
      if (!anonymized && application.status == 'accepted')
        CandidateIntegrationSection(
          application: application,
          campaignTitle: campaignTitle,
          gateway: gateway,
          onCompleted: onConversionCompleted,
        ),
    ],
  );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Card(
    key: Key('detail-section-$title'),
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

class _InfoGrid extends StatelessWidget {
  final Map<String, String> values;

  const _InfoGrid({required this.values});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 580 ||
              MediaQuery.textScalerOf(context).scale(16) > 23
          ? 1
          : 2;
      final width = (constraints.maxWidth - 18 * (columns - 1)) / columns;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final entry in values.entries)
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    entry.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _Answer extends StatelessWidget {
  final String label;
  final String? value;

  const _Answer(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        SelectableText(_value(value), style: const TextStyle(height: 1.6)),
      ],
    ),
  );
}

class _DocumentRow extends StatelessWidget {
  final String label;
  final String? url;

  const _DocumentRow({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final available = url?.trim().isNotEmpty == true;
    return Semantics(
      label: 'Document $label, ${available ? 'disponible' : 'non fourni'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (available)
              StoredAttachmentButton(
                url: url!,
                label: 'Consulter la pièce jointe',
              )
            else
              Text(
                'Non fourni',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ApplicationReviewModel review;

  final Map<String, dynamic>? rubric;
  const _ReviewCard(this.review, this.rubric);

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Évaluation ${review.score?.toStringAsFixed(1) ?? 'sans note'} sur 20, ${_recommendation(review.recommendation)}',
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.criteriaAssessment == null
                ? 'Note antérieure · Hors de la nouvelle grille'
                : 'Évaluation par critères',
          ),
          Text(
            '${review.score?.toStringAsFixed(1) ?? '—'}/20 · ${_recommendation(review.recommendation)}',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            'Évaluateur : ${review.reviewerName?.trim().isNotEmpty == true ? review.reviewerName : 'Un membre du jury'}',
          ),
          ..._criterionObservations(context),
          if (review.comment?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(review.comment!, style: const TextStyle(height: 1.6)),
            ),
        ],
      ),
    ),
  );
  List<Widget> _criterionObservations(BuildContext context) {
    final rows = (review.criteriaAssessment?['ratings'] as List? ?? const [])
        .whereType<Map>();
    final criteria = (rubric?['criteria'] as List? ?? const [])
        .whereType<Map>();
    final labels = {for (final row in criteria) row['id']: row['label']};
    return [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${labels[row['criterion_id']] ?? row['criterion_id']} · ${row['rating']}/4',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                row['evidence']?.toString() ?? '',
                style: const TextStyle(height: 1.6),
              ),
            ],
          ),
        ),
    ];
  }
}

class _HistoryEntry extends StatelessWidget {
  final ApplicationHistoryModel entry;
  const _HistoryEntry(this.entry);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(switch (entry.kind) {
          'submission' => Icons.inbox_outlined,
          'interview' => Icons.event_outlined,
          'integration' => Icons.person_add_alt_1_outlined,
          _ => Icons.swap_horiz_rounded,
        }, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${_dateTime(entry.occurredAt.toIso8601String())} · ${entry.actorName}',
                style: TextStyle(
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (entry.fromStatus != null && entry.toStatus != null)
                Text(
                  '${ApplicationStatusPresentation.fromStatus(entry.fromStatus!).title} → ${ApplicationStatusPresentation.fromStatus(entry.toStatus!).title}',
                  style: const TextStyle(height: 1.5),
                ),
              if (entry.scheduledFor != null)
                Text(
                  'Rendez-vous : ${_dateTime(entry.scheduledFor!.toIso8601String())}',
                  style: const TextStyle(height: 1.5),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _recommendation(String value) => switch (value) {
  'favorable' => 'Favorable',
  'defavorable' => 'Défavorable',
  _ => 'Avec réserves',
};

String _value(String? value) =>
    value?.trim().isNotEmpty == true ? value!.trim() : 'Non renseigné';

String _dateTime(String? raw) {
  final value = DateTime.tryParse(raw ?? '')?.toLocal();
  if (value == null) return 'Non renseignée';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year} à ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
