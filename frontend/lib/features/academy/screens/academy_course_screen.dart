// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../models/academy_models.dart';
import '../services/academy_gateway.dart';

class AcademyCourseScreen extends StatefulWidget {
  final String courseId;
  final AcademyGateway? gateway;
  final UserExperience? currentUser;
  const AcademyCourseScreen({
    super.key,
    required this.courseId,
    this.gateway,
    this.currentUser,
  });
  @override
  State<AcademyCourseScreen> createState() => _AcademyCourseScreenState();
}

class _AcademyCourseScreenState extends State<AcademyCourseScreen> {
  late final AcademyGateway gateway;
  AcademyCourseModel? course;
  UserExperience? currentUser;
  String? error;
  bool loading = true;
  String? busy;
  @override
  void initState() {
    super.initState();
    gateway = widget.gateway ?? ApiAcademyGateway();
    currentUser = widget.currentUser;
    if (currentUser == null) _loadCachedUser();
    load();
  }

  Future<void> _loadCachedUser() async {
    try {
      final cached = await AuthService.readCachedCurrentUser();
      if (cached != null && mounted) {
        setState(() => currentUser = UserExperience.fromJson(cached));
      }
    } catch (_) {
      // Le contenu du cours reste accessible sans permission d’administration.
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await gateway.getCourse(widget.courseId);
      if (mounted) setState(() => course = value);
    } catch (e) {
      if (mounted) setState(() => error = _msg(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> lesson(AcademyLessonModel l) async {
    if (busy != null) return;
    setState(() => busy = l.id);
    try {
      if (!l.started && !l.completed)
        await gateway.startLesson(l.id);
      else if (!l.completed)
        await gateway.completeLesson(l.id);
      await load();
    } catch (e) {
      _snack(_msg(e));
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  Future<void> quiz() async {
    try {
      final q = await gateway.getQuiz(course!.quiz.id);
      if (!mounted) return;
      final answers = await showDialog<List<int>>(
        context: context,
        builder: (_) => _QuizDialog(quiz: q),
      );
      if (answers == null) return;
      final result = await gateway.submitQuiz(q.id, answers);
      if (mounted)
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(result.passed ? 'Quiz réussi' : 'Quiz à reprendre'),
            content: Text(
              'Score : ${result.score.toStringAsFixed(0)}\nBonnes réponses : ${result.correctAnswers?.toString() ?? 'Non communiqué'} / ${result.total}\nPoints : ${result.points}${result.attemptNumber == null ? '' : '\nTentative : ${result.attemptNumber}'}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      await load();
    } catch (e) {
      _snack(_msg(e));
    }
  }

  void _snack(String v) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null)
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                FilledButton(onPressed: load, child: const Text('Réessayer')),
              ],
            ),
          ),
        ),
      );
    final c = course!;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _CourseHeader(
            course: c,
            canManage: currentUser?.canManageAcademy == true,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 24,
                runSpacing: 14,
                children: [
                  _D('Durée', '${c.durationMinutes} min'),
                  _D('Points', '${c.points}'),
                  _D('Progression', '${(c.progress * 100).round()} %'),
                  _D('Rôles cibles', c.targetRolesLabel),
                  _D('Pôle', c.poleId == null ? 'Tous' : 'Pôle associé'),
                  _D('Projet', c.projectId == null ? 'Tous' : 'Projet associé'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Leçons',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final l in c.lessons)
            Card(
              child: ListTile(
                minVerticalPadding: 12,
                leading: CircleAvatar(
                  child: Icon(
                    l.completed
                        ? Icons.check_rounded
                        : l.started
                        ? Icons.play_arrow_rounded
                        : Icons.menu_book_rounded,
                  ),
                ),
                title: Text(
                  l.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${l.typeLabel} · ${l.durationMinutes} min · ${l.statusLabel}${l.externalUrl == null && l.resourceFileId == null ? '' : ' · Ressource disponible'}\n${l.summary}',
                ),
                isThreeLine: true,
                trailing: SizedBox(
                  width: 120,
                  child: FilledButton.tonal(
                    onPressed: busy == l.id || l.completed
                        ? null
                        : () => lesson(l),
                    child: Text(l.started ? 'Terminer' : 'Commencer'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: c.quiz.id.isEmpty ? null : quiz,
            icon: const Icon(Icons.quiz_rounded),
            label: const Text('Ouvrir le quiz'),
          ),
        ],
      ),
    );
  }
}

class _CourseHeader extends StatelessWidget {
  final AcademyCourseModel course;
  final bool canManage;

  const _CourseHeader({required this.course, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(course.levelLabel)),
            Chip(label: Text(course.categoryLabel)),
            if (course.isRequired) const Chip(label: Text('Obligatoire')),
          ],
        ),
        Text(
          course.title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(course.description),
      ],
    );
    final action = OutlinedButton.icon(
      onPressed: () => context.go('/academy/admin'),
      icon: const Icon(Icons.admin_panel_settings_rounded),
      label: const Text('Gestion Academy'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 700 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              if (canManage) ...[const SizedBox(height: 12), action],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: details),
            if (canManage) ...[const SizedBox(width: 16), action],
          ],
        );
      },
    );
  }
}

