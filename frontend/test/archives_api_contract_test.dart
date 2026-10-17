import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/features/archives/models/archive_models.dart';
import 'package:frontend/features/archives/screens/archives_center_sections.dart';
import 'package:frontend/features/archives/services/archives_api_service.dart';
import 'package:frontend/features/archives/services/archives_gateway.dart';

class _Authenticated extends AuthService {
  @override
  Future<String?> getToken() async => 'test-token';
}

class _TokenStorage extends AuthStorage {
  @override
  Future<AuthTokens?> readTokenPair() async => null;
}

void main() {
  test(
    'reads the named collection envelopes returned by the Archives API',
    () async {
      final envelopes = <String, Object>{
        'historical-projects': {
          'projects': [
            {'id': 'project', 'name': 'Dimbali'},
          ],
        },
        'awards': {
          'awards': [
            {'id': 'award', 'title': 'Champion national 2023'},
          ],
        },
        'competitions': {
          'competitions': [
            {'id': 'cup', 'name': 'World Cup 2018'},
          ],
        },
        'hall-of-fame': {
          'items': [
            {'id': 'hall', 'title': 'Création Enactus ESP'},
          ],
        },
        'documents': {
          'documents': [
            {'id': 'doc', 'title': 'Rapport annuel'},
          ],
        },
        'media': {
          'media': [
            {'id': 'media', 'title': 'Photo historique'},
          ],
        },
        'statistics': {
          'statistics': [
            {
              'id': 'lives',
              'metric_key': 'lives_impacted',
              'label': 'Vies impactées',
              'value': 150000,
              'minimum': true,
              'status': 'validated',
            },
          ],
        },
      };
      final service = ArchivesService(
        authService: _Authenticated(),
        apiClient: ApiClient(
          authStorage: _TokenStorage(),
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer test-token');
            final response = envelopes[request.url.pathSegments.last];
            expect(response, isNotNull);
            return http.Response(jsonEncode(response), 200);
          }),
        ),
      );
      expect((await service.getHistoricalProjects()).single.name, 'Dimbali');
      expect(
        (await service.getAwards()).single.title,
        'Champion national 2023',
      );
      expect((await service.getCompetitions()).single.name, 'World Cup 2018');
      expect(
        (await service.getHallOfFame()).single.title,
        'Création Enactus ESP',
      );
      expect((await service.getDocuments()).length, 1);
      expect((await service.getMedia()).length, 1);
      final statistic = (await service.getHistoricalStatistics()).single;
      expect(statistic.value, 150000);
      expect(statistic.isMinimum, isTrue);
      expect(statistic.isValidated, isTrue);
    },
  );

  testWidgets(
    'all historical projects, awards and competitions are accessible',
    (tester) async {
      final home = ArchivesHomeData(
        statistics: [
          HistoricalStatisticModel.fromJson({
            'id': 'lives',
            'metric_key': 'lives_impacted',
            'label': 'Vies impactées',
            'value': 150000.0,
            'unit': 'personnes',
            'minimum': true,
            'status': 'validated',
          }),
        ],
        projects: [
          for (var i = 1; i <= 5; i++)
            HistoricalProjectModel(
              id: 'project-$i',
              name: 'Projet historique $i',
            ),
        ],
        awards: const [
          ArchiveAwardModel(id: 'award', title: 'Champion national 2023'),
        ],
        competitions: const [
          ArchiveCompetitionModel(id: 'cup', name: 'Enactus World Cup 2018'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HistoricalMemoryContents(
                home: home,
                gateway: ApiArchivesGateway(),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Plus de 150 000 personnes'), findsOneWidget);
      expect(find.text('150000.0 personnes'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Projets'));
      await tester.pump();
      expect(find.text('Projet historique 5'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Palmarès'));
      await tester.pump();
      expect(find.text('Champion national 2023'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Compétitions'));
      await tester.pump();
      expect(find.text('Enactus World Cup 2018'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'summary fallback formats numbers and translates API metric keys',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HistoricalImpactSummaryWrap(
              summary: ArchiveImpactSummaryModel(
                values: {
                  'people_trained': 1597.0,
                  'revenue_usd_2021_2022': 173193.0,
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('1 597'), findsOneWidget);
      expect(find.text('Personnes formées'), findsOneWidget);
      expect(find.text('173 193'), findsOneWidget);
      expect(find.text('Revenus 2021–2022 (USD)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
