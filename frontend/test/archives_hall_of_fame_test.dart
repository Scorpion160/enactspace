import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/archives/models/archive_models.dart';
import 'package:frontend/features/archives/models/memory_timeline_models.dart';
import 'package:frontend/features/archives/screens/archive_detail_screens.dart';
import 'package:frontend/features/archives/screens/archives_center_screen.dart';
import 'package:frontend/features/archives/services/archives_api_service.dart';
import 'package:frontend/features/archives/services/archives_gateway.dart';

const persistedId = '123e4567-e89b-12d3-a456-426614174000';
const persistedId2 = '223e4567-e89b-12d3-a456-426614174001';

void main() {
  group('contrat Archives', () {
    test('humanise les statuts, visibilités et types média', () {
      expect(archiveStatusLabel('draft'), 'Brouillon');
      expect(archiveStatusLabel('submitted'), 'Soumis');
      expect(archiveStatusLabel('validated'), 'Validé');
      expect(archiveStatusLabel('rejected'), 'Rejeté');
      expect(archiveStatusLabel('archived'), 'Archivé');
      expect(archiveStatusLabel('hidden'), 'Masqué');
      expect(archiveVisibilityLabel('interne'), 'Membres');
      expect(archiveVisibilityLabel('enacchefs'), 'Responsables');
      expect(archiveVisibilityLabel('privé'), 'Privé');
      expect(historicalMediaTypeLabel('article_presse'), 'Article de presse');
      expect(historicalMediaTypeLabel('lien_video'), 'Lien vidéo');
    });

    test('normalise uniquement les statuts projet confirmés', () {
      expect(historicalProjectStatusLabel('historique'), 'Historique');
      expect(historicalProjectStatusLabel('archive'), 'Archivé');
      expect(historicalProjectStatusLabel('continué'), 'Continué');
      expect(historicalProjectStatusLabel('developpement'), 'En développement');
    });

    test('centralise la distinction slug serveur et UUID DB', () {
      expect(isPersistedArchiveRecord('memoire-serveur'), isFalse);
      expect(isPersistedArchiveRecord(persistedId), isTrue);
    });

    test('ne modélise aucun ancien champ financier ou emploi', () {
      const project = HistoricalProjectModel(
        id: 'memoire',
        name: 'Initiative source',
      );
      expect(project.toString(), isNot(contains('revenue')));
      expect(project.toString(), isNot(contains('profit')));
      expect(project.toString(), isNot(contains('jobs')));
    });

    test('nuance une statistique historique non validée', () {
      const statistic = HistoricalStatisticModel(
        id: 'metric_reference',
        metricKey: 'metric_reference',
        label: 'Portée historique',
        value: 12,
        description:
            'Chiffre historique à confirmer avec les sources disponibles.',
      );
      expect(statistic.confidenceLabel, 'Historique à confirmer');
      expect(statistic.statusLabel, 'Brouillon');
    });

    test('marque une statistique DB validée', () {
      const statistic = HistoricalStatisticModel(
        id: persistedId,
        metricKey: 'metric_reference',
        label: 'Portée historique',
        value: 12,
        status: 'validated',
      );
      expect(statistic.confidenceLabel, 'Historique validé');
      expect(statistic.isPersisted, isTrue);
    });

    test('trie Hall of Fame par ordre puis année', () async {
      final service = _OrderingService();
      final values = await service.getHallOfFame();
      expect(values.map((item) => item.title), [
        'Ordre zéro',
        'Récent',
        'Ancien',
      ]);
    });

    test('parse une page timeline typée avec source et relation', () {
      final page = MemoryTimelinePage.fromJson({
        'items': [
          {
            'id': persistedId,
            'resource_type': 'institutional_event',
            'title': 'Repère parsé',
            'year': 2026,
            'date_precision': 'exact',
            'validation_status': 'VERIFIED',
            'origin': 'operational',
            'captured_at': '2026-09-10T10:30:00Z',
            'source': {
              'id': 'source-1',
              'type': 'document',
              'label': 'PV',
              'capability': {'type': 'document', 'url': '/api/documents/doc-1'},
            },
            'related_entities': [
              {'type': 'project', 'id': 'project-1', 'label': 'Projet source'},
            ],
          },
        ],
        'next_cursor': 'opaque',
      });
      expect(page.nextCursor, 'opaque');
      expect(page.items.single.trustLabel, 'Vérifié');
      expect(page.items.single.originLabel, 'Origine système');
      expect(page.items.single.capturedAt?.toUtc().year, 2026);
      expect(page.items.single.source?.capability?.type, 'document');
      expect(page.items.single.relatedEntities.single.label, 'Projet source');
    });

    test('distingue la capture opérationnelle de la date de création', () {
      final operational = MemoryTimelineItem.fromJson({
        'id': 'event-1',
        'resource_type': 'institutional_event',
        'title': 'Clôture capturée',
        'year': 2026,
        'origin': 'operational',
        'captured_at': '2026-09-10T10:30:00Z',
        'created_at': '2026-09-10T10:31:00Z',
      });
      final manual = MemoryTimelineItem.fromJson({
        'id': 'event-2',
        'resource_type': 'institutional_event',
        'title': 'Repère saisi',
        'year': 2025,
        'created_at': '2025-06-01T08:00:00Z',
      });

      expect(operational.capturedAt?.toUtc().minute, 30);
      expect(operational.createdAt?.toUtc().minute, 31);
      expect(manual.capturedAt, isNull);
      expect(manual.createdAt?.toUtc().year, 2025);
    });

    test('conserve les quatre filtres contextuels dans la requête', () {
      const filters = MemoryTimelineFilters(
        memberId: 'member-1',
        poleId: 'pole-1',
        projectId: 'project-1',
        eventId: 'event-1',
      );
      expect(filters.toQuery()['member_id'], 'member-1');
      expect(filters.toQuery()['pole_id'], 'pole-1');
      expect(filters.toQuery()['project_id'], 'project-1');
      expect(filters.toQuery()['event_id'], 'event-1');
    });
  });

  group('gateway statistiques', () {
    test('POST depuis une valeur backend metric_key', () async {
      final service = _RecordingStatisticsService();
      final gateway = ApiArchivesGateway(service: service);
      const current = HistoricalStatisticModel(
        id: 'portee',
        metricKey: 'portee',
        label: 'Portée',
        value: 8,
      );
      await gateway.saveHistoricalStatistic(current, {'value': 9});
      expect(service.created, 1);
      expect(service.patched, 0);
      expect(service.lastPayload?['metric_key'], 'portee');
    });

    test('PATCH une statistique UUID', () async {
      final service = _RecordingStatisticsService();
      final gateway = ApiArchivesGateway(service: service);
      const current = HistoricalStatisticModel(
        id: persistedId,
        metricKey: 'portee',
        label: 'Portée',
        value: 8,
      );
      await gateway.saveHistoricalStatistic(current, {'value': 10});
      expect(service.created, 0);
      expect(service.patched, 1);
      expect(service.lastId, persistedId);
    });

    test('évite un doublon metric_key déjà persisté', () async {
      final service = _RecordingStatisticsService(
        existing: const [
          HistoricalStatisticModel(
            id: persistedId,
            metricKey: 'portee',
            label: 'Portée',
            value: 8,
          ),
        ],
      );
      final gateway = ApiArchivesGateway(service: service);
      const reference = HistoricalStatisticModel(
        id: 'portee',
        metricKey: 'portee',
        label: 'Portée',
        value: 8,
      );
      await gateway.saveHistoricalStatistic(reference, {'value': 11});
      expect(service.created, 0);
      expect(service.patched, 1);
    });
  });

  group('centre Archives mémoire', () {
    testWidgets('affiche la timeline vérifiée et sa provenance', (
      tester,
    ) async {
      await _pumpCenter(tester, _MemoryArchivesGateway());
      expect(find.text('Mémoire Enactus ESP'), findsOneWidget);
      expect(find.text('Projet opérationnel terminé'), findsOneWidget);
      expect(find.text('Vérifié'), findsOneWidget);
      expect(find.text('Origine système'), findsOneWidget);
      expect(find.textContaining('Source non accessible'), findsOneWidget);
    });

    testWidgets('erreur timeline propose une relance explicite', (
      tester,
    ) async {
      await _pumpCenter(tester, _MemoryArchivesGateway(failHome: true));
      expect(
        find.text('Impossible de charger la mémoire institutionnelle.'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Projet opérationnel terminé'), findsNothing);
    });

    testWidgets('recherche redémarre la requête côté serveur', (tester) async {
      final gateway = _MemoryArchivesGateway();
      await _pumpCenter(tester, gateway);
      await tester.enterText(
        find.byKey(const Key('archives_search')),
        'projet terminé',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(gateway.lastTimelineFilters?.search, 'projet terminé');
      expect(gateway.timelineLoads, 2);
    });

    testWidgets('mode révision et héritage restent réservés au curateur', (
      tester,
    ) async {
      final curator = _MemoryArchivesGateway();
      await _pumpCenter(tester, curator);
      expect(find.byKey(const Key('memory_review_mode')), findsOneWidget);
      expect(find.byKey(const Key('memory_legacy_area')), findsOneWidget);
      expect(curator.homeLoads, 0);
      await tester.tap(find.byKey(const Key('memory_review_mode')));
      await tester.pumpAndSettle();
      expect(curator.lastTimelineFilters?.review, isTrue);
      await tester.tap(find.byKey(const Key('memory_legacy_area')));
      await tester.pumpAndSettle();
      expect(curator.homeLoads, 1);
      expect(find.text('Archives héritées à vérifier'), findsWidgets);

      await _pumpCenter(tester, _MemoryArchivesGateway(canValidate: false));
      expect(find.byKey(const Key('memory_review_mode')), findsNothing);
      expect(find.byKey(const Key('memory_legacy_area')), findsNothing);
    });

    testWidgets('pagination curseur ajoute sans doublon', (tester) async {
      final gateway = _MemoryArchivesGateway(paginated: true);
      await _pumpCenter(tester, gateway);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(gateway.timelineCursors, contains('page-2'));
      expect(find.text('Deuxième repère'), findsOneWidget);
      expect(find.text('Projet opérationnel terminé'), findsOneWidget);
    });

    testWidgets('filtres année et type relancent la première page', (
      tester,
    ) async {
      final gateway = _MemoryArchivesGateway();
      await _pumpCenter(tester, gateway);
      await tester.tap(find.byKey(const Key('memory_filters')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('memory_start_year')),
        '2020',
      );
      await tester.enterText(find.byKey(const Key('memory_end_year')), '2025');
      await tester.tap(find.byKey(const Key('memory_resource_type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Distinction').last);
      await tester.pumpAndSettle();
      tester
          .widget<FilledButton>(find.byKey(const Key('memory_apply_filters')))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(gateway.lastTimelineFilters?.startYear, 2020);
      expect(gateway.lastTimelineFilters?.endYear, 2025);
      expect(gateway.lastTimelineFilters?.resourceType, 'award');
      expect(gateway.timelineCursors.last, isNull);
    });

    testWidgets('état vide filtré et filtre contextuel restent explicites', (
      tester,
    ) async {
      final gateway = _MemoryArchivesGateway(emptyTimeline: true);
      await tester.pumpWidget(
        _app(
          ArchivesScreen(
            gateway: gateway,
            initialFilters: const MemoryTimelineFilters(projectId: 'project-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Aucun repère ne correspond à ces filtres.'),
        findsOneWidget,
      );
      expect(gateway.lastTimelineFilters?.projectId, 'project-1');
    });

    testWidgets('source autorisée et relation supprimée sont distinguées', (
      tester,
    ) async {
      await _pumpCenter(
        tester,
        _MemoryArchivesGateway(
          sourceAvailable: true,
          unavailableRelation: true,
        ),
      );
      expect(find.textContaining('Ouvrir la source'), findsOneWidget);
      expect(find.text('Élément source indisponible'), findsWidgets);
    });

    testWidgets('fichier protégé ne déclenche aucun lancement externe', (
      tester,
    ) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final launchedUrls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'launch') {
              launchedUrls.add(
                (call.arguments as Map<Object?, Object?>)['url']! as String,
              );
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await _pumpCenter(
        tester,
        _MemoryArchivesGateway(
          sourceCapability: const MemorySourceCapability(
            type: 'stored_file',
            url: '/api/files/protected-file/preview',
          ),
        ),
      );
      await tester.tap(find.textContaining('Ouvrir la source'));
      await tester.pumpAndSettle();

      expect(launchedUrls, isEmpty);
      expect(find.text('Source non accessible'), findsOneWidget);
    });

    testWidgets('URL externe autorisée reste lancée sans jeton', (
      tester,
    ) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final launchedUrls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'launch') {
              launchedUrls.add(
                (call.arguments as Map<Object?, Object?>)['url']! as String,
              );
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await _pumpCenter(
        tester,
        _MemoryArchivesGateway(
          sourceCapability: const MemorySourceCapability(
            type: 'external_url',
            url: 'https://example.test/source-publique',
          ),
        ),
      );
      await tester.tap(find.textContaining('Ouvrir la source'));
      await tester.pumpAndSettle();

      expect(launchedUrls, ['https://example.test/source-publique']);
      expect(launchedUrls.single, isNot(contains('?')));
      expect(launchedUrls.single.toLowerCase(), isNot(contains('token')));
      expect(launchedUrls.single.toLowerCase(), isNot(contains('bearer')));
    });

    testWidgets(
      'erreur de page suivante conserve la timeline et permet reprise',
      (tester) async {
        final gateway = _MemoryArchivesGateway(paginated: true, failMore: true);
        await _pumpCenter(tester, gateway);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(find.text('Projet opérationnel terminé'), findsOneWidget);
        expect(find.byKey(const Key('memory_retry_more')), findsOneWidget);
      },
    );

    testWidgets('mobile 390 et texte 200 pour cent restent sans débordement', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
      );
      await _pumpCenter(tester, _MemoryArchivesGateway());
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byTooltip('Effacer la recherche'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('fiches et workflow', () {
    testWidgets('fiche archive affiche source fichier dates et rejet réel', (
      tester,
    ) async {
      final gateway = _MemoryArchivesGateway();
      await tester.pumpWidget(
        _app(ArchiveItemDetailScreen(archiveId: persistedId, gateway: gateway)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rapport sourcé'), findsOneWidget);
      expect(find.text('Ouvrir la source'), findsOneWidget);
      expect(find.textContaining('Télécharger'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Motif du rejet'), 300);
      expect(find.text('Motif du rejet'), findsOneWidget);
      expect(find.text('Source illisible'), findsOneWidget);
      expect(find.text('Supprimer'), findsNothing);
    });

    testWidgets('workflow soumettre une archive brouillon', (tester) async {
      final gateway = _MemoryArchivesGateway(itemStatus: 'draft');
      await tester.pumpWidget(
        _app(ArchiveItemDetailScreen(archiveId: persistedId, gateway: gateway)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Soumettre'), 300);
      await tester.tap(find.text('Soumettre'));
      await tester.pumpAndSettle();
      expect(gateway.lastAction, 'submit');
    });

    testWidgets('workflow valider ou rejeter avec motif obligatoire', (
      tester,
    ) async {
      final gateway = _MemoryArchivesGateway(itemStatus: 'submitted');
      await tester.pumpWidget(
        _app(ArchiveItemDetailScreen(archiveId: persistedId, gateway: gateway)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Valider'), 300);
      expect(find.text('Valider'), findsOneWidget);
      await tester.tap(find.text('Rejeter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rejeter'));
      await tester.pump();
      expect(find.text('Indiquez un motif.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Motif obligatoire'),
        'Source insuffisante',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Rejeter'));
      await tester.pumpAndSettle();
      expect(gateway.lastReason, 'Source insuffisante');
    });

    testWidgets('archivage existe mais aucune suppression', (tester) async {
      final gateway = _MemoryArchivesGateway(itemStatus: 'validated');
      await tester.pumpWidget(
        _app(ArchiveItemDetailScreen(archiveId: persistedId, gateway: gateway)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Archiver'), 300);
      expect(find.text('Archiver'), findsOneWidget);
      expect(find.text('Supprimer'), findsNothing);
    });

    testWidgets('fiche projet est narrative et sans champs inventés', (
      tester,
    ) async {
      final gateway = _MemoryArchivesGateway();
      await tester.pumpWidget(
        _app(
          HistoricalProjectDetailScreen(
            projectId: 'initiative-source',
            gateway: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Récompenses'), 300);
      expect(find.text('Contexte'), findsOneWidget);
      expect(find.text('Le problème'), findsOneWidget);
      expect(find.text('La réponse'), findsOneWidget);
      expect(find.text('Impact et héritage'), findsOneWidget);
      expect(find.text('Équipe'), findsOneWidget);
      expect(find.text('Récompenses'), findsOneWidget);
      expect(find.text('Revenus'), findsNothing);
      expect(find.text('Bénéfices'), findsNothing);
      expect(find.text('Emplois'), findsNothing);
    });
  });

  group('Hall of Fame', () {
    testWidgets('fiche directe résout via liste et masque score absent', (
      tester,
    ) async {
      final gateway = _MemoryArchivesGateway();
      await tester.pumpWidget(
        _app(
          HallOfFameDetailScreen(entryId: 'moment-serveur', gateway: gateway),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.hallListLoads, 1);
      expect(find.text('Moment serveur'), findsOneWidget);
      expect(find.textContaining('92'), findsNothing);
      expect(find.text('Pourquoi il compte'), findsOneWidget);
      expect(find.text('Trace / média'), findsOneWidget);
    });

    testWidgets('fiche sans récit ne génère aucun storytelling', (
      tester,
    ) async {
      final gateway = _MemoryArchivesGateway(emptyHallStory: true);
      await tester.pumpWidget(
        _app(
          HallOfFameDetailScreen(entryId: 'moment-serveur', gateway: gateway),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Le moment'), findsNothing);
      expect(find.text('Pourquoi il compte'), findsNothing);
    });

    testWidgets('URL directe absente donne un état introuvable propre', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          HallOfFameDetailScreen(
            entryId: 'absent',
            gateway: _MemoryArchivesGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Cette entrée du Hall of Fame est introuvable.'),
        findsOneWidget,
      );
    });

    testWidgets('mobile 390 garde priorité titre année récit', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          HallOfFameDetailScreen(
            entryId: persistedId2,
            gateway: _MemoryArchivesGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Moment documenté'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFFFFC20A),
  ),
  home: Scaffold(body: child),
);

Future<void> _pumpCenter(WidgetTester tester, ArchivesGateway gateway) async {
  await tester.pumpWidget(
    _app(ArchivesScreen(key: UniqueKey(), gateway: gateway)),
  );
  await tester.pumpAndSettle();
}

class _MemoryArchivesGateway implements ArchivesGateway {
  final bool failHome;
  final bool canValidate;
  final String itemStatus;
  final bool emptyHallStory;
  final bool paginated;
  final bool failMore;
  final bool emptyTimeline;
  final bool sourceAvailable;
  final MemorySourceCapability? sourceCapability;
  final bool unavailableRelation;
  int createItemCalls = 0;
  int hallListLoads = 0;
  int homeLoads = 0;
  int timelineLoads = 0;
  String? lastAction;
  String? lastReason;
  Map<String, dynamic>? lastPayload;
  MemoryTimelineFilters? lastTimelineFilters;
  final List<String?> timelineCursors = [];

  _MemoryArchivesGateway({
    this.failHome = false,
    this.canValidate = true,
    this.itemStatus = 'rejected',
    this.emptyHallStory = false,
    this.paginated = false,
    this.failMore = false,
    this.emptyTimeline = false,
    this.sourceAvailable = false,
    this.sourceCapability,
    this.unavailableRelation = false,
  });

  MemoryTimelineItem get timelineItem => MemoryTimelineItem(
    id: persistedId,
    resourceType: 'event',
    title: 'Projet opérationnel terminé',
    summary: 'Repère capturé depuis le cycle de vie du projet.',
    year: 2025,
    datePrecision: 'day',
    validationStatus: 'VERIFIED',
    origin: 'operational',
    source: MemorySourceProvenance(
      id: 'source-1',
      type: 'document',
      label: 'Compte rendu privé',
      capability:
          sourceCapability ??
          (sourceAvailable
              ? const MemorySourceCapability(
                  type: 'document',
                  url: '/api/documents/doc-1',
                )
              : null),
    ),
    relatedEntities: unavailableRelation
        ? const [
            MemoryRelatedEntity(
              type: 'project',
              id: 'removed-project',
              label: 'Élément source indisponible',
              available: false,
            ),
          ]
        : const [],
  );

  ArchivePermissions get permissions => ArchivePermissions(
    canCreate: true,
    canValidate: canValidate,
    canExport: canValidate,
  );

  ArchiveItemModel get dbItem => ArchiveItemModel(
    id: persistedId,
    title: 'Rapport sourcé',
    category: 'Rapport annuel',
    year: 2025,
    description: 'Synthèse issue des sources disponibles.',
    status: itemStatus,
    visibility: 'interne',
    sourceLabel: 'Ouvrir la source',
    sourceUrl: 'https://example.org/source',
    tags: const ['rapport', 'source'],
    rejectionReason: itemStatus == 'rejected' ? 'Source illisible' : null,
    createdAt: DateTime(2025, 2, 1),
    updatedAt: DateTime(2025, 2, 2),
    file: const ArchiveFileModel(
      id: 'file-1',
      name: 'rapport.pdf',
      downloadUrl: 'https://example.org/rapport.pdf',
      previewUrl: 'https://example.org/preview',
    ),
  );

  ArchiveItemModel get staticItem => const ArchiveItemModel(
    id: 'temoignage-serveur',
    title: 'Témoignage vérifié',
    category: 'Témoignage',
    year: 2020,
    status: 'validated',
    visibility: 'alumni',
  );

  HistoricalProjectModel get project => const HistoricalProjectModel(
    id: 'initiative-source',
    name: 'Initiative source',
    year: 2019,
    seasonLabel: '2019–2020',
    description: 'Contexte documenté par le serveur.',
    problem: 'Problème décrit dans la source.',
    solution: 'Réponse effectivement mise en œuvre.',
    impactSummary: 'Impact formulé dans les données.',
    keyMembers: ['Membre source'],
    awards: ['Distinction source'],
    documentIds: ['doc-1'],
    mediaFileIds: ['media-1'],
  );

  List<HallOfFameEntryModel> get hall => [
    HallOfFameEntryModel(
      id: 'moment-serveur',
      title: 'Moment serveur',
      subtitle: emptyHallStory ? null : 'Une étape documentée',
      entryType: 'Héritage',
      year: 2018,
      description: emptyHallStory ? null : 'Le récit disponible côté serveur.',
      orderIndex: 0,
      externalUrl: 'https://example.org/trace',
    ),
    const HallOfFameEntryModel(
      id: persistedId2,
      title: 'Moment documenté',
      subtitle: 'Finale nationale',
      entryType: 'Compétition',
      year: 2024,
      description: 'Un résultat confirmé par la source.',
      scoreValue: 92,
      scoreLabel: 'points',
      orderIndex: 1,
      isFeatured: true,
    ),
  ];

  ArchivesHomeData get home => ArchivesHomeData(
    permissions: permissions,
    statistics: const [
      HistoricalStatisticModel(
        id: 'portee',
        metricKey: 'portee',
        label: 'Portée historique',
        value: 120,
        description:
            'Chiffre historique à confirmer avec les sources disponibles.',
      ),
      HistoricalStatisticModel(
        id: persistedId,
        metricKey: 'projets_valides',
        label: 'Projets documentés',
        value: 4,
        status: 'validated',
      ),
    ],
    projects: [
      project,
      const HistoricalProjectModel(
        id: persistedId,
        name: 'Projet DB',
        year: 2023,
      ),
    ],
    awards: const [
      ArchiveAwardModel(
        id: 'prix-serveur',
        title: 'Distinction serveur',
        year: 2022,
        competition: 'Finale',
        rank: 'Premier',
        result: 'Lauréat',
      ),
      ArchiveAwardModel(id: persistedId, title: 'Distinction DB', year: 2024),
    ],
    competitions: const [
      ArchiveCompetitionModel(
        id: 'challenge-serveur',
        name: 'Challenge documenté',
        year: 2022,
        stage: 'Finale',
        result: 'Lauréat',
      ),
    ],
    media: const [
      ArchiveMediaModel(
        id: 'presse-serveur',
        title: 'Article historique',
        mediaType: 'article_presse',
        year: 2021,
        externalUrl: 'https://example.org/article',
      ),
    ],
    documents: const [
      ArchiveDocumentModel(
        id: 'document-serveur',
        title: 'Dossier source',
        documentType: 'Document officiel',
        year: 2021,
        file: ArchiveFileModel(
          id: 'file-doc',
          name: 'dossier.pdf',
          downloadUrl: 'https://example.org/dossier.pdf',
        ),
      ),
    ],
    hallOfFame: hall,
  );

  @override
  Future<ArchivesHomeData> loadHome() async {
    homeLoads++;
    if (failHome) throw Exception('API indisponible');
    return home;
  }

  @override
  Future<MemoryTimelinePage> getTimeline({
    MemoryTimelineFilters filters = const MemoryTimelineFilters(),
    String? cursor,
    int limit = 25,
  }) async {
    timelineLoads++;
    timelineCursors.add(cursor);
    lastTimelineFilters = filters;
    if (failHome) throw Exception('API indisponible');
    if (paginated && cursor == 'page-2') {
      if (failMore) throw Exception('Page suivante indisponible');
      return const MemoryTimelinePage(
        items: [
          MemoryTimelineItem(
            id: persistedId2,
            resourceType: 'milestone',
            title: 'Deuxième repère',
            year: 2024,
            datePrecision: 'year',
            validationStatus: 'VERIFIED',
            origin: 'manual',
          ),
        ],
      );
    }
    if (emptyTimeline) return const MemoryTimelinePage(items: []);
    return MemoryTimelinePage(
      items: [timelineItem],
      nextCursor: paginated ? 'page-2' : null,
    );
  }

  @override
  Future<MemoryTimelineItem> getTimelineDetail(
    String resourceType,
    String id, {
    bool review = false,
  }) async => timelineItem;

  @override
  Future<ArchivePermissions> getPermissions() async => permissions;
  @override
  Future<List<ArchiveItemModel>> getItems({
    String? search,
    String? category,
    int? year,
    String? status,
    String? visibility,
  }) async => [dbItem, staticItem];
  @override
  Future<ArchiveItemModel> getItem(String id) async => dbItem;
  @override
  Future<ArchiveItemModel> createItem(Map<String, dynamic> payload) async {
    createItemCalls++;
    lastPayload = payload;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return dbItem;
  }

  @override
  Future<ArchiveItemModel> updateItem(
    String id,
    Map<String, dynamic> payload,
  ) async {
    lastPayload = payload;
    return dbItem;
  }

  @override
  Future<ArchiveItemModel> submitItem(String id) async {
    lastAction = 'submit';
    return dbItem;
  }

  @override
  Future<ArchiveItemModel> validateItem(String id) async {
    lastAction = 'validate';
    return dbItem;
  }

  @override
  Future<ArchiveItemModel> rejectItem(String id, String reason) async {
    lastAction = 'reject';
    lastReason = reason;
    return dbItem;
  }

  @override
  Future<ArchiveItemModel> archiveItem(String id) async {
    lastAction = 'archive';
    return dbItem;
  }

  @override
  Future<String> exportItemsCsv() async => 'id,title\n$persistedId,Rapport';
  @override
  Future<List<HistoricalProjectModel>> getHistoricalProjects({
    String? search,
    int? year,
    String? status,
  }) async => home.projects;
  @override
  Future<HistoricalProjectModel> getHistoricalProject(String id) async =>
      project;
  @override
  Future<List<ArchiveAwardModel>> getAwards() async => home.awards;
  @override
  Future<List<ArchiveCompetitionModel>> getCompetitions() async =>
      home.competitions;
  @override
  Future<List<ArchiveMediaModel>> getMedia({
    String? search,
    int? year,
    String? mediaType,
    String? projectId,
  }) async => home.media;
  @override
  Future<List<ArchiveDocumentModel>> getDocuments() async => home.documents;
  @override
  Future<List<HallOfFameEntryModel>> getHallOfFame({
    bool refresh = false,
  }) async {
    hallListLoads++;
    return hall;
  }

  @override
  Future<HallOfFameEntryModel?> getHallOfFameEntry(String id) async {
    final values = await getHallOfFame();
    for (final item in values) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<HistoricalStatisticModel>> getHistoricalStatistics() async =>
      home.statistics;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingStatisticsService extends ArchivesService {
  final List<HistoricalStatisticModel> existing;
  int created = 0;
  int patched = 0;
  String? lastId;
  Map<String, dynamic>? lastPayload;

  _RecordingStatisticsService({this.existing = const []});

  @override
  Future<List<HistoricalStatisticModel>> getHistoricalStatistics() async =>
      existing;

  @override
  Future<HistoricalStatisticModel> createHistoricalStatistic(
    Map<String, dynamic> payload,
  ) async {
    created++;
    lastPayload = payload;
    return HistoricalStatisticModel(
      id: persistedId,
      metricKey: '${payload['metric_key']}',
      label: 'Portée',
      value: payload['value'] as num,
    );
  }

  @override
  Future<HistoricalStatisticModel> updateHistoricalStatistic(
    String id,
    Map<String, dynamic> payload,
  ) async {
    patched++;
    lastId = id;
    lastPayload = payload;
    return HistoricalStatisticModel(
      id: id,
      metricKey: 'portee',
      label: 'Portée',
      value: payload['value'] as num,
    );
  }
}

class _OrderingService extends ArchivesService {
  @override
  Future<List<HallOfFameEntryModel>> getHallOfFame() async {
    final values = <HallOfFameEntryModel>[
      const HallOfFameEntryModel(
        id: 'old',
        title: 'Ancien',
        entryType: 'Moment',
        year: 2018,
        orderIndex: 2,
      ),
      const HallOfFameEntryModel(
        id: 'recent',
        title: 'Récent',
        entryType: 'Moment',
        year: 2024,
        orderIndex: 1,
      ),
      const HallOfFameEntryModel(
        id: 'zero',
        title: 'Ordre zéro',
        entryType: 'Moment',
        year: 2020,
        orderIndex: 0,
      ),
    ];
    values.sort((a, b) {
      final order = a.orderIndex.compareTo(b.orderIndex);
      return order != 0 ? order : (b.year ?? 0).compareTo(a.year ?? 0);
    });
    return values;
  }
}