class AcademyAdminScreen extends StatefulWidget {
  final AcademyGateway? gateway;
  const AcademyAdminScreen({super.key, this.gateway});
  @override
  State<AcademyAdminScreen> createState() => _AcademyAdminScreenState();
}

class _AcademyAdminScreenState extends State<AcademyAdminScreen> {
  late final AcademyGateway gateway;
  List<AcademyCourseModel>? courses;
  AcademyAdminSummary? summary;
  String? error;
  @override
  void initState() {
    super.initState();
    gateway = widget.gateway ?? ApiAcademyGateway();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final r = await Future.wait<dynamic>([
        gateway.getAdminCourses(),
        gateway.getAdminSummary(),
      ]);
      if (mounted)
        setState(() {
          courses = r[0] as List<AcademyCourseModel>;
          summary = r[1] as AcademyAdminSummary;
        });
    } catch (e) {
      if (mounted) setState(() => error = _msg(e));
    }
  }

  Future<void> action(AcademyCourseModel c, String a) async {
    try {
      switch (a) {
        case 'publish':
          await gateway.publishCourse(c.id);
        case 'unpublish':
          await gateway.unpublishCourse(c.id);
        case 'archive':
          await gateway.archiveCourse(c.id);
        case 'restore':
          await gateway.restoreCourse(c.id);
        case 'edit':
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => _CourseDialog(gateway: gateway, course: c),
          );
          if (ok != true) return;
        case 'lessons':
          await showDialog<void>(
            context: context,
            builder: (_) => _LessonsDialog(gateway: gateway, course: c),
          );
      }
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestion Academy',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Cours, publication et leçons — accès contrôlé par le backend.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () =>
                  showDialog<bool>(
                    context: context,
                    builder: (_) => _CourseDialog(gateway: gateway),
                  ).then((v) {
                    if (v == true) load();
                  }),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer un cours'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(error!),
            ),
          )
        else if (courses == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (summary != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  children: [
                    _D('Cours', '${summary!.courses}'),
                    _D('Publiés', '${summary!.publishedCourses}'),
                    _D('Apprenants', '${summary!.learners}'),
                    _D('Complétions', '${summary!.completions}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          for (final c in courses!)
            Card(
              child: ListTile(
                title: Text(
                  c.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${c.levelLabel} · ${c.categoryLabel} · ${c.isPublished ? 'Publié' : 'Non publié'}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => action(c, v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    const PopupMenuItem(
                      value: 'lessons',
                      child: Text('Gérer les leçons'),
                    ),
                    PopupMenuItem(
                      value: c.isPublished ? 'unpublish' : 'publish',
                      child: Text(c.isPublished ? 'Dépublier' : 'Publier'),
                    ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archiver'),
                    ),
                    const PopupMenuItem(
                      value: 'restore',
                      child: Text('Restaurer'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    ),
  );
}

class _QuizDialog extends StatefulWidget {
  final AcademyQuizModel quiz;
  const _QuizDialog({required this.quiz});
  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog> {
  final Map<int, int> answers = {};
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.quiz.title),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.quiz.questions.length; i++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}. ${widget.quiz.questions[i].question}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      for (
                        var j = 0;
                        j < widget.quiz.questions[i].choices.length;
                        j
                      )
                        RadioListTile<int>(
                          value: j,
                          groupValue: answers[i],
                          onChanged: (v) => setState(() => answers[i] = v!),
                          title: Text(widget.quiz.questions[i].choices[j]),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: answers.length == widget.quiz.questions.length
            ? () => Navigator.pop(context, [
                for (var i = 0; i < widget.quiz.questions.length; i++)
                  answers[i]!,
              ])
            : null,
        child: const Text('Soumettre'),
      ),
    ],
  );
}

class _CourseDialog extends StatefulWidget {
  final AcademyGateway gateway;
  final AcademyCourseModel? course;
  const _CourseDialog({required this.gateway, this.course});
  @override
  State<_CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends State<_CourseDialog> {
  late final Map<String, TextEditingController> c;
  late bool requiredCourse, published;
  late String level;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final v = widget.course;
    c = {
      'title': TextEditingController(text: v?.title ?? ''),
      'description': TextEditingController(text: v?.description ?? ''),
      'category': TextEditingController(text: v?.category ?? ''),
      'target_roles': TextEditingController(
        text: v?.targetRoles.join(', ') ?? '',
      ),
      'duration': TextEditingController(
        text: v?.durationMinutes.toString() ?? '',
      ),
      'points': TextEditingController(text: v?.points.toString() ?? ''),
      'pole_id': TextEditingController(text: v?.poleId ?? ''),
      'project_id': TextEditingController(text: v?.projectId ?? ''),
    };
    requiredCourse = v?.isRequired ?? false;
    published = v?.isPublished ?? false;
    level = v?.level ?? 'debutant';
  }

  @override
  void dispose() {
    for (final v in c.values) v.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    final f = {
      'title': c['title']!.text,
      'description': c['description']!.text,
      'category': c['category']!.text,
      'level': level,
      'target_roles': c['target_roles']!.text
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList(),
      'estimated_duration_minutes': int.tryParse(c['duration']!.text) ?? 0,
      'points': int.tryParse(c['points']!.text) ?? 0,
      'is_required': requiredCourse,
      'is_published': published,
      'pole_id': c['pole_id']!.text.isEmpty ? null : c['pole_id']!.text,
      'project_id': c['project_id']!.text.isEmpty
          ? null
          : c['project_id']!.text,
    };
    if (widget.course == null)
      await widget.gateway.createCourse(f);
    else
      await widget.gateway.updateCourse(widget.course!.id, f);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.course == null ? 'Créer un cours' : 'Modifier le cours'),
    content: SizedBox(
      width: 650,
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final e in c.entries)
              TextField(
                controller: e.value,
                minLines: e.key == 'description' ? 3 : 1,
                maxLines: e.key == 'description' ? 5 : 1,
                decoration: InputDecoration(
                  labelText: e.key.replaceAll('_', ' '),
                ),
              ),
            DropdownButtonFormField(
              initialValue: level,
              decoration: const InputDecoration(labelText: 'Niveau'),
              items: const [
                DropdownMenuItem(value: 'debutant', child: Text('Débutant')),
                DropdownMenuItem(
                  value: 'intermediaire',
                  child: Text('Intermédiaire'),
                ),
                DropdownMenuItem(value: 'avance', child: Text('Avancé')),
                DropdownMenuItem(
                  value: 'responsable',
                  child: Text('Responsable'),
                ),
              ],
              onChanged: (v) => level = v!,
            ),
            SwitchListTile(
              value: requiredCourse,
              onChanged: (v) => setState(() => requiredCourse = v),
              title: const Text('Obligatoire'),
            ),
            SwitchListTile(
              value: published,
              onChanged: (v) => setState(() => published = v),
              title: const Text('Publié'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class _LessonsDialog extends StatefulWidget {
  final AcademyGateway gateway;
  final AcademyCourseModel course;
  const _LessonsDialog({required this.gateway, required this.course});
  @override
  State<_LessonsDialog> createState() => _LessonsDialogState();
}

class _LessonsDialogState extends State<_LessonsDialog> {
  List<AcademyLessonModel>? lessons;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final v = await widget.gateway.getAdminLessons(widget.course.id);
    if (mounted) setState(() => lessons = v);
  }

  Future<void> form([AcademyLessonModel? l]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _LessonDialog(
        gateway: widget.gateway,
        courseId: widget.course.id,
        lesson: l,
      ),
    );
    if (ok == true) load();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Leçons · ${widget.course.title}'),
    content: SizedBox(
      width: 650,
      child: lessons == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              shrinkWrap: true,
              children: [
                for (final l in lessons!)
                  ListTile(
                    title: Text(l.title),
                    subtitle: Text('${l.typeLabel} · ordre ${l.orderIndex}'),
                    onTap: () => form(l),
                    trailing: IconButton(
                      tooltip: 'Supprimer la leçon',
                      onPressed: () async {
                        await widget.gateway.deleteLesson(l.id);
                        load();
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
              ],
            ),
    ),
    actions: [
      TextButton.icon(
        onPressed: () => form(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle leçon'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
    ],
  );
}

class _LessonDialog extends StatefulWidget {
  final AcademyGateway gateway;
  final String courseId;
  final AcademyLessonModel? lesson;
  const _LessonDialog({
    required this.gateway,
    required this.courseId,
    this.lesson,
  });
  @override
  State<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<_LessonDialog> {
  late final Map<String, TextEditingController> c;
  late String type;
  bool published = true, busy = false;
  @override
  void initState() {
    super.initState();
    final l = widget.lesson;
    c = {
      'title': TextEditingController(text: l?.title ?? ''),
      'summary': TextEditingController(text: l?.summary ?? ''),
      'content': TextEditingController(text: l?.content ?? ''),
      'order_index': TextEditingController(
        text: l?.orderIndex.toString() ?? '0',
      ),
      'duration_minutes': TextEditingController(
        text: l?.durationMinutes.toString() ?? '0',
      ),
      'resource_file_id': TextEditingController(text: l?.resourceFileId ?? ''),
      'external_url': TextEditingController(text: l?.externalUrl ?? ''),
    };
    type = l?.lessonType ?? 'texte';
    published = l?.isPublished ?? true;
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    final f = {
      'title': c['title']!.text,
      'summary': c['summary']!.text,
      'content': c['content']!.text,
      'lesson_type': type,
      'order_index': int.tryParse(c['order_index']!.text) ?? 0,
      'duration_minutes': int.tryParse(c['duration_minutes']!.text) ?? 0,
      'resource_file_id': c['resource_file_id']!.text.isEmpty
          ? null
          : c['resource_file_id']!.text,
      'external_url': c['external_url']!.text.isEmpty
          ? null
          : c['external_url']!.text,
      'is_published': published,
    };
    if (widget.lesson == null)
      await widget.gateway.createLesson(widget.courseId, f);
    else
      await widget.gateway.updateLesson(widget.lesson!.id, f);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.lesson == null ? 'Nouvelle leçon' : 'Modifier la leçon'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final e in c.entries)
              TextField(
                controller: e.value,
                minLines: e.key == 'content' ? 3 : 1,
                maxLines: e.key == 'content' ? 6 : 1,
                decoration: InputDecoration(
                  labelText: e.key.replaceAll('_', ' '),
                ),
              ),
            DropdownButtonFormField(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const ['texte', 'video', 'document', 'quiz', 'activite']
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(
                        v == 'activite'
                            ? 'Activité'
                            : v[0].toUpperCase() + v.substring(1),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => type = v!,
            ),
            SwitchListTile(
              value: published,
              onChanged: (v) => setState(() => published = v),
              title: const Text('Publiée'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class _D extends StatelessWidget {
  final String l, v;
  const _D(this.l, this.v);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 170,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l, style: Theme.of(context).textTheme.labelMedium),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
