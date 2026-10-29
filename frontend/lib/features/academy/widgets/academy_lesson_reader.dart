import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/ui/heritage_photo.dart';
import '../models/academy_lesson_sections.dart';
import '../models/academy_models.dart';
import '../services/academy_gateway.dart';
import 'academy_artwork.dart';
import 'academy_illustration.dart';
import 'academy_style.dart';

/// A dedicated reader. Only explicit completion records progress.
class AcademyLessonReader extends StatefulWidget {
  final AcademyCourseModel course;
  final AcademyLessonModel initialLesson;
  final AcademyGateway gateway;
  const AcademyLessonReader({
    super.key,
    required this.course,
    required this.initialLesson,
    required this.gateway,
  });

  @override
  State<AcademyLessonReader> createState() => _AcademyLessonReaderState();
}

class _AcademyLessonReaderState extends State<AcademyLessonReader> {
  final _scroll = ScrollController();
  final _sectionKeys = <int, GlobalKey>{};
  final _started = <String>{};
  late int _index;
  bool _saving = false;
  bool _opening = false;
  String? _failure;
  Brightness? _brightness;
  double _readingScale = 1;

  AcademyLessonModel get _lesson => widget.course.lessons[_index];
  bool get _busy => _saving || _opening;
  List<AcademyLessonSection> get _sections {
    final content = _lesson.content?.trim();
    return AcademyLessonSection.parse(
      content == null || content.isEmpty ? _lesson.summary : content,
    );
  }

