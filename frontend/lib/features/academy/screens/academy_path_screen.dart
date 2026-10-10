import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/academy_models.dart';
import '../services/academy_gateway.dart';

class AcademyPathScreen extends StatefulWidget {
  final String pathId;
  final AcademyGateway? gateway;
  const AcademyPathScreen({super.key, required this.pathId, this.gateway});
  @override
  State<AcademyPathScreen> createState() => _AcademyPathScreenState();
}

class _AcademyPathScreenState extends State<AcademyPathScreen> {
  late final AcademyGateway _gateway = widget.gateway ?? ApiAcademyGateway();
  AcademyHomeData? _data;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _gateway.loadHome();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_data == null) return const Center(child: CircularProgressIndicator());
    final paths = _data!.paths.where((p) => p.id == widget.pathId);
    if (paths.isEmpty) {
      return const Center(
        child: Text('Ce parcours n’est pas disponible actuellement.'),
      );
    }
    final path = paths.first;
    final courses = [
      for (final id in path.courseIds)
        ..._data!.courses.where((c) => c.id == id),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(path.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            path.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 16),
          const Text(
            'Avance étape par étape : termine les leçons et réussis le quiz pour débloquer la suite. Tu peux relire tes formations à tout moment.',
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < courses.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${i + 1}. ${courses[i].title}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (courses[i].isLocked) ...[
                      const Chip(
                        avatar: Icon(Icons.lock_outline, size: 18),
                        label: Text('À débloquer'),
                      ),
                      Text(
                        courses[i].lockReason,
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      courses[i].description,
                      style: const TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${courses[i].completedLessonCount}/${courses[i].lessonCount} leçons terminées${courses[i].quizPassed ? ' · Quiz réussi' : ''}',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => context.go(
                        '/academy/courses/${courses[i].id}${courses[i].isLocked || courses[i].isMastered ? '' : '?resume=true'}',
                        extra: _gateway,
                      ),
                      icon: Icon(
                        courses[i].isLocked
                            ? Icons.lock_outline
                            : Icons.play_arrow,
                      ),
                      label: Text(
                        courses[i].isLocked
                            ? 'Voir les prérequis'
                            : courses[i].isMastered
                            ? 'Relire la formation'
                            : 'Continuer cette formation',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
