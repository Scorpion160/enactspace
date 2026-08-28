import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/pole_portfolio_models.dart';
import '../services/poles_portfolio_gateway.dart';
import '../widgets/poles_portfolio_widgets.dart';
import 'pole_detail_screen.dart';

class PolesPortfolioScreen extends StatefulWidget {
  final PolesPortfolioGateway? gateway;
  final ValueChanged<PolePortfolioItem>? onOpenPole;

  const PolesPortfolioScreen({super.key, this.gateway, this.onOpenPole});

  @override
  State<PolesPortfolioScreen> createState() => _PolesPortfolioScreenState();
}

class _PolesPortfolioScreenState extends State<PolesPortfolioScreen> {
  late final PolesPortfolioGateway _gateway;
  late Future<List<PolePortfolioItem>> _loading;
  final _searchController = TextEditingController();
  String _type = 'all';
  String _responsible = 'all';
  PoleAlertFilter _alert = PoleAlertFilter.all;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiPolesPortfolioGateway();
    _loading = loadPolesPortfolio(_gateway);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<List<PolePortfolioItem>>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PolePortfolioLoadingState();
          }
          if (snapshot.hasError) {
            return PolePortfolioErrorState(onRetry: _retry);
          }
          final allItems = snapshot.data ?? const [];
          if (allItems.isEmpty) return const PolePortfolioEmptyState();
          return _buildLoaded(allItems);
        },
      ),
    ),
  );

  Widget _buildLoaded(List<PolePortfolioItem> allItems) {
    final responsibleOptions = {
      for (final item in allItems)
        if (item.lead != null) item.lead!.id: item.lead!.displayName,
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
                child: const PolesPortfolioHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: desktop ? 28 : 16),
                child: PolePortfolioFilters(
                  compact: !desktop,
                  searchController: _searchController,
                  selectedType: _type,
                  selectedResponsible: _responsible,
                  selectedAlert: _alert,
                  responsibleOptions: responsibleOptions,
                  onTypeChanged: (value) => setState(() => _type = value),
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
                child: PoleNoFilterResultsState(),
              )
            else if (desktop)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => PolePortfolioRow(
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
                  itemBuilder: (context, index) => PolePortfolioCard(
                    item: items[index],
                    onOpen: () => _open(items[index]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<PolePortfolioItem> _filtered(List<PolePortfolioItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    return items.where((item) {
      if (query.isNotEmpty &&
          !item.pole.name.toLowerCase().contains(query) &&
          !item.pole.displayShortName.toLowerCase().contains(query)) {
        return false;
      }
      final normalizedType = item.pole.type.trim().toLowerCase();
      if (_type == 'unknown' &&
          (normalizedType == 'metier' ||
              normalizedType == 'métier' ||
              normalizedType == 'support')) {
        return false;
      }
      if (_type != 'all' && _type != 'unknown' && normalizedType != _type) {
        return false;
      }
      if (_responsible != 'all' && item.lead?.id != _responsible) return false;
      return switch (_alert) {
        PoleAlertFilter.all => true,
        PoleAlertFilter.blocked => item.alerts.blockedCount > 0,
        PoleAlertFilter.overdue => item.alerts.overdueCount > 0,
        PoleAlertFilter.noNextAction =>
          !item.tasksUnavailable && item.nextAction == null,
        PoleAlertFilter.noLead => !item.membersUnavailable && item.lead == null,
        PoleAlertFilter.noDeputy =>
          !item.membersUnavailable && item.deputy == null,
        PoleAlertFilter.noTeam =>
          !item.membersUnavailable && item.activeMembers.isEmpty,
      };
    }).toList();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _type = 'all';
      _responsible = 'all';
      _alert = PoleAlertFilter.all;
    });
  }

  void _open(PolePortfolioItem item) {
    if (widget.onOpenPole != null) {
      widget.onOpenPole!(item);
      return;
    }
    context.push(
      '/poles/${item.pole.id}',
      extra: PoleDetailRouteData(gateway: _gateway, initialItem: item),
    );
  }

  void _retry() => setState(() => _loading = loadPolesPortfolio(_gateway));
}

Future<List<PolePortfolioItem>> loadPolesPortfolio(
  PolesPortfolioGateway gateway,
) async {
  final poles = await gateway.loadPoles();
  return Future.wait(
    poles.map((pole) async {
      final membersFuture = capturePoleSource(gateway.loadMembers(pole.id));
      final tasksFuture = capturePoleSource(gateway.loadTasks(pole.id));
      final members = await membersFuture;
      final tasks = await tasksFuture;
      PoleNextAction? nextAction;
      if (tasks.value != null) {
        final now = DateTime.now();
        final candidates =
            tasks.value!.where((task) {
              final due = DateTime.tryParse(task.dueDate ?? '');
              return !PoleTaskPresentation.isTerminal(task.status) &&
                  due != null &&
                  due.isAfter(now);
            }).toList()..sort(
              (a, b) => DateTime.parse(
                a.dueDate!,
              ).compareTo(DateTime.parse(b.dueDate!)),
            );
        if (candidates.isNotEmpty) {
          final task = candidates.first;
          final assignees = await capturePoleSource(
            gateway.loadTaskAssignees(task.id),
          );
          nextAction = PoleNextAction(
            task: task,
            assignees: assignees.value ?? const [],
          );
        }
      }
      return PolePortfolioItem(
        pole: pole,
        members: members.value,
        tasks: tasks.value,
        nextAction: nextAction,
        membersUnavailable: members.error != null,
        tasksUnavailable: tasks.error != null,
      );
    }),
  );
}

Future<PoleSourceResult<T>> capturePoleSource<T>(Future<T> future) async {
  try {
    return PoleSourceResult(value: await future);
  } catch (error) {
    return PoleSourceResult(error: error);
  }
}

class PoleSourceResult<T> {
  final T? value;
  final Object? error;
  const PoleSourceResult({this.value, this.error});
}
