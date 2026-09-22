import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/user_experience.dart';
import '../../members/models/member_model.dart';
import '../models/project_management_models.dart';
import '../models/project_member_model.dart';
import '../models/project_model.dart';
import '../models/project_portfolio_models.dart';
import '../models/project_team_management_models.dart';
import '../services/projects_portfolio_gateway.dart';
import '../widgets/project_detail_widgets.dart';
import '../widgets/project_management_widgets.dart';
import '../widgets/project_team_management_widgets.dart';

class ProjectDetailRouteData {
  final ProjectsPortfolioGateway gateway;
  final ProjectPortfolioItem initialItem;

  const ProjectDetailRouteData({
    required this.gateway,
    required this.initialItem,
  });
}

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final ProjectsPortfolioGateway? gateway;
  final ProjectPortfolioItem? initialItem;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.gateway,
    this.initialItem,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late final ProjectsPortfolioGateway _gateway;
  late Future<ProjectDetailData> _loading;
  UserExperience? _user;
  bool _ignoreInitialItem = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiProjectsPortfolioGateway();
    _loading = _load();
  }

  Future<ProjectDetailData> _load() async {
    final user = await _captureDetail(_gateway.loadCurrentUser());
    _user = user.value;
    final initial = !_ignoreInitialItem && widget.initialItem != null
        ? widget.initialItem!
        : await _loadPortfolioItem();
    final documentsFuture = _captureDetail(
      _gateway.loadDocuments(widget.projectId),
    );
    final eventsFuture = _captureDetail(_gateway.loadEvents());
    final documents = await documentsFuture;
    final events = await eventsFuture;
    final taskAssignees = <String, List<ProjectAssignee>>{};
    if (initial.tasks != null) {
      await Future.wait(
        initial.tasks!.map((task) async {
          final result = await _captureDetail(
            _gateway.loadTaskAssignees(task.id),
          );
          if (result.value != null) {
            taskAssignees[task.id] = result.value!;
          }
        }),
      );
    }
    return ProjectDetailData(
      item: initial,
      documents: documents.value,
      events: events.value
          ?.where((event) => event.projectId == widget.projectId)
          .toList(),
      taskAssignees: taskAssignees,
      documentsUnavailable: documents.error != null,
      eventsUnavailable: events.error != null,
    );
  }

  Future<ProjectPortfolioItem> _loadPortfolioItem() async {
    final projects = await _gateway.loadProjects();
    final matches = projects.where((item) => item.id == widget.projectId);
    if (matches.isEmpty) throw StateError('Projet introuvable');
    final project = matches.first;
    final membersFuture = _captureDetail(_gateway.loadMembers(project.id));
    final tasksFuture = _captureDetail(_gateway.loadTasks(project.id));
    final impactFuture = _captureDetail(_gateway.loadImpact());
    final members = await membersFuture;
    final tasks = await tasksFuture;
    final impact = await impactFuture;
    final typedTasks = tasks.value;
    ProjectNextAction? nextAction;
    if (typedTasks != null) {
      final now = DateTime.now();
      final candidates =
          typedTasks.where((task) {
            final due = DateTime.tryParse(task.dueDate ?? '');
            return !ProjectTaskPresentation.isTerminal(task.status) &&
                due != null &&
                due.isAfter(now);
          }).toList()..sort(
            (a, b) => DateTime.parse(
              a.dueDate!,
            ).compareTo(DateTime.parse(b.dueDate!)),
          );
      if (candidates.isNotEmpty) {
        final task = candidates.first;
        final assigned = await _captureDetail(
          _gateway.loadTaskAssignees(task.id),
        );
        nextAction = ProjectNextAction(
          task: task,
          assignees: assigned.value ?? const [],
        );
      }
    }
    final impacts = impact.value;
    return ProjectPortfolioItem(
      project: project,
      members: members.value,
      tasks: typedTasks,
      impact: impacts?[project.id],
      nextAction: nextAction,
      teamUnavailable: members.error != null,
      tasksUnavailable: tasks.error != null,
      impactUnavailable: impact.error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<ProjectDetailData>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ProjectDetailLoadingState();
            }
            if (snapshot.hasError || snapshot.data == null) {
              return ProjectDetailErrorState(
                onBack: _back,
                onRetry: () => setState(() => _loading = _load()),
              );
            }
            final data = snapshot.data!;
            final canManage = ProjectManagementPermissions.canManage(
              _user,
              data.item.members,
            );
            final teamPermissions = ProjectTeamPermissions.resolve(
              _user,
              data.item.members,
            );
            return ProjectDetailView(
              data: data,
              onBack: _back,
              onHistory: () => context.go(
                '/archives?project_id=${Uri.encodeQueryComponent(widget.projectId)}',
              ),
              teamSection: ProjectTeamManagementSection(
                projectName: data.item.project.name,
                members: data.item.members,
                unavailable: data.item.teamUnavailable,
                permissions: teamPermissions,
                onAddMember: teamPermissions.canManageOrdinaryMembers
                    ? () => _openAddMember(data)
                    : null,
                onChangeLead: teamPermissions.canManageResponsibilities
                    ? () => _openResponsibility(
                        data,
                        ProjectPositionPresentation.lead,
                      )
                    : null,
                onChangeDeputy: teamPermissions.canManageResponsibilities
                    ? () => _openResponsibility(
                        data,
                        ProjectPositionPresentation.deputy,
                      )
                    : null,
                onRemoveMember: teamPermissions.canManageOrdinaryMembers
                    ? (member) => _openRemoval(data, member, teamPermissions)
                    : null,
              ),
              management: canManage
                  ? ProjectManagementSection(
                      onEdit: () => _openEdit(data),
                      onChangeStatus: () => _openStatus(data),
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/projects');
    }
  }

  Future<void> _openEdit(ProjectDetailData data) async {
    final seasons = await _captureDetail(_gateway.loadSeasons());
    if (!mounted) return;
    final updated = await showDialog<ProjectModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProjectFormDialog(
        project: data.item.project,
        seasons: seasons.value ?? const [],
        onSubmit: (draft) => _gateway.updateProject(widget.projectId, draft),
      ),
    );
    if (updated != null) _mutationSucceeded();
  }

  Future<void> _openStatus(ProjectDetailData data) async {
    final updated = await showDialog<ProjectModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProjectStatusDialog(
        item: data.item,
        onSubmit: (target) =>
            _gateway.changeProjectStatus(data.item.project, target),
      ),
    );
    if (updated != null) _mutationSucceeded();
  }

  Future<List<MemberModel>?> _loadDirectoryForDialog() async {
    try {
      return await _gateway.loadMemberDirectory();
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(projectTeamErrorMessage(error))));
      return null;
    }
  }

  Future<void> _openAddMember(ProjectDetailData data) async {
    final directory = await _loadDirectoryForDialog();
    if (!mounted || directory == null) return;
    final result = await showDialog<ProjectMemberMutationResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProjectMemberDialog(
        projectName: data.item.project.name,
        directory: directory,
        activeMemberships: data.item.activeMembers,
        onSubmit: (member) => _gateway.assignProjectMember(
          projectId: widget.projectId,
          userId: member.id,
          position: ProjectPositionPresentation.member,
        ),
      ),
    );
    if (result == null) return;
    _teamMutationSucceeded(
      result.kind == ProjectMemberMutationKind.reactivated
          ? 'Membre réintégré à l’équipe'
          : 'Membre ajouté à l’équipe',
    );
  }

  Future<void> _openResponsibility(
    ProjectDetailData data,
    String targetPosition,
  ) async {
    final directory = await _loadDirectoryForDialog();
    if (!mounted || directory == null) return;
    final current = targetPosition == ProjectPositionPresentation.lead
        ? data.item.lead
        : data.item.deputy;
    final result = await showDialog<ProjectMemberMutationResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProjectLeadChangeDialog(
        projectName: data.item.project.name,
        targetPosition: targetPosition,
        currentHolder: current,
        directory: directory,
        onSubmit: (member) => _gateway.assignProjectMember(
          projectId: widget.projectId,
          userId: member.id,
          position: targetPosition,
        ),
      ),
    );
    if (result == null) return;
    _teamMutationSucceeded(
      targetPosition == ProjectPositionPresentation.lead
          ? 'Chef de projet mis à jour'
          : 'Adjoint du projet mis à jour',
    );
  }

  Future<void> _openRemoval(
    ProjectDetailData data,
    ProjectMemberModel membership,
    ProjectTeamPermissions permissions,
  ) async {
    if (!permissions.canRemove(membership)) return;
    final removed = await showDialog<ProjectMemberModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProjectMemberRemovalDialog(
        projectName: data.item.project.name,
        membership: membership,
        isCurrentUser: membership.userId == _user?.id,
        onSubmit: () => _gateway.removeProjectMember(
          projectId: widget.projectId,
          userId: membership.userId,
        ),
      ),
    );
    if (removed != null) _teamMutationSucceeded('Membre retiré de l’équipe');
  }

  void _teamMutationSucceeded(String message) {
    if (!mounted) return;
    _ignoreInitialItem = true;
    setState(() {
      _loading = _load();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _mutationSucceeded() {
    if (!mounted) return;
    _ignoreInitialItem = true;
    setState(() {
      _loading = _load();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Projet mis à jour')));
  }
}

Future<_DetailSourceResult<T>> _captureDetail<T>(Future<T> future) async {
  try {
    return _DetailSourceResult(value: await future);
  } catch (error) {
    return _DetailSourceResult(error: error);
  }
}

class _DetailSourceResult<T> {
  final T? value;
  final Object? error;
  const _DetailSourceResult({this.value, this.error});
}
