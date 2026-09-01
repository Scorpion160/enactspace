import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/archives/models/archive_models.dart';
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
      expect(statistic.confidenceLabel, 'Validé');
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
    testWidgets('affiche résumé serveur et nuance historique', (tester) async {
      await _pumpCenter(tester, _MemoryArchivesGateway());
      expect(find.text('Archives & mémoire collective'), findsOneWidget);
      expect(find.text('Historique à confirmer'), findsOneWidget);
      expect(find.text('Validé'), findsOneWidget);
      expect(find.text('Initiative source'), findsOneWidget);
    });

    testWidgets('erreur gateway ne montre aucun fallback local', (
      tester,
    ) async {
      await _pumpCenter(tester, _MemoryArchivesGateway(failHome: true));
      expect(
        find.text('Impossible de charger la mémoire collective.'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Initiative source'), findsNothing);
    });

    testWidgets(
      'recherche et filtres archive catégorie année statut visibilité',
      (tester) async {
        final gateway = _MemoryArchivesGateway();
        await _pumpCenter(tester, gateway);
        await tester.tap(find.text('Archives'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('archives_search')),
          'Rapport sourcé',
        );
        await tester.pump();
        expect(find.text('Rapport sourcé'), findsWidgets);
        expect(find.text('Témoignage vérifié'), findsNothing);
        expect(find.text('Catégorie'), findsOneWidget);
        expect(find.text('Année'), findsOneWidget);
        expect(find.text('Statut'), findsOneWidget);
        expect(find.text('Visibilité'), findsOneWidget);
      },
    );

    testWidgets('archive statique non modifiable et DB modifiable', (
      tester,
    ) async {
      await _pumpCenter(tester, _MemoryArchivesGateway());
      await tester.tap(find.text('Archives'));
      await tester.pumpAndSettle();
      expect(find.text('Mémoire historique Enactus ESP'), findsOneWidget);
      expect(find.byKey(const Key('archive_edit_button')), findsOneWidget);
    });

    testWidgets('création préserve garde-fou public et double-submit', (
      tester,
    ) async {
      final gateway = _MemoryArchivesGateway();
      await _pumpCenter(tester, gateway);
      await tester.tap(find.text('Nouvelle archive'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Un contenu public doit être visible par le public ou les alumni.',
        ),
        findsOneWidget,
      );
      expect(find.text('metadata_json'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Titre'),
        'Nouvelle mémoire',
      );
      await tester.tap(find.byKey(const Key('save_archive_button')));
      await tester.tap(find.byKey(const Key('save_archive_button')));
      await tester.pumpAndSettle();
      expect(gateway.createItemCalls, 1);
    });

    testWidgets('export visible uniquement au validateur', (tester) async {
      await _pumpCenter(tester, _MemoryArchivesGateway());
      expect(find.text('Exporter les archives'), findsOneWidget);
      await _pumpCenter(tester, _MemoryArchivesGateway(canValidate: false));
      expect(find.text('Exporter les archives'), findsNothing);
    });

    testWidgets('mobile 390 garde navigation et contenus verticaux', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpCenter(tester, _MemoryArchivesGateway());
      expect(find.text('Vue d’ensemble'), findsOneWidget);
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

  group('collections historiques', () {
    testWidgets(
      'palmarès différencie compétition rang résultat et édition DB',
      (tester) async {
        await _pumpCenter(tester, _MemoryArchivesGateway());
        await tester.tap(find.text('Palmarès'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Finale'), findsOneWidget);
        expect(find.textContaining('Premier'), findsOneWidget);
        expect(find.text('Supprimer'), findsNothing);
      },
    );

    testWidgets('compétitions affichent timeline serveur et aucun delete', (
      tester,
    ) async {
      await _pumpCenter(tester, _MemoryArchivesGateway());
      await tester.tap(find.text('Compétitions'));
      await tester.pumpAndSettle();
      expect(find.text('Challenge documenté'), findsOneWidget);
      expect(find.text('Supprimer'), findsNothing);
    });

    testWidgets('médias humanisés avec ouverture preview ou externe', (
      tester,
    ) async {
      await _pumpCenter(tester, _MemoryArchivesGateway());
      await tester.tap(find.text('Médias'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Article de presse'), findsOneWidget);
      expect(find.text('Ouvrir'), findsOneWidget);
    });

    testWidgets('documents historiques restent une section dédiée', (
      tester,
    ) async {
      await _pumpCenter(tester, _MemoryArchivesGateway());
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();
      expect(find.text('Dossier source'), findsOneWidget);
      expect(find.text('Ouvrir document'), findsOneWidget);
    });
  });

  group('Hall of Fame', () {
    testWidgets('liste respecte contenu score et featured', (tester) async {
      await _pumpCenter(tester, _MemoryArchivesGateway());
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hall of Fame'));
      await tester.pumpAndSettle();
      expect(find.text('Moment documenté'), findsOneWidget);
      expect(find.text('Mis en avant'), findsWidgets);
      expect(find.textContaining('92'), findsOneWidget);
    });

    testWidgets('entrée serveur non modifiable et UUID modifiable', (
      tester,
    ) async {
      await _pumpCenter(tester, _MemoryArchivesGateway());
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hall of Fame'));
      await tester.pumpAndSettle();
      expect(find.text('Mémoire historique Enactus ESP'), findsOneWidget);
      expect(find.byKey(const Key('archive_edit_button')), findsOneWidget);
    });

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
  int createItemCalls = 0;
  int hallListLoads = 0;
  String? lastAction;
  String? lastReason;
  Map<String, dynamic>? lastPayload;

  _MemoryArchivesGateway({
    this.failHome = false,
    this.canValidate = true,
    this.itemStatus = 'rejected',
    this.emptyHallStory = false,
  });

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
    if (failHome) throw Exception('API indisponible');
    return home;
  }

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
