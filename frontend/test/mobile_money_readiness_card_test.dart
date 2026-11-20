import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/finance/services/finance_service.dart';
import 'package:frontend/features/finance/widgets/mobile_money_readiness_card.dart';

class FakeReadinessService extends FinanceService {
  FakeReadinessService(this.response);
  final Map<String, dynamic> response;

  @override
  Future<Map<String, dynamic>> getMobileMoneyReadiness() async => response;
}

Widget screen(Map<String, dynamic> data) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(
    child: MobileMoneyReadinessCard(
      financeService: FakeReadinessService(data),
    ),
  )),
);

void main() {
  testWidgets('sandbox does not claim real funds can be charged',
      (tester) async {
    await tester.pumpWidget(screen({
      'configuration_ready': true,
      'ready_for_live_test': false,
      'provider': 'paydunya',
      'mode': 'test',
      'allowed_channels': ['wave-senegal', 'orange-money-senegal'],
      'reconciliation_enabled': true,
      'blocking_checks': [],
    }));
    await tester.tap(find.text('Vérification des paiements en ligne'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pas de débit réel'), findsOneWidget);
    expect(find.textContaining('Mode : test'), findsOneWidget);
  });

  testWidgets('missing configuration renders blockers without secrets',
      (tester) async {
    await tester.pumpWidget(screen({
      'configuration_ready': false,
      'ready_for_live_test': false,
      'provider': 'paydunya',
      'mode': 'live',
      'allowed_channels': [],
      'reconciliation_enabled': false,
      'blocking_checks': ['Clés PayDunya non configurées'],
    }));
    await tester.tap(find.text('Vérification des paiements en ligne'));
    await tester.pumpAndSettle();
    expect(find.text('Clés PayDunya non configurées'), findsOneWidget);
    expect(find.textContaining('paiement réel à ne pas lancer'), findsOneWidget);
    expect(find.textContaining('dummy-token'), findsNothing);
  });
}
