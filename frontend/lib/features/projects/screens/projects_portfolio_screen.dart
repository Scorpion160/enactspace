import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/user_experience.dart';
import '../models/project_management_models.dart';
import '../models/project_model.dart';
import '../models/project_portfolio_models.dart';
import '../services/projects_portfolio_gateway.dart';
import '../widgets/project_management_widgets.dart';
import '../widgets/projects_portfolio_widgets.dart';
import 'project_detail_screen.dart';

class ProjectsPortfolioScreen extends StatefulWidget {
  final ProjectsPortfolioGateway? gateway;
  final ValueChanged<ProjectPortfolioItem>? onOpenProject;

  const ProjectsPortfolioScreen({super.key, this.gateway, this.onOpenProject});

  @override
  State<ProjectsPortfolioScreen> createState() =>
      _ProjectsPortfolioScreenState();
}

class _ProjectsPortfolioScreenState extends State<ProjectsPortfolioScreen> {
  late final ProjectsPortfolioGateway _gateway;
  late Future<List<ProjectPortfolioItem>> _loading;
  final _searchController = TextEditingController();
  String _status = 'all';
  String _responsible = 'all';
  ProjectAlertFilter _alert = ProjectAlertFilter.all;
  UserExperience? _user;
  List<ProjectSeasonOption> _seasons = const [];

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiProjectsPortfolioGateway();
    _loading = _loadPortfolio();
    _searchController.addListener(_refreshFilters);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshFilters)
      ..dispose();
    super.dispose();
  }

  void _refreshFilters() => setState(() {});

  Future<List<ProjectPortfolioItem>> _loadPortfolio() async {
    final user = await _capture(_gateway.loadCurrentUser());
    _user = user.value;
    if (ProjectManagementPermissions.canCreate(_user)) {
      final seasons = await _capture(_gateway.loadSeasons());
      _seasons = seasons.value ?? const [];
    }
    final projectsFuture = _gateway.loadProjects();
    final impactFuture = _capture(_gateway.loadImpact());
    final projects = await projectsFuture;
    final impactResult = await impactFuture;

    return Future.wait(
      projects.map((project) async {
        final membersFuture = _capture(_gateway.loadMembers(project.id));
        final tasksFuture = _capture(_gateway.loadTasks(project.id));
        final members = await membersFuture;
        final tasks = await tasksFuture;
        final projectTasks = tasks.value;

        ProjectNextAction? nextAction;
        if (projectTasks != null) {
          final now = DateTime.now();
          final candidates =
              projectTasks.where((task) {
                final due = DateTime.tryParse(task.dueDate ?? '');
                return !ProjectTaskPresentation.isTerminal(task.status) &&
                    due != null &&
                    due.isAfter(now);
              }).toList()..sort((a, b) {
                final left = DateTime.parse(a.dueDate!);
                final right = DateTime.parse(b.dueDate!);
                return left.compareTo(right);
              });
          if (candidates.isNotEmpty) {
            final task = candidates.first;
            final assignees = await _capture(
              _gateway.loadTaskAssignees(task.id),
            );
            nextAction = ProjectNextAction(
              task: task,
              assignees: assignees.value ?? const [],
            );
          }
        }

        final impacts = impactResult.value;
        return ProjectPortfolioItem(
          project: project,
          members: members.value,
          tasks: projectTasks,
          impact: impacts?[project.id],
          nextAction: nextAction,
          teamUnavailable: members.error != null,
          tasksUnavailable: tasks.error != null,
          impactUnavailable: impactResult.error != null,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<ProjectPortfolioItem>>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ProjectPortfolioLoadingState();
            }
            if (snapshot.hasError) {
              return ProjectPortfolioErrorState(onRetry: _retry);
            }
            final allItems = snapshot.data ?? const [];
            if (allItems.isEmpty) return const ProjectPortfolioEmptyState();
            return _buildLoaded(context, allItems);
          },
        ),
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    List<ProjectPortfolioItem> allItems,
  ) {
    final responsibleOptions = {
      for (final item in allItems)
        if (item.lead != null) item.lead!.userId: item.lead!.displayName,
    };
    final items = _filtered(allItems);
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 28 : 16,
                  24,
                  desktop ? 28 : 16,
                  12,
                ),
                child: ProjectsPortfolioHeader(
                  onCreate: ProjectManagementPermissions.canCreate(_user)
                      ? _openCreate
                      : null,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: desktop ? 28 : 16),
                child: ProjectPortfolioFilters(
                  compact: !desktop,
                  searchController: _searchController,
                  selectedStatus: _status,
                  selectedResponsible: _responsible,
                  selectedAlert: _alert,
                  responsibleOptions: responsibleOptions,
                  onStatusChanged: (value) => setState(() => _status = value),
                  onResponsibleChanged: (value) =>
                      setState(() => _responsible = value),
                  onAlertChanged: (value) => setState(() => _alert = value),
                  onReset: _resetFilters,
                ),
              ),
            ),
            if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ProjectNoFilterResultsState(),
              )
            else ...[
              if (desktop)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => ProjectPortfolioRow(
                      item: items[index],
                      onOpen: () => _open(items[index]),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => ProjectPortfolioCard(
                      item: items[index],
                      onOpen: () => _open(items[index]),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  List<ProjectPortfolioItem> _filtered(List<ProjectPortfolioItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      if (query.isNotEmpty &&
          !item.project.name.toLowerCase().contains(query) &&
          !(item.project.description ?? '').toLowerCase().contains(query)) {
        return false;
      }
      if (_status != 'all' && item.project.status != _status) return false;
      if (_responsible != 'all' && item.lead?.userId != _responsible) {
        return false;
      }
      return switch (_alert) {
        ProjectAlertFilter.all => true,
        ProjectAlertFilter.blocked => item.alerts.blockedCount > 0,
        ProjectAlertFilter.overdue => item.alerts.overdueCount > 0,
        ProjectAlertFilter.noNextAction =>
          !item.tasksUnavailable && item.nextAction == null,
        ProjectAlertFilter.incomplete => item.hasIncompleteData,
      };
    }).toList();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _status = 'all';
      _responsible = 'all';
      _alert = ProjectAlertFilter.all;
    });
  }

  void _open(ProjectPortfolioItem item) {
    if (widget.onOpenProject != null) {
      widget.onOpenProject!(item);
      return;
    }
    context.push(
      '/projects/${item.project.id}',
      extra: ProjectDetailRouteData(gateway: _gateway, initialItem: item),
    );
  }

  Future<void> _openCreate() async {
    final created = await showDialog<ProjectModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProjectFormDialog(
        project: null,
        seasons: _seasons,
        onSubmit: _gateway.createProject,
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _loading = _loadPortfolio();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Projet mis à jour')));
  }

  void _retry() => setState(() => _loading = _loadPortfolio());
}

Future<_SourceResult<T>> _capture<T>(Future<T> future) async {
  try {
    return _SourceResult(value: await future);
  } catch (error) {
    return _SourceResult(error: error);
  }
}

class _SourceResult<T> {
  final T? value;
  final Object? error;

  const _SourceResult({this.value, this.error});
}
