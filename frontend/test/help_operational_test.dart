import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/core/push/push_navigation_resolver.dart';
import 'package:frontend/features/about/services/app_info_provider.dart';
import 'package:frontend/features/help/models/help_models.dart';
import 'package:frontend/features/help/models/managed_help_models.dart';
import 'package:frontend/features/help/screens/help_screen.dart';
import 'package:frontend/features/help/screens/help_management_screen.dart';
import 'package:frontend/features/help/screens/help_guide_screen.dart';
import 'package:frontend/features/help/services/help_gateway.dart';
import 'package:frontend/features/help/widgets/help_guide_panel.dart';

UserExperience user([
  Set<String> roles = const {'enacteur'},
  String status = 'active',
]) => UserExperience(
  id: 'member',
  email: 'member@example.test',
  displayName: 'Synthetic',
  status: status,
  gender: null,
  profileType: status == 'alumni' ? 'alumni' : 'enacteur',
  roles: roles,
  canReviewJoinRequests: false,
);
final stamp = DateTime.utc(2026, 10, 7);
SupportTicket ticket({String status = 'open', String? assigned}) =>
    SupportTicket(
      id: 'ticket',
      subject: 'Accès au cours',
      category: 'technical',
      status: status,
      priority: 'normal',
      updatedAt: stamp,
      userId: 'member',
      requesterName: 'Synthetic Member',
      assignedToId: assigned,
      messages: [
        SupportMessage(
          id: 'initial',
          authorId: 'member',
          message: 'Le quiz ne s’ouvre pas.',
          createdAt: stamp,
        ),
      ],
    );
ProductFeedback feedback({String status = 'new', String? reply}) =>
    ProductFeedback(
      id: 'feedback',
      category: 'idea',
      message: 'Mieux retrouver mes leçons',
      rating: null,
      status: status,
      createdAt: stamp,
      updatedAt: stamp,
      publicReply: reply,
    );

class PendingInfo implements AppInfoProvider {
  final pending = Completer<AppInfo>();
  @override
  Future<AppInfo> load() => pending.future;
}

class Gateway implements HelpGateway, HelpManagementGateway {
  List<SupportTicket> tickets = [];
  List<ProductFeedback> remarks = [];
  List<String?> keys = [];
  bool failSend = false,
      failTicketLoad = false,
      failFeedbackLoad = false,
      stale = false;
  int sends = 0, claims = 0, changes = 0;
  String? publicText, privateText;
  Completer<void>? waiting;
  @override
  Future<List<SupportTicket>> loadTickets() async {
    if (failTicketLoad) throw Exception('network');
    return tickets;
  }

