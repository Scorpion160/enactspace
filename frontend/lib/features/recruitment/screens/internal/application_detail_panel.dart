import '../../widgets/recruitment_workspace.dart';
import '../../widgets/recruitment_style.dart';
import '../../services/recruitment_campaign_tools.dart';
import '../../widgets/internal/interview_planning_dialog.dart';
import '../../widgets/internal/personality_review_card.dart';
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
  Widget build(BuildContext context) =>
      RecruitmentStyle(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    final application = _application;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            _PanelHeader(
              title:
                  (widget.anonymized ||
                      (_application ?? widget.summary).isAnonymized)
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
                      anonymized: widget.anonymized || application.isAnonymized,
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
    final saved = await showRecruitmentDialog<bool>(
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

class _DetailBody extends StatefulWidget {
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
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  late final Map<String, GlobalKey> _anchors = {
    for (final label in [
      'Réponses',
      'Évaluation',
      'Entretien',
      'Décision',
      'Historique',
    ])
      label: GlobalKey(),
  };
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.anonymized)
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: RecruitmentNotice(
            'Lecture anonymisée : identité, documents et éléments personnels masqués.',
            icon: Icons.visibility_off_outlined,
          ),
        ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            for (final entry in _anchors.entries.where(
              (e) =>
                  e.key != 'Décision' ||
                  widget.application.permissions['can_decide'] != false,
            ))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(
                  onPressed: () {
                    final target = entry.value.currentContext;
                    if (target != null) {
                      Scrollable.ensureVisible(
                        target,
                        duration: const Duration(milliseconds: 240),
                        alignment: 0,
                      );
                    }
                  },
                  child: Text(entry.key),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          key: const Key('application-detail-scroll'),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(
                key: _anchors['Réponses'],
                title: 'Résumé',
                icon: Icons.badge_outlined,
                children: [
                  _InfoGrid(
                    values: {
                      'Identité': widget.anonymized
                          ? widget.application.anonymousCode
                          : widget.application.fullName,
                      'E-mail': widget.anonymized
                          ? 'Identité masquée'
                          : widget.application.email,
                      'Téléphone': widget.anonymized
                          ? 'Identité masquée'
                          : _value(widget.application.phone),
                      'Campagne': widget.campaignTitle,
                      'Statut': widget.application.statusLabel,
                      'Soumise le': _dateTime(widget.application.createdAt),
                      'Département': _value(widget.application.department),
                      'Promotion': _value(widget.application.className),
                      'Niveau': _value(widget.application.studyLevel),
                      if (!widget.anonymized &&
                          widget.application.knownEnactusFrom
                                  ?.trim()
                                  .isNotEmpty ==
                              true)
                        'Découverte d’Enactus ESP':
                            widget.application.knownEnactusFrom!,
                      if (widget.application.preferredPole?.trim().isNotEmpty ==
                          true)
                        'Préférence de pôle indiquée auparavant':
                            widget.application.preferredPole!,
                      if (widget.application.projectInterest
                              ?.trim()
                              .isNotEmpty ==
                          true)
                        'Projet évoqué auparavant':
                            widget.application.projectInterest!,
                      'Disponibilité': _value(widget.application.availability),
                      if (!widget.anonymized)
                        'Résidence au campus':
                            widget.application.campusResident == null
                            ? 'Non renseignée'
                            : widget.application.campusResident!
                            ? 'Oui'
                            : 'Non',
                      if (!widget.anonymized &&
                          widget
                                  .application
                                  .interviewAvailability
                                  ?.isNotEmpty ==
                              true)
                        'Disponibilités pour l’entretien':
                            widget.application.interviewAvailability!,
                      if (!widget.anonymized &&
                          widget.application.interviewPreferences.isNotEmpty)
                        'Formats souhaités': widget
                            .application
                            .interviewPreferences
                            .map(
                              (v) =>
                                  const {
                                    'in_person': 'Présentiel',
                                    'online': 'En ligne',
                                    'hybrid': 'Mixte',
                                  }[v] ??
                                  v,
                            )
                            .join(', '),
                      'Évaluation selon la grille':
                          widget.application.screeningScore == null
                          ? 'À réaliser'
                          : '${widget.application.screeningScore!.toStringAsFixed(1)}/100',
                      'Avis enregistrés':
                          '${widget.application.screeningReviewCount}',
                    },
                  ),
                ],
              ),
              _Section(
                title: 'Réponses',
                icon: Icons.forum_outlined,
                children: [
                  if (widget.application.questionnaireAnswers.isNotEmpty) ...[
                    const Text(
                      'Questionnaire de candidature',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    for (final q in widget.application.questionnaireAnswers)
                      _Answer(
                        q['question']?.toString() ?? '',
                        q['answer']?.toString(),
                      ),
                  ] else ...[
                    _Answer('Motivations', widget.application.motivation),
                    _Answer(
                      'Votre connaissance d’Enactus',
                      widget.application.enactusKnowledge,
                    ),
                    _Answer(
                      'Autres clubs ou associations',
                      widget.application.otherClubs,
                    ),
                    _Answer(
                      'Contribution envisagée',
                      widget.application.contribution,
                    ),
                    _Answer(
                      'Idées de projets',
                      widget.application.projectIdeas,
                    ),
                    _Answer(
                      'Profil de leadership',
                      widget.application.leadershipProfile,
                    ),
                    _Answer(
                      'Expérience associative',
                      widget.application.associativeExperience,
                    ),
                    _Answer(
                      'Commentaire candidat',
                      widget.application.publicComment,
                    ),
                  ],
                ],
              ),
              _Section(
                title: 'Documents',
                icon: Icons.folder_open_outlined,
                children: [
                  if (widget.anonymized)
                    const Text(
                      'Les pièces jointes sont masquées pendant la lecture anonymisée.',
                    )
                  else ...[
                    _DocumentRow(label: 'CV', url: widget.application.cvUrl),
                    _DocumentRow(
                      label: 'Lettre de motivation',
                      url: widget.application.motivationLetterUrl,
                    ),
                    _DocumentRow(
                      label: 'Document complémentaire',
                      url: widget.application.attachmentUrl,
                    ),
                  ],
                ],
              ),
              _Section(
                key: _anchors['Évaluation'],
                title: 'Évaluations',
                icon: Icons.rate_review_outlined,
                children: [
                  FilledButton.icon(
                    key: const Key('candidate-review-action'),
                    onPressed: widget.application.screeningRubric == null
                        ? null
                        : widget.onReview,
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(
                      widget.application.myReview == null
                          ? 'Évaluer'
                          : 'Modifier mon avis',
                    ),
                  ),
                  if (widget.application.screeningRubric == null)
                    const Text(
                      'Actualisez le dossier pour charger la grille d’évaluation.',
                    ),
                  const SizedBox(height: 12),
                  if (widget.reviews.isEmpty)
                    Text('Aucune évaluation officielle enregistrée.')
                  else ...[
                    Text(
                      widget.application.screeningScore == null
                          ? 'La grille reste à renseigner. Les notes antérieures sont conservées ci-dessous.'
                          : 'Indice du jury : ${widget.application.screeningScore!.toStringAsFixed(1)}/100 · ${widget.application.screeningReviewCount} avis',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.application.screeningSpread != null &&
                        widget.application.screeningReviewCount > 1)
                      Text(
                        'Écart entre les avis : ${widget.application.screeningSpread!.toStringAsFixed(1)} points. Discutez les observations avant de décider.',
                      ),
                    const SizedBox(height: 10),
                    ...widget.reviews.map(
                      (review) => _ReviewCard(
                        review,
                        widget.application.screeningRubric,
                      ),
                    ),
                  ],
                ],
              ),
              _Section(
                key: _anchors['Entretien'],
                title: 'Entretien',
                icon: Icons.record_voice_over_outlined,
                children: [
                  _InfoGrid(
                    values: {
                      'Date': widget.application.interviewLabel,
                      'Lieu': _value(widget.application.interviewLocation),
                      'Jury': _value(widget.application.interviewJury),
                      if (widget.application.interviewTeam != null)
                        'Équipe': _value(
                          widget.application.interviewTeam!['name']?.toString(),
                        ),
                      'Détails': _value(widget.application.interviewNote),
                    },
                  ),
                ],
              ),
              _Section(
                key: _anchors['Historique'],
                title: 'Historique',
                icon: Icons.history_rounded,
                children: [
                  if (widget.application.history.isEmpty)
                    Text(
                      'Candidature reçue · ${_dateTime(widget.application.createdAt)}',
                    )
                  else
                    ...widget.application.history.map(_HistoryEntry.new),
                ],
              ),
              if (widget.application.permissions['can_decide'] != false)
                _Section(
                  key: _anchors['Décision'],
                  title: 'Actions sur la candidature',
                  icon: Icons.admin_panel_settings_outlined,
                  children: [
                    CandidateActionsSection(
                      application: widget.application,
                      campaignTitle: widget.campaignTitle,
                      reviewCount: widget.application.screeningReviewCount,
                      reviewAverage: widget.application.screeningScore == null
                          ? null
                          : widget.application.screeningScore! / 5,
                      onStatusChange: widget.onStatusChange,
                      onInterview: widget.onInterview,
                      onAdvancedInterview:
                          widget.gateway is CampaignToolsProvider
                          ? () => showRecruitmentDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => InterviewPlanningDialog(
                                application: widget.application,
                                tools: (widget.gateway as CampaignToolsProvider)
                                    .campaignTools,
                                onSaved: (_) => widget.onConversionCompleted(),
                              ),
                            )
                          : null,
                      feedback: widget.actionFeedback,
                    ),
                  ],
                ),
              if (!widget.anonymized && widget.gateway is CampaignToolsProvider)
                PersonalityReviewCard(
                  application: widget.application,
                  tools:
                      (widget.gateway as CampaignToolsProvider).campaignTools,
                ),
              if (widget.application.interviewNeedsReassignment)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'La composition du jury a changé. Modifie l’entretien pour confirmer une équipe disponible.',
                    ),
                  ),
                ),
              if (!widget.anonymized && widget.application.status == 'accepted')
                CandidateIntegrationSection(
                  application: widget.application,
                  campaignTitle: widget.campaignTitle,
                  gateway: widget.gateway,
                  onCompleted: widget.onConversionCompleted,
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    super.key,
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
