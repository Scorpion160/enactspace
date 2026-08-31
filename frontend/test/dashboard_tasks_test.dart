import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/models/dashboard_summary_model.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:frontend/features/dashboard/services/dashboard_gateway.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/features/tasks/models/task_assignee_model.dart';
import 'package:frontend/features/tasks/models/task_center_models.dart';
import 'package:frontend/features/tasks/models/task_model.dart';
import 'package:frontend/features/tasks/screens/task_detail_screen.dart';
import 'package:frontend/features/tasks/screens/tasks_screen.dart';
import 'package:frontend/features/tasks/services/tasks_gateway.dart';
import 'package:frontend/features/tasks/widgets/task_form_dialog.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Dashboard quotidien', () {
    testWidgets('charge summary, priorités réelles et activité récente', (
      tester,
    ) async {
      final gateway = _DashboardMemoryGateway(_summary());
      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(gateway: gateway)),
      );
      await tester.pumpAndSettle();

      expect(gateway.calls, 1);
      expect(find.text('À suivre aujourd’hui'), findsOneWidget);
      expect(find.text('Tâches en retard'), findsOneWidget);
      expect(find.text('Notifications'), findsWidgets);
      expect(find.text('Messages'), findsWidgets);
      expect(find.text('Prochains événements'), findsOneWidget);
      expect(find.text('Rapport publié'), findsOneWidget);
    });

    testWidgets(
      'null reste indisponible et carte métier suit permission + donnée',
      (tester) async {
        final gateway = _DashboardMemoryGateway(
          _summary(finance: true, payments: null),
        );
        await tester.pumpWidget(
          MaterialApp(home: DashboardScreen(gateway: gateway)),
        );
        await tester.pumpAndSettle();

        expect(find.text('—'), findsWidgets);
        expect(find.text('Paiements'), findsNothing);

        gateway.value = _summary(finance: true, payments: 3);
        await tester.tap(find.text('Actualiser'));
        await tester.pumpAndSettle();
        expect(find.text('Paiements'), findsOneWidget);
      },
    );

    testWidgets('affiche chargement puis erreur', (tester) async {
      final completer = Completer<DashboardSummaryModel>();
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            gateway: _PendingDashboardGateway(completer.future),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.completeError(Exception('summary indisponible'));
      await tester.pumpAndSettle();
      expect(find.text('summary indisponible'), findsOneWidget);
    });

    testWidgets('390 px sans overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(gateway: _DashboardMemoryGateway(_summary())),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Centre de tâches', () {
    test(
      'enrichissement assignés démarre en parallèle et isole une erreur',
      () async {
        final started = <String>[];
        final first = Completer<List<TaskAssigneeModel>>();
        final future = loadTaskAssigneesInParallel(
          [
            _task(),
            const TaskModel(
              id: 't2',
              title: 'Deux',
              priority: 'normale',
              status: 'a_faire',
              proofRequired: false,
              canManage: false,
              currentUserAssigned: false,
            ),
          ],
          (taskId) {
            started.add(taskId);
            if (taskId == 't2') return Future.error(Exception('isolée'));
            return first.future;
          },
        );
        await Future<void>.delayed(Duration.zero);
        expect(started, ['t1', 't2']);
        first.complete(const [
          TaskAssigneeModel(id: 'a1', taskId: 't1', userId: 'm1'),
        ]);
        final result = await future;
        expect(result.values['t1'], hasLength(1));
        expect(result.values['t2'], isEmpty);
        expect(result.failures, {'t2'});
      },
    );

    test(
      'statuts/priorités sont humanisés et retard respecte les terminaux',
      () {
        expect(_task(status: 'bloque').statusLabel, 'Bloqué');
        expect(_task(status: 'annule').statusLabel, 'Annulé');
        expect(_task(priority: 'urgente').priorityLabel, 'Urgente');
        final now = DateTime.utc(2026, 8, 31);
        expect(_task(dueDate: '2026-08-30T00:00:00Z').isLateAt(now), isTrue);
        expect(
          _task(
            status: 'termine',
            dueDate: '2026-08-30T00:00:00Z',
          ).isLateAt(now),
          isFalse,
        );
        expect(
          _task(
            status: 'valide',
            dueDate: '2026-08-30T00:00:00Z',
          ).isLateAt(now),
          isFalse,
        );
        expect(
          _task(
            status: 'annule',
            dueDate: '2026-08-30T00:00:00Z',
          ).isLateAt(now),
          isFalse,
        );
      },
    );

    testWidgets('liste, recherche, filtres Bloqué/Annulé et reset', (
      tester,
    ) async {
      final gateway = _TasksMemoryGateway(data: _centerData());
      await tester.pumpWidget(
        MaterialApp(
          home: TasksScreen(
            gateway: gateway,
            clock: () => DateTime.utc(2026, 8, 31),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Préparer atelier'), findsOneWidget);
      expect(find.text('Tâche annulée'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('tasks-search')), 'atelier');
      await tester.pump();
      expect(find.text('Préparer atelier'), findsOneWidget);
      expect(find.text('Tâche annulée'), findsNothing);

      await tester.tap(find.byKey(const Key('tasks-reset')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tasks-status-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulé').last);
      await tester.pumpAndSettle();
      expect(find.text('Tâche annulée'), findsOneWidget);
      expect(find.text('Préparer atelier'), findsNothing);
    });

    testWidgets('vues Mes tâches et En retard sont transmises au gateway', (
      tester,
    ) async {
      final gateway = _TasksMemoryGateway(data: _centerData());
      await tester.pumpWidget(MaterialApp(home: TasksScreen(gateway: gateway)));
      await tester.pumpAndSettle();
      final views = find.byKey(const Key('tasks-views'));
      await tester.tap(
        find.descendant(of: views, matching: find.text('Mes tâches')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: views, matching: find.text('En retard')),
      );
      await tester.pumpAndSettle();
      expect(
        gateway.views,
        containsAllInOrder([
          TaskCenterView.all,
          TaskCenterView.mine,
          TaskCenterView.late,
        ]),
      );
    });

    testWidgets('état vide et mobile 390 px sans overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gateway = _TasksMemoryGateway(
        data: const TaskCenterData(tasks: []),
      );
      await tester.pumpWidget(MaterialApp(home: TasksScreen(gateway: gateway)));
      await tester.pumpAndSettle();
      expect(find.text('Aucune tâche'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('erreur assignés reste locale à une tâche', (tester) async {
      final data = _centerData(assigneeFailure: true);
      await tester.pumpWidget(
        MaterialApp(
          home: TasksScreen(gateway: _TasksMemoryGateway(data: data)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Assignés indisponibles'), findsOneWidget);
      expect(find.text('Tâche annulée'), findsOneWidget);
    });
  });

  group('Fiche et mutations', () {
    testWidgets('URL directe charge la fiche et respecte can_manage', (
      tester,
    ) async {
      final gateway = _TasksMemoryGateway(data: _centerData());
      final router = GoRouter(
        initialLocation: '/tasks/t1',
        routes: [
          GoRoute(
            path: '/tasks/:id',
            builder: (_, state) => TaskDetailScreen(
              taskId: state.pathParameters['id']!,
              gateway: gateway,
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Préparer atelier'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Valider'), findsOneWidget);
      expect(find.text('Historique technique'), findsOneWidget);
    });

    testWidgets('current_user_assigned expose statut/preuve sans édition', (
      tester,
    ) async {
      final gateway = _TasksMemoryGateway(
        data: _centerData(),
        detailTask: _task(canManage: false, assigned: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TaskDetailScreen(taskId: 't1', gateway: gateway),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Changer le statut'), findsOneWidget);
      expect(find.text('Preuve'), findsWidgets);
      expect(find.text('Modifier'), findsNothing);
    });

    testWidgets('création envoie le payload et empêche double submit', (
      tester,
    ) async {
      final gateway = _TasksMemoryGateway(data: _centerData());
      gateway.delayCreate = true;
      await tester.pumpWidget(
        MaterialApp(
          home: _DialogHost(
            dialog: TaskFormDialog.create(
              gateway: gateway,
              data: _centerData(),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('task-title')),
        'Nouvelle tâche',
      );
      await tester.tap(find.byKey(const Key('task-form-submit')));
      await tester.pump();
      expect(gateway.createCalls, 1);
      expect(gateway.created?.title, 'Nouvelle tâche');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('task-form-submit')))
            .onPressed,
        isNull,
      );
      gateway.completeCreate();
      await tester.pumpAndSettle();
      expect(gateway.createCalls, 1);
    });

    testWidgets('édition envoie PATCH logique', (tester) async {
      final gateway = _TasksMemoryGateway(data: _centerData());
      await tester.pumpWidget(
        MaterialApp(
          home: _DialogHost(
            dialog: TaskFormDialog.edit(gateway: gateway, task: _task()),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('task-title')),
        'Titre modifié',
      );
      await tester.tap(find.byKey(const Key('task-form-submit')));
      await tester.pumpAndSettle();
      expect(gateway.updated?.title, 'Titre modifié');
      expect(gateway.updatedTaskId, 't1');
    });
  });
}

DashboardSummaryModel _summary({bool finance = false, int? payments = 2}) =>
    DashboardSummaryModel.fromJson({
      'profile': {
        'id': 'u1',
        'display_name': 'Awa',
        'status': 'active',
        'profile_type': 'enacteur',
        'roles': ['enacteur'],
        'can_view_finance': finance,
      },
      'counts': {
        'notifications_unread': 2,
        'tasks_assigned': 4,
        'tasks_late': 1,
        'tasks_done': 3,
        'messages_unread': 3,
        'events_upcoming': 2,
        'posts_recent': 1,
        'documents_accessible': null,
        'badges_points': 10,
        'badges_count': 1,
        'payments_pending': payments,
      },
      'recent_activity': [
        {
          'type': 'post',
          'title': 'Rapport publié',
          'created_at': '2026-08-30T10:00:00Z',
          'route': '/posts',
        },
      ],
    });

TaskModel _task({
  String status = 'bloque',
  String priority = 'haute',
  String? dueDate = '2026-08-30T00:00:00Z',
  bool canManage = true,
  bool assigned = true,
}) => TaskModel(
  id: 't1',
  title: 'Préparer atelier',
  description: 'Brief équipe',
  priority: priority,
  status: status,
  dueDate: dueDate,
  proofRequired: true,
  createdAt: '2026-08-20T00:00:00Z',
  canManage: canManage,
  currentUserAssigned: assigned,
);

TaskCenterData _centerData({bool assigneeFailure = false}) => TaskCenterData(
  tasks: [
    _task(),
    const TaskModel(
      id: 't2',
      title: 'Tâche annulée',
      priority: 'basse',
      status: 'annule',
      proofRequired: false,
      canManage: false,
      currentUserAssigned: false,
    ),
  ],
  members: const [
    MemberModel(id: 'm1', email: 'awa@example.test', fullName: 'Awa Diop'),
  ],
  assigneesByTaskId: const {
    't1': [TaskAssigneeModel(id: 'a1', taskId: 't1', userId: 'm1')],
  },
  assigneeErrorTaskIds: assigneeFailure ? const {'t1'} : const {},
  canCreate: true,
);

class _DashboardMemoryGateway implements DashboardGateway {
  DashboardSummaryModel value;
  int calls = 0;
  _DashboardMemoryGateway(this.value);
  @override
  Future<DashboardSummaryModel> loadSummary() async {
    calls++;
    return value;
  }
}

class _PendingDashboardGateway implements DashboardGateway {
  final Future<DashboardSummaryModel> value;
  _PendingDashboardGateway(this.value);
  @override
  Future<DashboardSummaryModel> loadSummary() => value;
}

class _TasksMemoryGateway implements TasksGateway {
  final TaskCenterData data;
  final TaskModel? detailTask;
  final List<TaskCenterView> views = [];
  TaskCreateInput? created;
  TaskUpdateInput? updated;
  String? updatedTaskId;
  int createCalls = 0;
  bool delayCreate = false;
  Completer<void>? _createCompleter;
  _TasksMemoryGateway({required this.data, this.detailTask});

  @override
  Future<TaskCenterData> loadCenter(
    TaskCenterView view, {
    bool includeDirectory = true,
  }) async {
    views.add(view);
    return data;
  }

  @override
  Future<TaskDetailData> loadDetail(String taskId) async => TaskDetailData(
    task: detailTask ?? data.tasks.first,
    assignees: data.assigneesByTaskId[taskId] ?? const [],
    members: data.members,
  );
  @override
  Future<List<MemberModel>> membersForPole(String poleId) async => data.members;
  @override
  Future<List<MemberModel>> membersForProject(String projectId) async =>
      data.members;
  @override
  Future<TaskModel> createTask(TaskCreateInput input) async {
    createCalls++;
    created = input;
    if (delayCreate) {
      _createCompleter = Completer<void>();
      await _createCompleter!.future;
    }
    return _task();
  }

  void completeCreate() => _createCompleter?.complete();
  @override
  Future<TaskModel> updateTask(String taskId, TaskUpdateInput input) async {
    updatedTaskId = taskId;
    updated = input;
    return _task();
  }

  @override
  Future<TaskModel> changeStatus(String taskId, String status) async =>
      _task(status: status);
  @override
  Future<TaskModel> submitProof(String taskId, String proofUrl) async =>
      _task();
  @override
  Future<TaskModel> validateTask(String taskId) async =>
      _task(status: 'valide');
  @override
  void invalidate() {}
}

class _DialogHost extends StatelessWidget {
  final Widget dialog;
  const _DialogHost({required this.dialog});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => dialog,
        ),
        child: const Text('Ouvrir'),
      ),
    ),
  );
}