  @override
  Future<SupportTicket> loadTicket(String id) async => tickets.first;
  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String message,
    String? clientRequestId,
  }) async {
    sends++;
    keys.add(clientRequestId);
    if (waiting != null) await waiting!.future;
    if (failSend) throw Exception('network');
    final value = SupportTicket(
      id: 'new',
      subject: subject,
      category: category,
      status: 'open',
      priority: priority,
      updatedAt: stamp,
    );
    tickets = [value, ...tickets];
    return value;
  }

  @override
  Future<SupportMessage> replyToTicket(
    String id,
    String message, {
    String? clientRequestId,
  }) async {
    final reply = SupportMessage(
      id: 'reply',
      authorId: 'member',
      message: message,
      createdAt: stamp,
    );
    tickets = [
      tickets.first.withMessages([...tickets.first.messages, reply]),
    ];
    return reply;
  }

  @override
  Future<List<ProductFeedback>> loadFeedback() async {
    if (failFeedbackLoad) throw Exception('network');
    return remarks;
  }

  @override
  Future<ProductFeedback> createFeedback({
    required String category,
    required String message,
    int? rating,
    String? platform,
    String? appVersion,
    int? buildNumber,
    String? clientRequestId,
  }) async {
    sends++;
    keys.add(clientRequestId);
    if (failSend) throw Exception('network');
    final value = ProductFeedback(
      id: 'new-feedback',
      category: category,
      message: message,
      rating: rating,
      status: 'new',
      createdAt: stamp,
    );
    remarks = [value, ...remarks];
    return value;
  }

  @override
  Future<List<SupportTicket>> loadManagedTickets() => loadTickets();
  @override
  Future<SupportTicket> loadManagedTicket(String id) => loadTicket(id);
  @override
  Future<SupportTicket> manageTicket(
    String id, {
    String? status,
    String? priority,
    String? assignedToId,
    bool updateAssignment = false,
    required DateTime expectedUpdatedAt,
  }) async {
    if (stale) {
      throw ApiException(
        statusCode: 409,
        message: 'Cette demande a changé. Actualisez-la.',
      );
    }
    expect(expectedUpdatedAt, stamp);
    changes++;
    if (updateAssignment) {
      claims++;
      tickets = [ticket(status: tickets.first.status, assigned: assignedToId)];
    } else {
      tickets = [
        ticket(
          status: status ?? tickets.first.status,
          assigned: tickets.first.assignedToId,
        ),
      ];
    }
    return tickets.first;
  }

  @override
  Future<SupportMessage> replyAsManager(
    String id,
    String message, {
    String? clientRequestId,
  }) => replyToTicket(id, message, clientRequestId: clientRequestId);
  @override
  Future<List<ManagedFeedback>> loadManagedFeedback() async {
    final rows = await loadFeedback();
    return rows
        .map(
          (v) => ManagedFeedback(feedback: v, adminNote: 'Diagnostic réservé'),
        )
        .toList();
  }

  @override
  Future<ManagedFeedback> loadManagedFeedbackItem(String id) async =>
      ManagedFeedback(feedback: remarks.first, adminNote: 'Diagnostic réservé');
  @override
  Future<ManagedFeedback> manageFeedback(
    String id, {
    required String status,
    required String publicReply,
    required String adminNote,
    required DateTime expectedUpdatedAt,
  }) async {
    publicText = publicReply;
    privateText = adminNote;
    changes++;
    remarks = [feedback(status: status, reply: publicReply)];
    return ManagedFeedback(feedback: remarks.first, adminNote: adminNote);
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void narrow(WidgetTester tester, {double width = 320}) {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget app(Widget child, {bool dark = false, double scale = 1}) => MaterialApp(
  theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  test('UTC dates and role boundaries agree with server semantics', () {
    expect(
      SupportTicket.fromJson({'updated_at': '2026-10-07T00:00:00'}).updatedAt,
      stamp,
    );
    expect(UserExperience.canAccessPath(user(), '/help/manage'), isFalse);
    expect(
      UserExperience.canAccessPath(
        user({'secretaire_generale'}),
        '/help/manage',
      ),
      isTrue,
    );
    expect(
      UserExperience.canAccessPath(
        user({'secretaire_generale'}, 'alumni'),
        '/help/manage',
      ),
      isFalse,
    );
    expect(UserExperience.canAccessPath(user(), '/welcome-help'), isTrue);
  });
  test('support notifications never route to finance', () {
    for (final kind in ['support_ticket', 'product_feedback']) {
      expect(
        PushNavigationResolver.resolve(type: 'support', relatedType: kind),
        '/help',
      );
    }
    for (final kind in [
      'support_ticket_management',
      'product_feedback_management',
    ]) {
      expect(
        PushNavigationResolver.resolve(type: 'support', relatedType: kind),
        '/help/manage',
      );
    }
  });
  test('public guide stays outside the readiness shell', () {
    final source = File('lib/app/app_router.dart').readAsStringSync();
    expect(
      source.indexOf("path: '/help-guide'"),
      lessThan(
        source.indexOf(
          'builder: (context, state, child) => ProductReadinessGate',
        ),
      ),
    );
    expect(helpGuideArticles.length, 7);
    expect(helpQuestions.length, 15);
    expect(
      helpGuideArticles.every((article) => article.body.length > 250),
      isTrue,
    );
  });
  testWidgets(
    'guide searches accents offline and remains readable in narrow dark mode',
    (tester) async {
      narrow(tester);
      await tester.pumpWidget(
        app(const HelpGuideScreen(), dark: true, scale: 2),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('help-search')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('help-guide-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('help-search')), 'biometrie');
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.text('La biométrie remplace-t-elle la première activation ?'),
      );
      expect(
        find.textContaining('Activez d’abord votre accès'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('help-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('help-search')), 'zzzzzz');
      await tester.pumpAndSettle();
      expect(find.textContaining('Aucune réponse trouvée'), findsOneWidget);
    },
  );
  testWidgets(
    'failed ticket preserves text and retry key without claiming success',
    (tester) async {
      final gateway = Gateway()..failSend = true;
      await tester.pumpWidget(app(HelpScreen(gateway: gateway, user: user())));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Nouvelle demande'));
      await tester.enterText(find.byType(TextField).first, 'Accès');
      await tester.enterText(
        find.byType(TextField).last,
        'Mon quiz est bloqué',
      );
      await tap(tester, find.text('Envoyer'));
      expect(find.text('Mon quiz est bloqué'), findsOneWidget);
      expect(find.text('Votre demande a été envoyée.'), findsNothing);
      gateway.failSend = false;
      await tap(tester, find.text('Envoyer'));
      expect(gateway.sends, 2);
      expect(gateway.keys[0], gateway.keys[1]);
      expect(gateway.keys.first, isNotNull);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets('inflight ticket prevents double submit and closing the dialog', (
    tester,
  ) async {
    final gateway = Gateway()..waiting = Completer<void>();
    await tester.pumpWidget(app(HelpScreen(gateway: gateway, user: user())));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Nouvelle demande'));
    await tester.enterText(find.byType(TextField).first, 'Accès');
    await tester.enterText(find.byType(TextField).last, 'Mon quiz est bloqué');
    await tester.tap(find.text('Envoyer'));
    await tester.pump();
    expect(gateway.sends, 1);
    final actions = tester.widgetList<TextButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ),
    );
    expect(actions.every((v) => v.onPressed == null), isTrue);
    gateway.waiting!.complete();
    await tester.pumpAndSettle();
    expect(gateway.sends, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('optional platform metadata cannot block sending feedback', (
    tester,
  ) async {
    final gateway = Gateway();
    final info = PendingInfo();
    await tester.pumpWidget(
      app(HelpScreen(gateway: gateway, user: user(), appInfoProvider: info)),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Donner mon avis'));
    await tester.enterText(
      find.byKey(const Key('feedback-message-field')),
      'Une amélioration utile',
    );
    await tap(tester, find.text('Envoyer'));
    expect(gateway.sends, 1);
    expect(find.byType(AlertDialog), findsNothing);
    info.pending.complete(const AppInfo(version: '1.0.0', buildNumber: '14'));
    await tester.pump();
  });
  testWidgets(
    'member reads public reply while internal staff notes remain absent',
    (tester) async {
      final gateway = Gateway()
        ..remarks = [
          feedback(
            status: 'planned',
            reply: 'Nous prévoyons cette amélioration.',
          ),
        ];
      await tester.pumpWidget(app(HelpScreen(gateway: gateway, user: user())));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Mieux retrouver mes leçons'));
      expect(find.text('Prévu'), findsWidgets);
      expect(find.text('Nous prévoyons cette amélioration.'), findsOneWidget);
      expect(find.text('Diagnostic réservé'), findsNothing);
    },
  );
  testWidgets(
    'manager claims ticket and stale changes cannot simulate a save',
    (tester) async {
      final gateway = Gateway()..tickets = [ticket()];
      await tester.pumpWidget(
        app(HelpManagementScreen(gateway: gateway, currentUserId: 'staff')),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Accès au cours'));
      await tap(tester, find.text('Prendre en charge'));
      expect(gateway.claims, 1);
      expect(gateway.tickets.first.assignedToId, 'staff');
      gateway.stale = true;
      await tap(tester, find.text('Enregistrer le suivi'));
      expect(
        find.text('Cette demande a changé. Actualisez-la.'),
        findsOneWidget,
      );
      expect(gateway.changes, 1);
      gateway.stale = false;
      await tap(tester, find.text('Actualiser la demande'));
      expect(find.text('Cette demande a changé. Actualisez-la.'), findsNothing);
    },
  );
  testWidgets(
    'staff feedback has separate public response and private note at large text',
    (tester) async {
      narrow(tester);
      final gateway = Gateway()..remarks = [feedback()];
      await tester.pumpWidget(
        app(
          HelpManagementScreen(gateway: gateway, currentUserId: 'staff'),
          dark: true,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Avis et suggestions'));
      await tap(tester, find.text('Mieux retrouver mes leçons'));
      await tester.enterText(
        find.byKey(const Key('manager-feedback-public')),
        'Merci pour votre idée.',
      );
      await tester.enterText(
        find.byKey(const Key('manager-feedback-internal')),
        'À discuter en interne.',
      );
      await tap(tester, find.text('Enregistrer le suivi'));
      expect(gateway.publicText, 'Merci pour votre idée.');
      expect(gateway.privateText, 'À discuter en interne.');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'management lists fail independently and search remains functional',
    (tester) async {
      final gateway = Gateway()
        ..failTicketLoad = true
        ..remarks = [feedback()];
      await tester.pumpWidget(
        app(HelpManagementScreen(gateway: gateway, currentUserId: 'staff')),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Avis et suggestions'));
      expect(find.text('Mieux retrouver mes leçons'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'absent');
      await tester.pumpAndSettle();
      expect(find.text('Mieux retrouver mes leçons'), findsNothing);
    },
  );
}