  @override
  void initState() {
    super.initState();
    _index = widget.course.lessons.indexWhere(
      (l) => l.id == widget.initialLesson.id,
    );
    assert(_index >= 0, 'The selected lesson belongs to this course.');
    _started.add(widget.initialLesson.id);
    _started.addAll(
      widget.course.lessons
          .where((l) => l.started || l.completed)
          .map((l) => l.id),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _selectLesson(int index) async {
    if (_busy ||
        index == _index ||
        index < 0 ||
        index >= widget.course.lessons.length ||
        widget.course.isLocked) {
      return;
    }
    final next = widget.course.lessons[index];
    setState(() {
      _opening = true;
      _failure = null;
    });
    try {
      if (!_started.contains(next.id) && !next.completed) {
        await widget.gateway.startLesson(next.id);
      }
      if (!mounted) return;
      setState(() {
        _started.add(next.id);
        _index = index;
        _sectionKeys.clear();
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (_) {
      if (mounted) {
        setState(
          () => _failure =
              'Cette leçon ne peut pas être ouverte pour le moment. Réessaie dans quelques instants.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _complete() async {
    if (_busy || _lesson.completed || widget.course.isLocked) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final result = await widget.gateway.completeLesson(_lesson.id);
      if (mounted) Navigator.of(context).pop(result.label);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure =
              'Ta lecture reste ouverte. La validation n’a pas abouti ; tu peux réessayer.';
        });
      }
    }
  }

  Future<void> _openResource() async {
    final uri = Uri.tryParse(_lesson.externalUrl ?? '');
    try {
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Resource unavailable');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _failure =
              'La ressource ne peut pas être ouverte. Tu peux continuer à lire la leçon ici.',
        );
      }
    }
  }

  void _jumpTo(int index) {
    final target = _sectionKeys[index]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 260),
        alignment: 0.04,
      );
    }
  }

  void _showProgram() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AcademyStyle(
        brightness: _brightness,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.75,
            child: _program(
              onSelect: (index) {
                Navigator.of(sheetContext).pop();
                _selectLesson(index);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AcademyStyle(
    brightness: _brightness,
    child: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return PopScope(
          canPop: !_busy,
          child: Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: 'Fermer la leçon',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
                title: const Text('La leçon'),
                actions: [
                  PopupMenuButton<double>(
                    tooltip: 'Taille du texte',
                    icon: const Icon(Icons.text_fields_rounded),
                    initialValue: _readingScale,
                    onSelected: (value) =>
                        setState(() => _readingScale = value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 1, child: Text('Taille habituelle')),
                      PopupMenuItem(
                        value: 1.15,
                        child: Text('Texte plus grand'),
                      ),
                      PopupMenuItem(
                        value: 1.3,
                        child: Text('Texte très grand'),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: colors.brightness == Brightness.dark
                        ? 'Lire en clair'
                        : 'Lire en sombre',
                    icon: Icon(
                      colors.brightness == Brightness.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    onPressed: () => setState(
                      () => _brightness = colors.brightness == Brightness.dark
                          ? Brightness.light
                          : Brightness.dark,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final leftRail = constraints.maxWidth >= 1080 && scale <= 1.3;
                  final rightRail =
                      constraints.maxWidth >= 1430 && scale <= 1.3;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (leftRail)
                        SizedBox(
                          width: 255,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
                            child: Card(
                              child: _program(onSelect: _selectLesson),
                            ),
                          ),
                        ),
                      Expanded(
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(
                              scale * _readingScale,
                            ),
                          ),
                          child: _reading(context, showProgram: !leftRail),
                        ),
                      ),
                      if (rightRail)
                        SizedBox(
                          width: 230,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
                            child: Card(child: _outline()),
                          ),
                        ),
                    ],
                  );
                },
              ),
              bottomNavigationBar: _footer(context),
            ),
          ),
        );
      },
    ),
  );

  Widget _program({required ValueChanged<int> onSelect}) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        widget.course.title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 12),
      AcademyArtwork(
        name: academyCourseArtwork(widget.course.title, widget.course.category),
        height: 105,
        panoramic: false,
      ),
      const SizedBox(height: 12),
      Text(
        '${widget.course.lessonCount} leçons · ${widget.course.durationMinutes} min',
      ),
      const SizedBox(height: 18),
      const Text(
        'LE PROGRAMME',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 10),
      for (var index = 0; index < widget.course.lessons.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Builder(
            builder: (context) {
              final item = widget.course.lessons[index];
              final selected = index == _index;
              final colors = Theme.of(context).colorScheme;
              return Material(
                color: selected ? colors.tertiaryContainer : colors.surface,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  selected: selected,
                  selectedColor: colors.onTertiaryContainer,
                  enabled: !_busy,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: selected
                        ? academyYellow
                        : colors.surfaceContainerHighest,
                    foregroundColor: selected ? academyInk : colors.onSurface,
                    child: item.completed
                        ? const Icon(Icons.check, size: 18)
                        : Text('${index + 1}'.padLeft(2, '0')),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  subtitle: Text(
                    '${item.durationMinutes} min · ${item.completed
                        ? 'Terminé'
                        : selected
                        ? 'En cours'
                        : item.statusLabel}',
                  ),
                  onTap: () => onSelect(index),
                ),
              );
            },
          ),
        ),
      if (widget.course.quiz.id.isNotEmpty) ...[
        const Divider(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.quiz_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.course.quizPassed
                    ? 'Quiz réussi'
                    : widget.course.canTakeQuiz
                    ? 'Le quiz t’attend sur la fiche de formation.'
                    : 'Termine les leçons pour accéder au quiz.',
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _outline() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Dans cette leçon',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < _sections.length; i++)
        if (_sections[i].heading != null)
          TextButton.icon(
            onPressed: () => _jumpTo(i),
            icon: const Icon(Icons.circle, size: 7),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _sections[i].heading!,
                style: const TextStyle(height: 1.4),
              ),
            ),
          ),
    ],
  );

  Widget _reading(BuildContext context, {required bool showProgram}) {
    final lesson = _lesson;
    final sections = _sections;
    final subject = '${widget.course.title} ${lesson.title}';
    final photo =
        heritagePhotoFor(subject) ??
        const HeritagePhotoData(
          'world-cup-2018-delegation',
          'Apprendre ensemble et porter ses projets plus loin.',
        );
    return SingleChildScrollView(
      key: const Key('academy-reader-scroll'),
      controller: _scroll,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showProgram)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _showProgram,
                        icon: const Icon(Icons.format_list_numbered_rounded),
                        label: const Text('Le programme'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'LEÇON ${(_index + 1).toString().padLeft(2, '0')} / ${widget.course.lessonCount.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    lesson.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AcademyPill(lesson.typeLabel),
                      AcademyPill(
                        'Lecture : environ ${lesson.readingMinutes} min',
                      ),
                      if (lesson.practiceMinutes > 0)
                        AcademyPill(
                          'Pratique : environ ${lesson.practiceMinutes} min',
                          warm: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  HeritagePhoto(photo: photo, height: 220),
                  const SizedBox(height: 22),
                  for (var index = 0; index < sections.length; index++)
                    Padding(
                      key: _sectionKeys.putIfAbsent(index, GlobalKey.new),
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _LessonSection(section: sections[index]),
                    ),
                  if (sections.isEmpty)
                    const Text(
                      'Le contenu de cette leçon n’est pas encore disponible.',
                    ),
                  ExpansionTile(
                    title: const Text('Les idées en image'),
                    children: [
                      AcademyIllustration(
                        courseTitle: widget.course.title,
                        lessonTitle: lesson.title,
                        showPhoto: false,
                        showHeading: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completed = _lesson.completed;
    final action = FilledButton.icon(
      key: const Key('complete-reading-lesson'),
      onPressed: _busy
          ? null
          : completed
          ? () => Navigator.of(context).pop()
          : _complete,
      icon: _saving || _opening
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              completed ? Icons.arrow_back_rounded : Icons.check_circle_outline,
            ),
      label: Text(
        completed ? 'Retour à la formation' : 'J’ai terminé cette leçon',
        textAlign: TextAlign.center,
      ),
    );
    final resource = _lesson.externalUrl?.trim().isNotEmpty == true
        ? OutlinedButton.icon(
            onPressed: _busy ? null : _openResource,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text(
              'Consulter la ressource',
              textAlign: TextAlign.center,
            ),
          )
        : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _failure!,
                    style: TextStyle(color: colors.error, height: 1.4),
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow =
                      constraints.maxWidth < 730 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3;
                  final navigation = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Leçon précédente',
                        onPressed: !_busy && _index > 0
                            ? () => _selectLesson(_index - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text('${_index + 1}/${widget.course.lessonCount}'),
                      IconButton(
                        tooltip: 'Leçon suivante',
                        onPressed:
                            !_busy && _index + 1 < widget.course.lessonCount
                            ? () => _selectLesson(_index + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  );
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.course.lessonCount > 1)
                          Align(alignment: Alignment.center, child: navigation),
                        if (resource != null) ...[
                          resource,
                          const SizedBox(height: 8),
                        ],
                        action,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      if (resource != null) Flexible(child: resource),
                      const Spacer(),
                      if (widget.course.lessonCount > 1) ...[
                        navigation,
                        const SizedBox(width: 14),
                      ],
                      Flexible(flex: 2, child: action),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonSection extends StatelessWidget {
  final AcademyLessonSection section;
  const _LessonSection({required this.section});
  @override
  Widget build(BuildContext context) {
    final heading = section.heading;
    final key = heading?.toLowerCase() ?? '';
    final objective = key.contains('objectif');
    final practice = key.contains('jouer') || key == 'en pratique';
    final field = key == 'sur le terrain';
    final boxed = objective || practice || field;
    final colors = Theme.of(context).colorScheme;
    final foreground = practice || field
        ? colors.onTertiaryContainer
        : objective
        ? colors.onSecondaryContainer
        : colors.onSurface;
    return Container(
      padding: EdgeInsets.all(boxed ? 20 : 0),
      decoration: boxed
          ? BoxDecoration(
              color: practice || field
                  ? colors.tertiaryContainer
                  : colors.secondaryContainer,
              borderRadius: BorderRadius.circular(18),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heading != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  objective
                      ? Icons.track_changes_rounded
                      : practice
                      ? Icons.edit_rounded
                      : field
                      ? Icons.explore_outlined
                      : Icons.menu_book_rounded,
                  color: boxed ? foreground : colors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    heading,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            if (section.body.isNotEmpty) const SizedBox(height: 12),
          ],
          if (section.body.isNotEmpty)
            Text(
              section.body,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: foreground, height: 1.75),
            ),
        ],
      ),
    );
  }
}
