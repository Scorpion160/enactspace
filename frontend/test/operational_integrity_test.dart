import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/models/application_status_presentation.dart';
import 'package:frontend/features/tasks/models/task_model.dart';

TaskModel task(String status, {required bool manager, bool assigned = true}) {
  return TaskModel(
    id: 'task-1',
    title: 'Operational task',
    priority: 'normale',
    status: status,
    proofRequired: false,
    canManage: manager,
    currentUserAssigned: assigned,
  );
}

void main() {
  group('PR-6.5 task transition truth', () {
    test('assignee sees only allowed progression', () {
      expect(task('a_faire', manager: false).allowedStatusTransitions,
          ['en_cours', 'bloque']);
      expect(task('en_cours', manager: false).allowedStatusTransitions,
          ['bloque', 'termine']);
      expect(task('bloque', manager: false).allowedStatusTransitions,
          ['en_cours', 'termine']);
    });

    test('assignee cannot validate cancel or reopen completed work', () {
      expect(task('termine', manager: false).allowedStatusTransitions, isEmpty);
      expect(task('valide', manager: false).allowedStatusTransitions, isEmpty);
      expect(task('annule', manager: false).allowedStatusTransitions, isEmpty);
    });

    test('manager can cancel nonterminal task', () {
      expect(task('a_faire', manager: true).allowedStatusTransitions,
          contains('annule'));
      expect(task('en_cours', manager: true).allowedStatusTransitions,
          contains('annule'));
      expect(task('bloque', manager: true).allowedStatusTransitions,
          contains('annule'));
    });

    test('manager can validate or return completed task for correction', () {
      expect(task('termine', manager: true).allowedStatusTransitions,
          ['en_cours', 'valide']);
    });

    test('validated and cancelled tasks remain terminal for manager', () {
      expect(task('valide', manager: true).allowedStatusTransitions, isEmpty);
      expect(task('annule', manager: true).allowedStatusTransitions, isEmpty);
    });
  });

  group('PR-6.5 recruitment status aliases', () {
    test('legacy values map to canonical presentation', () {
      expect(ApplicationStatusPresentation.fromStatus('received').status,
          'submitted');
      expect(ApplicationStatusPresentation.fromStatus('preselected').status,
          'under_review');
      expect(ApplicationStatusPresentation.fromStatus('interview').status,
          'interview_scheduled');
    });

    test('terminal recruitment statuses stay canonical', () {
      for (final value in ['accepted', 'rejected', 'cancelled']) {
        expect(ApplicationStatusPresentation.fromStatus(value).status, value);
      }
    });
  });
}
