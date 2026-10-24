# Couverture de la démonstration native

| Rubrique | Écran réutilisé |
| --- | --- |
| Accueil | DashboardScreen et AppShell |
| Alumni | AlumniScreen, AlumniProfileDetailScreen |
| Archives | ArchivesScreen, HistoricalMemoryContents, fiches et collections |
| Projets | ProjectsPortfolioScreen, ProjectDetailScreen |
| Pôles | PolesScreen, PoleDetailScreen |
| Membres | MembersScreen, MemberProfileScreen |
| Academy | AcademyHomeScreen, AcademyPathScreen, AcademyCourseScreen et quiz |
| Discussions | ChatScreen, pièces jointes et éléments partagés existants |
| Vie du club | PostsScreen |
| Événements | EventsScreen, EventDetailScreen |
| EnactMeet | MeetingsScreen, MeetingDetailScreen ; appels désactivés |
| Recrutement | InternalRecruitmentScreen, campagne publique, formulaire et suivi |
| Tâches | TasksScreen, TaskDetailScreen |
| Documents | InstitutionalDocumentsHubScreen, DocumentDetailScreen et lecteur PDF existant |
| Finances | FinanceScreen ; aucun paiement réel |
| Présences | AttendanceScreen ; caméra et NFC désactivés |
| Impact | ImpactDashboardScreen, ImpactRecordsScreen et fiches |
| Veille | VeilleScreen, VeilleRecordScreen |
| Jeux et récompenses | GamificationScreen, GamesScreen ; aucune session réelle |
| Notifications | NotificationsScreen ; lecture locale |
| Profil | MyProfileScreen |
| Paramètres | SettingsScreen, profil académique, années ; dépendances isolées |
| Aide et informations | HelpScreen, HelpGuideScreen, AboutScreen et mentions légales |

Les fonctionnalités et les droits visibles dépendent du vrai modèle UserExperience appliqué au profil fictif. Les routes publiques de production restent strictement bornées à `/demo`, `/demo/enacteur` et `/demo/alumni` pour cette visite. Les liens internes restent dans le routeur de démonstration.

Le contrat local ne relaie aucune demande au serveur. Un chemin inconnu échoue localement. Les fichiers publics viennent d’une liste explicite d’assets et les médias temporaires du chat de la mémoire de visite. Le contrôle des profils Enacteur/Alumni parse 156 modèles de production et vérifie l’absence de partage de données entre visites.

Les suites de widgets complètent ces contrôles : vrais types d’écrans pour les 23 rubriques, chargement sans API, formulaires de recrutement, URL du navigateur conservée, sortie sans déconnexion réelle et maintien des parcours existants. La validation Flutter finale doit être faite sur Windows avant le build 1.0.19+22.
