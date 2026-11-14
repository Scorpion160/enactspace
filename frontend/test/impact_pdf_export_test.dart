import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/impact/models/impact_models.dart';
import 'package:frontend/features/impact/screens/impact_dashboard_screen.dart';
import 'package:frontend/features/impact/services/impact_gateway.dart';

void main() {
  testWidgets('le tableau Impact expose le rapport PDF officiel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImpactDashboardScreen(gateway: _ImpactErrorGateway()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('impact-download-summary-pdf')),
      findsOneWidget,
    );
    expect(find.text('Télécharger la synthèse PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ImpactErrorGateway implements ImpactGateway {
  @override
  Future<ImpactDashboardData> loadDashboard() =>
      Future.error(Exception('Impact indisponible'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
