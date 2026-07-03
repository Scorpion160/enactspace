import '../models/archive_models.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../documents/models/document_model.dart';
import '../../documents/services/documents_service.dart';

class ArchivesService {
  final ApiClient _apiClient;
  final AuthService _authService;
  final DocumentsService _documentsService;

  ArchivesService({
    ApiClient? apiClient,
    AuthService? authService,
    DocumentsService? documentsService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _authService = authService ?? AuthService(),
       _documentsService = documentsService ?? DocumentsService();

  Future<ArchivesHomeData> getArchives() async {
    await Future<void>.delayed(const Duration(milliseconds: 240));

    final officialDocuments = await _loadOfficialDocuments();
    final apiHallOfFame = await _loadHallOfFame();

    return ArchivesHomeData(
      summary: ArchiveImpactSummaryModel(
        createdProjects: 9,
        developingProjects: 4,
        developedProducts: 18,
        touchedSdgs: 13,
        createdJobs: 227,
        savedLives: 206,
        plantedTrees: 1425,
        cumulativeUsdGains: 46236.7,
        cumulativeFcfaGains: 27468761,
        impactedLives: 15900,
      ),
      projects: [
        ArchiveProjectModel(
          id: 'dimbali',
          name: 'DIMBALI',
          summary:
              'Projet lancé à Ngayène Sabakh pour combattre la malnutrition et renforcer durablement les revenus des femmes.',
          launchYear: 2016,
          archiveYear: 2020,
          locality: 'Ngayène Sabakh, Sénégal',
          target: 'Enfants, femmes transformatrices et familles rurales',
          problem:
              'Un taux de malnutrition de 15,78 %, de faibles revenus et d’importantes pertes post-récolte.',
          solution:
              'Farine infantile fortifiée, séchage solaire et structuration du GIE FAVEC autour de produits locaux.',
          actions: [
            'Création et accompagnement du GIE FAVEC',
            'Production de farine infantile fortifiée',
            'Déploiement d’un séchoir solaire de 20 kg par cycle de 72 h',
            'Suivi nutritionnel et développement commercial',
          ],
          sdgs: ['ODD 2', 'ODD 8', 'ODD 13'],
          products: ['Farine infantile fortifiée', 'Produits locaux séchés'],
          revenue: 8600000,
          profit: 2100000,
          jobs: 112,
          impactedLives: 4200,
          savedLives: 72,
          plantedTrees: 620,
          partners: [
            'GIE FAVEC',
            'Comité National de Lutte contre la Malnutrition',
            'Communauté de Ngayène Sabakh',
          ],
          awards: [
            'Champion National 2017',
            'World Cup Enactus aux États-Unis en 2018',
          ],
          documents: [
            'Présentation Enactus ESP 2020',
            'Document officiel du projet Dimbali',
            'Rapports impact',
          ],
          members: ['Équipe projet Dimbali', 'Alumni Enactus ESP'],
          lessons: [
            'Mesurer tôt les preuves terrain',
            'Former les relais locaux',
            'Relier impact social et viabilité économique',
            'Concevoir avec les bénéficiaires pour assurer la continuité',
          ],
          logoAsset: 'assets/img/logo_dimbali.png',
          status: 'archivé',
          expansionReady: true,
        ),
        ArchiveProjectModel(
          id: 'deconaane',
          name: 'DECONAANE',
          summary:
              'Projet lié à l’eau sûre, au moringa, à la prévention sanitaire et aux revenus.',
          launchYear: 2016,
          archiveYear: 2020,
          locality: 'Sénégal',
          target: 'Familles et communautés exposées aux risques sanitaires',
          problem: 'Accès insuffisant à une eau sûre et prévention limitée.',
          solution:
              'Approche communautaire combinant traitement, sensibilisation et valorisation du moringa.',
          actions: [
            'Sensibilisation santé',
            'Production locale',
            'Distribution encadrée',
          ],
          sdgs: ['ODD 3', 'ODD 6', 'ODD 8'],
          products: ['Solutions santé', 'Produits à base de moringa'],
          revenue: 5200000,
          profit: 1200000,
          jobs: 38,
          impactedLives: 3100,
          savedLives: 58,
          plantedTrees: 210,
          partners: ['Relais communautaires', 'Acteurs santé'],
          awards: ['4 prix sur 5 à la compétition Uhodari 2016'],
          documents: ['Présentation Enactus ESP 2020'],
          members: ['Équipe projet Deconaane'],
          lessons: [
            'La confiance locale est centrale',
            'Un bon produit doit être accompagné d’éducation',
          ],
          logoAsset: 'assets/img/logo_deconaane.png',
          status: 'expansion',
          expansionReady: true,
        ),
        ArchiveProjectModel(
          id: 'javelisel',
          name: 'JAVELISEL',
          summary:
              'Projet de santé publique autour de l’eau de javel et de la prévention des maladies.',
          launchYear: 2015,
          archiveYear: 2019,
          locality: 'Sénégal',
          target: 'Ménages et structures communautaires',
          problem: 'Prévention insuffisante de maladies liées à l’hygiène.',
          solution:
              'Production et diffusion de solutions de désinfection accessibles avec sensibilisation.',
          actions: ['Production', 'Sensibilisation', 'Démonstrations terrain'],
          sdgs: ['ODD 3', 'ODD 6'],
          products: ['Eau de javel', 'Kits de sensibilisation'],
          revenue: 3100000,
          profit: 780000,
          jobs: 22,
          impactedLives: 2100,
          savedLives: 46,
          plantedTrees: 0,
          partners: ['Communautés locales'],
          awards: ['Premier Prix d’Excellence Fondation Sonatel'],
          documents: ['Présentation Enactus ESP 2020'],
          members: ['Équipe Javelisel'],
          lessons: [
            'La pédagogie d’usage compte autant que le produit',
            'Le packaging doit rester simple et sûr',
          ],
          logoAsset: 'assets/img/logo_javelisel.png',
          status: 'archivé',
          expansionReady: false,
        ),
        ArchiveProjectModel(
          id: 'mobigel',
          name: 'MOBIGEL',
          summary:
              'Innovation rapide née en contexte Covid-19 autour de l’hygiène mobile.',
          launchYear: 2020,
          archiveYear: 2021,
          locality: 'Campus et espaces publics',
          target: 'Usagers exposés aux risques sanitaires',
          problem:
              'Besoin urgent de solutions d’hygiène accessibles et mobiles pendant la crise sanitaire.',
          solution:
              'Dispositif mobile facilitant l’accès au gel ou à l’hygiène préventive.',
          actions: [
            'Prototype rapide',
            'Tests utilisateurs',
            'Sensibilisation',
          ],
          sdgs: ['ODD 3', 'ODD 9'],
          products: ['Dispositif Mobigel'],
          revenue: 950000,
          profit: 230000,
          jobs: 8,
          impactedLives: 1200,
          savedLives: 30,
          plantedTrees: 0,
          partners: ['ESP', 'Communauté campus'],
          awards: ['Parution presse', 'Passage TV'],
          documents: ['Présentation Enactus ESP 2020'],
          members: ['Équipe Mobigel'],
          lessons: [
            'La vitesse d’exécution peut sauver la pertinence',
            'Tester vite réduit les mauvaises hypothèses',
          ],
          logoAsset: 'assets/img/logo_mobigel.png',
          status: 'terminé',
          expansionReady: true,
        ),
        ArchiveProjectModel(
          id: 'meune-nagn',
          name: 'MEUNE NAGN',
          summary:
              'Projet autour de la chaîne de valeur, de la coopérative et des ressources de Casamance.',
          launchYear: 2018,
          archiveYear: 2020,
          locality: 'Casamance',
          target: 'Producteurs, coopératives et jeunes',
          problem:
              'Chaînes de valeur locales peu structurées et revenus instables.',
          solution:
              'Organisation coopérative, transformation et meilleure commercialisation.',
          actions: ['Diagnostic terrain', 'Structuration', 'Transformation'],
          sdgs: ['ODD 1', 'ODD 8', 'ODD 12'],
          products: ['Produits locaux transformés'],
          revenue: 6400000,
          profit: 1600000,
          jobs: 61,
          impactedLives: 2800,
          savedLives: 0,
          plantedTrees: 320,
          partners: ['Coopératives locales'],
          awards: ['Intervention RFI'],
          documents: ['Présentation Enactus ESP 2020'],
          members: ['Équipe Meune Nagn'],
          lessons: [
            'La gouvernance locale doit être claire',
            'La valeur ajoutée se construit dans la chaîne complète',
          ],
          logoAsset: 'assets/img/logo_men_nan.png',
          status: 'archivé',
          expansionReady: true,
        ),
        ArchiveProjectModel(
          id: 'soukhali',
          name: 'SOUKHALI',
          summary:
              'Valorisation de ressources locales comme le Neem, la mangue et le Madd.',
          launchYear: 2017,
          archiveYear: 2020,
          locality: 'Sénégal',
          target: 'Producteurs et consommateurs locaux',
          problem: 'Ressources locales sous-valorisées et pertes post-récolte.',
          solution:
              'Transformation, branding et création de débouchés commerciaux.',
          actions: ['Recherche produit', 'Transformation', 'Vente pilote'],
          sdgs: ['ODD 8', 'ODD 12'],
          products: ['Neem', 'Mangue transformée', 'Madd transformé'],
          revenue: 4200000,
          profit: 930000,
          jobs: 32,
          impactedLives: 1900,
          savedLives: 0,
          plantedTrees: 185,
          partners: ['Producteurs locaux'],
          awards: ['Deuxième National Compétition Nationale 2016'],
          documents: ['Présentation Enactus ESP 2020'],
          members: ['Équipe Soukhali'],
          lessons: [
            'Le design produit aide la confiance',
            'Les pertes post-récolte sont une opportunité d’impact',
          ],
          status: 'archivé',
          expansionReady: true,
        ),
        ArchiveProjectModel(
          id: 'kong-serve',
          name: 'KONG’SERVE',
          summary:
              'Projet de conservation et transformation pour réduire les pertes et créer de la valeur.',
          launchYear: 2018,
          archiveYear: 2020,
          locality: 'Sénégal',
          target: 'Producteurs et ménages',
          problem:
              'Pertes alimentaires et faible durée de conservation des produits.',
          solution:
              'Méthodes de conservation et produits transformés adaptés au marché local.',
          actions: ['Tests de conservation', 'Prototypage', 'Vente pilote'],
          sdgs: ['ODD 2', 'ODD 12'],
          products: ['Produits conservés', 'Solutions de transformation'],
          revenue: 2500000,
          profit: 540000,
          jobs: 12,
          impactedLives: 900,
          savedLives: 0,
          plantedTrees: 40,
          partners: ['Producteurs locaux'],
          awards: [],
          documents: ['Présentation Enactus ESP 2020'],
          members: ['Équipe Kong’Serve'],
          lessons: [
            'La conservation doit rester accessible',
            'Le marché valide mieux que l’idée seule',
          ],
          logoAsset: 'assets/img/logo_kongserve.png',
          status: 'développement',
          expansionReady: false,
        ),
        ArchiveProjectModel(
          id: 'sukhalii-gokh',
          name: 'SUKHALII GOKH',
          summary:
              'Projet d’amélioration locale centré sur le quartier et la participation communautaire.',
          launchYear: 2019,
          archiveYear: 2020,
          locality: 'Quartiers partenaires',
          target: 'Habitants et jeunes locaux',
          problem:
              'Besoins locaux dispersés et manque de coordination communautaire.',
          solution:
              'Actions de quartier, mobilisation et micro-initiatives structurées.',
          actions: ['Diagnostic participatif', 'Actions locales', 'Suivi'],
          sdgs: ['ODD 11', 'ODD 17'],
          products: ['Actions communautaires'],
          revenue: 520000,
          profit: 90000,
          jobs: 0,
          impactedLives: 700,
          savedLives: 0,
          plantedTrees: 50,
          partners: ['Communautés locales'],
          awards: [],
          documents: ['Présentation Enactus ESP 2020'],
          members: ['Équipe Sukhalii Gokh'],
          lessons: [
            'La participation locale améliore la durabilité',
            'Les petits actes doivent être documentés',
          ],
          logoAsset: 'assets/img/logo_soukhalii_gokh.png',
          status: 'archivé',
          expansionReady: true,
        ),
        ArchiveProjectModel(
          id: 'terrasen-2025',
          name: 'TERRASEN',
          summary:
              'Projet 2025 structuré autour de l’agroécologie, de l’irrigation, de la transformation et de la documentation terrain.',
          launchYear: 2024,
          archiveYear: null,
          locality: 'Yeumbeul, Passy, Khaffe, Ngayène Sabakh et UCAD',
          target:
              'GIE, vendeuses de légumes, communautés agricoles, étudiants et bénéficiaires terrain',
          problem:
              'Production locale fragilisée par l’accès aux outils, la conservation, l’irrigation et la valorisation commerciale.',
          solution:
              'Kits de micro-jardinage, système d’irrigation, prototypes techniques, transformation et suivi d’impact documenté.',
          actions: [
            'Immersions terrain et PV de réunions réguliers',
            'Budgétisation des systèmes d’irrigation et équipements agro/IT',
            'Structuration en pôles Agriculture, Élevage, IT, Communication et Fundraising',
            'Préparation World Cup avec pitch, rapport projet et preuves',
          ],
          sdgs: ['ODD 8', 'ODD 11', 'ODD 12', 'ODD 13', 'ODD 15'],
          products: [
            'Kit de micro-jardinage',
            'Système d’irrigation',
            'Solutions de transformation',
            'Documentation World Cup',
          ],
          revenue: 0,
          profit: 0,
          jobs: 0,
          impactedLives: 500,
          savedLives: 0,
          plantedTrees: 0,
          partners: ['GIE Waar wi', 'GIE de Yeumbeul', 'ESP', 'UCAD'],
          awards: ['Préparation World Cup Thaïlande 2025'],
          documents: [
            'TERRASEN presentation.pdf',
            'Document de Projet/Terrasen (2).pdf',
            'Bilans mensuels/MENSUEL.pdf',
            'Budgets et PV de réunions 2024-2025',
            'Dossier World Cup Thaïlande 2025',
          ],
          members: [
            'Équipe projet Terrasen',
            'Pôles Agriculture, Élevage, IT, Communication, Fundraising',
          ],
          lessons: [
            'Relier très tôt budget, preuve terrain et pitch compétition',
            'Documenter chaque déplacement et chaque prototype',
            'Séparer les sous-pôles projet pour mieux suivre les responsabilités',
          ],
          status: 'développement',
          expansionReady: true,
        ),
        ArchiveProjectModel(
          id: 'aquatus-2025',
          name: 'AQUATUS',
          summary:
              'Projet documenté avec album terrain, fiche projet, recherche, technique, budgets, mockups et partenariats.',
          launchYear: 2025,
          archiveYear: null,
          locality: 'Sénégal',
          target:
              'Communautés concernées par l’accès, l’usage ou la qualité de l’eau',
          problem:
              'Besoin de solutions mieux documentées autour de l’eau, du matériel, du terrain et des coûts réels.',
          solution:
              'Recherche, fiche projet, documents techniques, budgétisation et préparation partenariats/fundraising.',
          actions: [
            'Album terrain et documentation visuelle',
            'Budgétisations AquaTus et visites',
            'Documents de recherche et documents techniques',
            'Mockups, logo et dossier partenariats',
          ],
          sdgs: ['ODD 6', 'ODD 8', 'ODD 12'],
          products: ['Dossier technique', 'Mockups', 'Plan de partenariat'],
          revenue: 0,
          profit: 0,
          jobs: 0,
          impactedLives: 0,
          savedLives: 0,
          plantedTrees: 0,
          partners: ['Partenaires à consolider'],
          awards: [],
          documents: [
            'FICHE DE PROJET AQUATUS',
            'DOCUMENT TECHNIQUE AQUATUS',
            'Budgétisations AQUATUS',
            'Partenariats et fundraising',
          ],
          members: ['Équipe projet Aquatus'],
          lessons: [
            'Lier recherche, technique et budget dans un même dossier projet',
            'Prévoir des preuves visuelles propres dès les premières visites',
          ],
          status: 'développement',
          expansionReady: true,
        ),
        ArchiveProjectModel(
          id: 'shery-2025',
          name: 'SHERY',
          summary:
              'Projet 2025 sur les serviettes hygiéniques réutilisables, avec équipes internes, impact, budget et supports de présentation.',
          launchYear: 2025,
          archiveYear: null,
          locality: 'Sénégal',
          target:
              'Femmes, jeunes filles et communautés ciblées par la précarité menstruelle',
          problem:
              'Accès, coût, tabous et durabilité des protections menstruelles restent des enjeux de santé et dignité.',
          solution:
              'Serviettes hygiéniques réutilisables, sensibilisation, structuration d’équipes et suivi impact.',
          actions: [
            'Structuration en teams Communication, Gestion, Orga, Partenariats et Rédaction',
            'Budgétisation et prévisions financières',
            'Observations terrain et impact projet',
            'Supports de présentation et cartes de visite',
          ],
          sdgs: ['ODD 3', 'ODD 5', 'ODD 8', 'ODD 12'],
          products: [
            'Serviettes hygiéniques réutilisables',
            'Supports de sensibilisation',
          ],
          revenue: 0,
          profit: 0,
          jobs: 0,
          impactedLives: 0,
          savedLives: 0,
          plantedTrees: 0,
          partners: ['Partenaires santé et distribution à consolider'],
          awards: [],
          documents: [
            'Présentation du projet SHERY.pdf',
            'SHERY - Serviettes Hygiéniques Réutilisables.pdf',
            'Prévisions Financières SHERY.xlsx',
            'Impact projet shery.docx',
          ],
          members: [
            'Équipe projet Shery',
            'Teams Communication, Gestion, Orga, Partenariats, Rédaction',
          ],
          lessons: [
            'Rattacher finance, impact et communication au même cycle projet',
            'Conserver les observations terrain comme preuves officielles',
          ],
          status: 'développement',
          expansionReady: true,
        ),
        ArchiveProjectModel(
          id: 'men-nan-2025',
          name: 'MËN NAÑ',
          summary:
              'Projet 2025 autour du moringa, de la noix de cajou, de la planification d’activités et du suivi membres.',
          launchYear: 2025,
          archiveYear: null,
          locality: 'Sénégal',
          target: 'Producteurs, membres projet et communautés locales',
          problem:
              'Valorisation et commercialisation des ressources locales nécessitent une équipe stable et un calendrier clair.',
          solution:
              'Planification d’activités, budget, suivi membres, PV et présentation projet structurée.',
          actions: [
            'Calendrier d’activités',
            'Liste membres et contacts',
            'PV de réunion',
            'Budgétisation et présentation finale',
          ],
          sdgs: ['ODD 2', 'ODD 8', 'ODD 12'],
          products: ['Moringa', 'Noix de cajou', 'Support projet'],
          revenue: 0,
          profit: 0,
          jobs: 0,
          impactedLives: 0,
          savedLives: 0,
          plantedTrees: 0,
          partners: ['Partenaires locaux à consolider'],
          awards: [],
          documents: [
            'Présentation Mën Nañ final - Enactus ESP.pdf',
            'Calendrier des activités',
            'Liste des membres et contacts',
            'PV Mën Nan 11 Mars.pdf',
          ],
          members: ['Équipe projet Mën Nañ'],
          lessons: [
            'Faire suivre les contacts et rôles depuis les profils membres',
            'Transformer les calendriers en tâches et jalons dans l’app',
          ],
          logoAsset: 'assets/img/logo_men_nan.png',
          status: 'développement',
          expansionReady: true,
        ),
      ],
      hallOfFame: apiHallOfFame.isNotEmpty
          ? apiHallOfFame
          : [
              HallOfFameItemModel(
                title: 'Création d’Enactus ESP',
                period: '2015',
                description:
                    'Naissance de l’équipe à l’École Supérieure Polytechnique de Dakar.',
                type: 'Histoire',
              ),
              HallOfFameItemModel(
                title: 'Premier Prix d’Excellence Fondation Sonatel',
                period: 'Historique',
                description:
                    'Reconnaissance de l’excellence et de l’impact terrain.',
                type: 'Prix',
              ),
              HallOfFameItemModel(
                title: 'Deuxième National Compétition Nationale',
                period: '2016',
                description: 'Performance nationale majeure pour Enactus ESP.',
                type: 'Compétition',
                imageAsset: 'assets/img/prix_enactus_national_2016.png',
              ),
              HallOfFameItemModel(
                title: '4 prix sur 5 à la compétition Uhodari',
                period: '2016',
                description: 'Palmarès remarquable sur plusieurs catégories.',
                type: 'Compétition',
                imageAsset: 'assets/img/prix_uhodari_2016.png',
              ),
              HallOfFameItemModel(
                title: 'Champion National',
                period: '2017',
                description:
                    'Titre obtenu après audit des projets et qualification pour la World Cup de Londres.',
                type: 'Titre',
              ),
              HallOfFameItemModel(
                title: 'Participation à la World Cup',
                period: '2018',
                description:
                    'Enactus ESP représente le Sénégal lors de la compétition internationale aux États-Unis.',
                type: 'International',
              ),
              HallOfFameItemModel(
                title: 'Demi-finaliste compétition internationale',
                period: '2018',
                description:
                    'Rayonnement international des projets Enactus ESP.',
                type: 'International',
              ),
              HallOfFameItemModel(
                title: 'Parution presse, passage TV et intervention RFI',
                period: 'Historique',
                description:
                    'Visibilité médiatique et crédibilité publique du club.',
                type: 'Média',
              ),
              HallOfFameItemModel(
                title: 'Retour à la compétition nationale',
                period: '2022',
                description:
                    'Reprise de la compétition après les années de consolidation et la période Covid-19.',
                type: 'Compétition',
              ),
            ],
      officialDocuments: officialDocuments,
    );
  }

  Future<List<HallOfFameItemModel>> _loadHallOfFame() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return const [];

      final response = await _apiClient.get(
        '/archives/hall-of-fame',
        token: token,
      );
      if (response is! Map<String, dynamic>) return const [];
      final items = response['items'];
      if (items is! List) return const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(_hallOfFameFromJson)
          .where((item) => item.title.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  HallOfFameItemModel _hallOfFameFromJson(Map<String, dynamic> json) {
    final year = int.tryParse(json['year']?.toString() ?? '');
    final subtitle = json['subtitle']?.toString();
    final description = json['description']?.toString();
    return HallOfFameItemModel(
      title: json['title']?.toString() ?? '',
      period: year?.toString() ?? 'Historique',
      description: (description != null && description.trim().isNotEmpty)
          ? description
          : (subtitle ?? 'Moment fort Enactus ESP.'),
      type: json['entry_type']?.toString() ?? 'Histoire',
    );
  }

  Future<List<ArchiveOfficialDocumentModel>> _loadOfficialDocuments() async {
    try {
      final documents = await _documentsService.getDocuments(isOfficial: true);
      return documents.map(_officialDocumentFromDocument).toList();
    } catch (_) {
      return const [];
    }
  }

  ArchiveOfficialDocumentModel _officialDocumentFromDocument(
    DocumentModel document,
  ) {
    return ArchiveOfficialDocumentModel(
      id: document.id,
      title: document.title,
      category: document.categoryLabel,
      visibility: document.visibilityLabel,
      fileUrl: document.fileUrl,
      projectId: document.projectId,
      poleId: document.poleId,
      eventId: document.eventId,
      createdAtLabel: document.createdAtLabel,
    );
  }
}
