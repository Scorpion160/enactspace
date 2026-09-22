import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/application_model.dart';
import '../../models/application_review_model.dart';
import '../../services/internal_recruitment_gateway.dart';
import '../../widgets/internal/candidate_actions.dart';
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
        widget.gateway.loadApplication(widget.summary.id),
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
      color: AppTheme.background,
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
                        message: _error.toString().replaceAll(
                          'Exception: ',
                          '',
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
        widget.gateway.loadApplication(widget.summary.id),
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
    padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppTheme.border)),
    ),
    child: Row(
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        InternalStatusBadge(status: status),
        Semantics(
          button: true,
          label: 'Fermer la fiche candidat',
          child: IconButton(
            onPressed: onClose,
            tooltip: 'Fermer',
            icon: const Icon(Icons.close_rounded),
          ),
        ),
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
              'Pôle préféré': _value(application.preferredPole),
              'Projet': _value(application.projectInterest),
              'Disponibilité': _value(application.availability),
              'Indice de présélection': '${application.screeningScore}/100',
            },
          ),
        ],
      ),
      _Section(
        title: 'Réponses',
        icon: Icons.forum_outlined,
        children: [
          _Answer('Motivations', application.motivation),
          _Answer(
            'Comment avez-vous connu Enactus ?',
            application.knownEnactusFrom,
          ),
          _Answer('Votre connaissance d’Enactus', application.enactusKnowledge),
          _Answer('Autres clubs ou associations', application.otherClubs),
          _Answer('Contribution envisagée', application.contribution),
          _Answer('Idées de projets', application.projectIdeas),
          _Answer('Profil de leadership', application.leadershipProfile),
          _Answer('Expérience associative', application.associativeExperience),
          _Answer('Commentaire candidat', application.publicComment),
        ],
      ),
      _Section(
        title: 'Documents',
        icon: Icons.folder_open_outlined,
        children: [
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
      ),
      _Section(
        title: 'Évaluations',
        icon: Icons.rate_review_outlined,
        children: [
          if (reviews.isEmpty)
            const Text('Aucune évaluation officielle enregistrée.')
          else ...[
            Semantics(
              label:
                  'Moyenne officielle ${_average(reviews).toStringAsFixed(1)} sur 20',
              child: Text(
                'Moyenne officielle : ${_average(reviews).toStringAsFixed(1)}/20',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            ...reviews.map(_ReviewCard.new),
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
          Text('Dossier soumis · ${_dateTime(application.createdAt)}'),
          if (application.updatedAt != null)
            Text('Dernière mise à jour · ${_dateTime(application.updatedAt)}'),
          const SizedBox(height: 8),
          const Text(
            'Le backend ne fournit pas encore de journal de transitions détaillé.',
            style: TextStyle(color: AppTheme.secondaryText),
          ),
        ],
      ),
      _Section(
        title: 'Actions sur la candidature',
        icon: Icons.admin_panel_settings_outlined,
        children: [
          CandidateActionsSection(
            application: application,
            campaignTitle: campaignTitle,
            reviewCount: reviews.length,
            reviewAverage: reviews.isEmpty ? null : _average(reviews),
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
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 14,
    children: values.entries
        .map(
          (entry) => SizedBox(
            width: MediaQuery.sizeOf(context).width < 560
                ? double.infinity
                : 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.secondaryText,
                  ),
                ),
                Text(
                  entry.value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        )
        .toList(),
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        SelectableText(_value(value)),
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
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.description_outlined),
        title: Text(label),
        subtitle: Text(available ? _fileName(url!) : 'Non fourni'),
        trailing: available
            ? TextButton(
                onPressed: () => _openDocument(url!),
                child: const Text('Consulter'),
              )
            : null,
      ),
    );
  }

  static Future<void> _openDocument(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    final resolved = uri.hasScheme
        ? uri
        : Uri.parse('${ApiClient.serverUrl}${uri.path}');
    await launchUrl(resolved, webOnlyWindowName: '_blank');
  }
}

class _ReviewCard extends StatelessWidget {
  final ApplicationReviewModel review;

  const _ReviewCard(this.review);

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Évaluation ${review.score?.toStringAsFixed(1) ?? 'sans note'} sur 20, ${_recommendation(review.recommendation)}',
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.softBlack.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${review.score?.toStringAsFixed(1) ?? '—'}/20 · ${_recommendation(review.recommendation)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            'Évaluateur : ${review.reviewerId.isEmpty ? 'Non renseigné' : review.reviewerId}',
          ),
          if (review.comment?.trim().isNotEmpty == true) Text(review.comment!),
        ],
      ),
    ),
  );
}

double _average(List<ApplicationReviewModel> reviews) {
  final scores = reviews.map((item) => item.score).whereType<double>().toList();
  if (scores.isEmpty) return 0;
  return scores.reduce((a, b) => a + b) / scores.length;
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
  return '$day/$month/${value.year}';
}

String _fileName(String value) {
  final segments = Uri.tryParse(value)?.pathSegments ?? const <String>[];
  return segments.isEmpty ? value : segments.last;
}
