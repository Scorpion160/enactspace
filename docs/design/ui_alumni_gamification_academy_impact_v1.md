# UI Alumni, Gamification, Academy et Impact v1

## Architecture

Les quatre domaines utilisent désormais des gateways injectables. Les widgets ne construisent plus une constellation de services réseau : `AlumniGateway` agrège profils, mentorats et références utiles ; `GamificationGateway` charge en parallèle points, badges, classements et références ; `AcademyGateway` transporte l’expérience membre et l’administration ; `ImpactGateway` sépare dashboard, fiches, indicateurs et preuves.

Les implémentations API restent les seules à connaître `ApiClient`, `AuthService` et les services de référence. Les tests injectent exclusivement des fakes mémoire et n’émettent aucune requête réseau.

## Alumni et mentorat

L’annuaire conserve recherche et filtre mentors. La route `/alumni/:profileId` présente photo, nom, promotion, entreprise, poste, domaine, compétences, expérience, disponibilité, visibilité et actions humaines LinkedIn/Portfolio. Le propriétaire ou un responsable cohérent peut proposer une édition complète ou une suppression confirmée ; le backend reste l’autorité finale.

Le transport couvre création, lecture, mise à jour et suppression des profils. Les visibilités sont humanisées en Membres, Alumni, Responsables et Privé.

Le mentorat accepte exactement un projet ou un pôle et expose mentor, cible, titre, objectif, dates et statut. Création, pause, reprise, clôture et suppression confirmée passent par le gateway. Les statuts Actif, En pause, Terminé et Annulé ne laissent apparaître aucune clé technique.

## Gamification

La vue personnelle ne reçoit que les points et badges autorisés par le backend ; la vue manager ajoute attribution de points et gestion des badges. Le payload de point transporte `user_id`, `season_id`, `pole_id`, `project_id`, `source_type`, `source_id`, `points` et `reason`.

Les dix sources sont humanisées. Un identifiant membre/pôle non résolu est remplacé par une valeur neutre et jamais affiché comme nom. Les classements membres/pôles et gagnants mensuels restent fondés sur les réponses serveur.

La gestion discrète des badges couvre création, édition, suppression, attribution, retrait et initialisation des badges par défaut. Les formulaires bloquent les doubles soumissions.

## Academy réelle

L’accueil charge cours, progression et parcours en parallèle via les endpoints confirmés. Une absence de session, une réponse invalide ou une erreur API produit un état d’erreur avec Réessayer. Aucun chemin de production ne remplace l’erreur par `_demoHome`, aucun `Set` ne valide une leçon, aucun compteur local n’accorde des points.

La route `/academy/courses/:courseId` expose catégorie, niveau humanisé, durée, points, caractère obligatoire, rôles cibles, progression et leçons. Commencer et Terminer appellent les endpoints de leçon puis rechargent la progression serveur.

Le quiz est d’abord chargé depuis `/academy/quizzes/{quiz_id}`. Le client collecte seulement les choix et les soumet au backend ; il n’utilise jamais `correct_index` comme vérité. Score, réussite/échec, bonnes réponses lorsqu’elles sont fournies, total, points et numéro de tentative viennent exclusivement de la réponse.

La route `/academy/admin` couvre création/modification de cours, publication, dépublication, archivage, restauration et CRUD des leçons. Les champs confirmés des cours et leçons sont transportés. Le backend contrôle les permissions.

## Impact réel

Le dashboard charge `/impact/summary` et `/impact/projects` sans fallback silencieux. L’indisponibilité API reste visible. Les valeurs absentes ne sont plus complétées par des statistiques de démonstration. Les projets dérivés sont présentés comme indicateurs de suivi ou données à documenter, sans score Flutter supplémentaire.

Les routes `/impact/records` et `/impact/records/:impactRecordId` couvrent création et édition des champs People, Planet et Prosperity, statuts humanisés, validation et rejet avec motif obligatoire. Les actions s’affichent selon `can_manage` et `can_validate`, puis le backend tranche.

Les métriques et preuves sont chargées uniquement à l’ouverture de leur bloc dans une fiche. Création, validation et rejet passent par les endpoints confirmés. Catégories, unités et statuts sont humanisés ; fichier et indicateur liés restent des références serveur existantes, sans faux upload.

## Responsive et accessibilité

Les centres utilisent des cartes empilées sous 700 px et des grilles souples au-dessus. Les fiches, formulaires, classements et workflows utilisent `Wrap`, `ListView` et dialogues scrollables afin d’éviter une table desktop compressée ou un scroll horizontal obligatoire. Les actions importantes utilisent des boutons, menus et icônes avec libellé ou tooltip et des cibles Material tactiles.

## Tests

`frontend/test/alumni_gamification_academy_impact_test.dart` vérifie avec des gateways mémoire les visibilités Alumni, statuts mentorat, annuaire, distinction manager Gamification, sources de points, niveaux/types Academy, erreurs sans données démo, fiche cours, statuts/catégories/unités Impact, permissions et chargement lazy métriques/preuves. Les tests de transport restent isolables par injection de `ApiClient` et aucune mutation réseau réelle n’est exécutée.

## Limite restante

La gestion des questions de quiz n’est pas ajoutée : aucun contrat confirmé pour leur CRUD n’a été fourni. Les cours et leçons sont entièrement gérés, tandis que les questions existantes sont seulement consommées par le quiz membre.

## Validation visuelle finale

Les huit captures finales ont été produites avec un harness Flutter widget temporaire, des gateways mémoire déterministes et le vrai `AppShell` habillé par `AppTheme.lightTheme`. Poppins a été embarquée uniquement pendant la génération ; MaterialIcons a été chargée avec `FontLoader` depuis le SDK Flutter. Le navigateur intégré n’a pas été utilisé et aucune donnée métier n’a été demandée au réseau.

Les scénarios couvrent l’annuaire Alumni desktop, le profil Alumni mobile, la Gamification manager desktop et personnelle mobile, l’accueil Academy membre, la fiche Academy administrateur, le dashboard Impact desktop et la fiche Impact mobile. Les fichiers sont disponibles dans `docs/design/screenshots/ui_alumni_gamification_academy_impact_v1/` :

1. `01_alumni_directory_desktop_1440x900.png`
2. `02_alumni_profile_mobile_390x844.png`
3. `03_gamification_desktop_1440x900.png`
4. `04_gamification_mobile_390x844.png`
5. `05_academy_home_desktop_1440x900.png`
6. `06_academy_course_admin_desktop_1366x768.png`
7. `07_impact_dashboard_desktop_1440x900.png`
8. `08_impact_record_mobile_390x844.png`

Le contrôle visuel confirme le thème EnactSpace, Poppins, les glyphes MaterialIcons, l’absence d’overflow, d’UUID et d’enum brut, ainsi que la palette métier jaune/noir/crème non dominée par le thème Material générique. Les scénarios Academy et Impact proviennent exclusivement des fakes temporaires : aucun ancien fallback applicatif n’a été utilisé et aucune statistique n’est présentée comme serveur. Les qualificatifs « Donnée consolidée », « Indicateur de suivi » et « À documenter » distinguent la nature des valeurs Impact.

Tous les compteurs de mutations réelles sont restés à zéro et aucune mutation applicative n’a été effectuée. La limite Academy reste inchangée : aucun CRUD de questions n’est exposé sans contrat backend confirmé, et tout quiz visible est identifié comme corrigé côté serveur. La trace des marqueurs, contrôles et SHA-256 est consignée dans `capture_state_results.json`. Le harness, sa déclaration de fontes, les fontes temporaires et les artefacts intermédiaires ont été supprimés après génération.
