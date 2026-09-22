import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/user_experience.dart';
import '../../members/models/member_model.dart';
import '../models/pole_management_models.dart';
import '../models/pole_model.dart';
import '../models/pole_portfolio_models.dart';
import '../services/poles_portfolio_gateway.dart';
import '../widgets/pole_detail_widgets.dart';
import '../widgets/pole_management_widgets.dart';
import 'poles_portfolio_screen.dart';

class PoleDetailRouteData {
  final PolesPortfolioGateway gateway;
  final PolePortfolioItem initialItem;

  const PoleDetailRouteData({required this.gateway, required this.initialItem});
}

class PoleDetailScreen extends StatefulWidget {
  final String poleId;
  final PolesPortfolioGateway? gateway;
  final PolePortfolioItem? initialItem;

  const PoleDetailScreen({
    super.key,
    required this.poleId,
    this.gateway,
    this.initialItem,
  });

  @override
  State<PoleDetailScreen> createState() => _PoleDetailScreenState();
}

class _PoleDetailScreenState extends State<PoleDetailScreen> {
  late final PolesPortfolioGateway _gateway;
  late Future<PoleDetailData> _loading;
  UserExperience? _user;
  bool _ignoreInitialItem = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiPolesPortfolioGateway();
    _loading = _load();
  }

  Future<PoleDetailData> _load() async {
    final user = await capturePoleSource(_gateway.loadCurrentUser());
    _user = user.value;
    final item = !_ignoreInitialItem && widget.initialItem != null
        ? widget.initialItem!
        : await _loadDirectItem();
    final documentsFuture = capturePoleSource(
      _gateway.loadDocuments(widget.poleId),
    );
    final eventsFuture = capturePoleSource(_gateway.loadEvents());
    final postsFuture = capturePoleSource(_gateway.loadPosts(widget.poleId));
    final assignees = <String, List<PoleAssignee>>{};
    if (item.tasks != null) {
      await Future.wait(
        item.tasks!.map((task) async {
          final result = await capturePoleSource(
            _gateway.loadTaskAssignees(task.id),
          );
          if (result.value != null) assignees[task.id] = result.value!;
        }),
      );
    }
    final documents = await documentsFuture;
    final events = await eventsFuture;
    final posts = await postsFuture;
    return PoleDetailData(
      item: item,
      documents: documents.value,
      events: events.value
          ?.where((event) => event.poleId == widget.poleId)
          .toList(),
      posts: posts.value
          ?.where((post) => post.poleId == widget.poleId)
          .toList(),
      taskAssignees: assignees,
      documentsUnavailable: documents.error != null,
      activityUnavailable: events.error != null || posts.error != null,
    );
  }

  Future<PolePortfolioItem> _loadDirectItem() async {
    final items = await loadPolesPortfolio(_gateway);
    final matches = items.where((item) => item.pole.id == widget.poleId);
    if (matches.isEmpty) throw StateError('Pôle introuvable');
    return matches.first;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<PoleDetailData>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PoleDetailLoadingState();
          }
          if (snapshot.hasError || snapshot.data == null) {
            return PoleDetailErrorState(
              onBack: _back,
              onRetry: () => setState(() => _loading = _load()),
            );
          }
          final data = snapshot.data!;
          final permissions = PoleManagementPermissions.resolve(
            _user,
            data.item.members,
          );
          return PoleDetailView(
            data: data,
            onBack: _back,
            onHistory: () => context.go(
              '/archives?pole_id=${Uri.encodeQueryComponent(widget.poleId)}',
            ),
            management: permissions.canEditPole
                ? PoleManagementActions(onEdit: () => _openEdit(data))
                : null,
            teamSection: PoleTeamManagementSection(
              poleName: data.item.pole.name,
              members: data.item.members,
              unavailable: data.item.membersUnavailable,
              permissions: permissions,
              onAddMember: permissions.canManageOrdinaryMembers
                  ? () => _openAddMember(data)
                  : null,
              onChangeLead: permissions.canManageResponsibilities
                  ? () =>
                        _openResponsibility(data, PolePositionPresentation.lead)
                  : null,
              onChangeDeputy: permissions.canManageResponsibilities
                  ? () => _openResponsibility(
                      data,
                      PolePositionPresentation.deputy,
                    )
                  : null,
              onRemoveMember: permissions.canManageOrdinaryMembers
                  ? (member) => _openRemoval(data, member, permissions)
                  : null,
            ),
          );
        },
      ),
    ),
  );

  void _back() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/poles');
    }
  }

  Future<void> _openEdit(PoleDetailData data) async {
    final updated = await showDialog<PoleModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PoleFormDialog(
        pole: data.item.pole,
        onSubmit: (draft) => _gateway.updatePole(widget.poleId, draft),
      ),
    );
    if (updated != null) _mutationSucceeded('Pôle mis à jour');
  }

  Future<List<MemberModel>?> _loadDirectory() async {
    try {
      return await _gateway.loadMemberDirectory();
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(poleManagementErrorMessage(error))),
      );
      return null;
    }
  }

  Future<void> _openAddMember(PoleDetailData data) async {
    final directory = await _loadDirectory();
    if (!mounted || directory == null) return;
    final result = await showDialog<PoleMemberMutationResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PoleMemberDialog(
        poleName: data.item.pole.name,
        directory: directory,
        activeMemberships: data.item.activeMembers,
        onSubmit: (member) => _gateway.assignPoleMember(
          poleId: widget.poleId,
          userId: member.id,
          position: PolePositionPresentation.member,
        ),
      ),
    );
    if (result == null) return;
    _mutationSucceeded('Équipe du pôle mise à jour');
  }

  Future<void> _openResponsibility(PoleDetailData data, String position) async {
    final directory = await _loadDirectory();
    if (!mounted || directory == null) return;
    final current = position == PolePositionPresentation.lead
        ? data.item.lead
        : data.item.deputy;
    final result = await showDialog<PoleMemberMutationResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PoleResponsibilityDialog(
        poleName: data.item.pole.name,
        targetPosition: position,
        currentHolder: current,
        directory: directory,
        onSubmit: (member) => _gateway.assignPoleMember(
          poleId: widget.poleId,
          userId: member.id,
          position: position,
        ),
      ),
    );
    if (result == null) return;
    _mutationSucceeded(
      position == PolePositionPresentation.lead
          ? 'Chef de pôle mis à jour'
          : 'Adjoint du pôle mis à jour',
    );
  }

  Future<void> _openRemoval(
    PoleDetailData data,
    MemberModel member,
    PoleManagementPermissions permissions,
  ) async {
    if (!permissions.canRemove(member)) return;
    final removed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PoleMemberRemovalDialog(
        poleName: data.item.pole.name,
        membership: member,
        onSubmit: () =>
            _gateway.removePoleMember(poleId: widget.poleId, userId: member.id),
      ),
    );
    if (removed == true) _mutationSucceeded('Membre retiré de l’équipe');
  }

  void _mutationSucceeded(String message) {
    if (!mounted) return;
    _ignoreInitialItem = true;
    setState(() => _loading = _load());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
