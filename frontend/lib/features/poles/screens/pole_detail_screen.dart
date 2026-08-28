import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/pole_portfolio_models.dart';
import '../services/poles_portfolio_gateway.dart';
import '../widgets/pole_detail_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiPolesPortfolioGateway();
    _loading = _load();
  }

  Future<PoleDetailData> _load() async {
    final item = widget.initialItem ?? await _loadDirectItem();
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
          return PoleDetailView(data: snapshot.data!, onBack: _back);
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
}
