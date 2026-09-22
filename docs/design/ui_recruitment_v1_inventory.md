# EnactSpace — Inventaire UI/UX Recrutement v1

## 1. Objet et périmètre

Ce document constitue l'inventaire préalable à la phase 2D de refonte UI/UX du module Recrutement. Il décrit l'existant sans modifier le comportement applicatif, le backend, les données ou les fixtures.

- Branche d'audit : `feat/ui-recruitment-v1`
- Commit de départ : `de1f0435a6ea785c3f28f5b644dbafc6daa9159a`
- Date de l'inventaire : 3 août 2026
- Compte de contrôle : `ui_audit`
- Fichiers structurants et dépendances directes inspectés : 23
- Endpoints Recrutement recensés : 20

Le périmètre couvre les parcours candidats publics, les opérations internes, le routage, les permissions frontend et backend, les modèles et contrats API, les états métier, les tests existants et les fixtures accessibles au compte d'audit.

## 2. Fichiers inspectés

### Frontend Recrutement

1. `frontend/lib/features/recruitment/screens/recruitment_screen.dart`
2. `frontend/lib/features/recruitment/screens/application_tracking_screen.dart`
3. `frontend/lib/features/recruitment/services/recruitment_service.dart`
4. `frontend/lib/features/recruitment/models/application_model.dart`
5. `frontend/lib/features/recruitment/models/application_tracking_model.dart`
6. `frontend/lib/features/recruitment/models/recruitment_campaign_model.dart`
7. `frontend/lib/features/recruitment/models/application_review_model.dart`

### Frontend environnant et dépendances directes

8. `frontend/lib/features/auth/screens/login_screen.dart`
9. `frontend/lib/app/app_router.dart`
10. `frontend/lib/core/auth/user_experience.dart`
11. `frontend/test/widget_test.dart`
12. `frontend/lib/core/network/api_client.dart`
13. `frontend/lib/features/auth/services/auth_service.dart`
14. `frontend/lib/features/poles/models/pole_model.dart`
15. `frontend/lib/features/poles/services/poles_service.dart`
16. `frontend/lib/features/projects/models/project_model.dart`
17. `frontend/lib/features/projects/services/projects_service.dart`

### Backend et autorisations

18. `backend/app/api/routes/recruitment.py`
19. `backend/app/models/recruitment.py`
20. `backend/app/schemas/recruitment.py`
21. `backend/app/api/deps.py`
22. `backend/app/core/roles.py`
23. `backend/app/api/routes/academy.py`

Le frontend Recrutement compte sept fichiers dédiés. L'écran interne principal concentre à lui seul près de 3 000 lignes, tandis que le suivi public approche 660 lignes. Cette concentration augmente le coût d'évolution et le risque de régression.

## 3. Routes et points d'entrée

| Route frontend | Accès | Point d'entrée | Surface |
|---|---|---|---|
| `/application-tracking` | Public | Bouton « Suivre ma candidature » sur la connexion et succès de candidature | Recherche par code de suivi et e-mail |
| `/recruitment` | Authentifié et autorisé | Navigation interne | Campagnes, candidatures, filtres et actions |

La connexion expose également une action « Postuler ». Elle ouvre d'abord une boîte de dialogue d'accès, charge les campagnes publiques, puis réutilise le même `CreateApplicationDialog` que l'espace interne. Il n'existe pas de route publique dédiée à la découverte d'une campagne ou à un formulaire progressif.

Si aucune campagne n'est retournée, ou si leur chargement échoue, le frontend bascule vers une feuille de demande d'adhésion avec le message « Aucune campagne active... ». Cette convergence masque la différence entre une absence réelle de campagne et une panne réseau ou serveur.

## 4. Parcours candidat public actuel

### 4.1 Dépôt d'une candidature

1. Le candidat ouvre la page de connexion.
2. Il choisit « Postuler ».
3. Une boîte de dialogue intermédiaire est affichée.
4. Le frontend appelle la liste des campagnes publiques.
5. Une campagne est sélectionnée dans un long formulaire modal.
6. Le candidat saisit identité, études, motivations, disponibilité et liens vers les pièces.
7. Une seule action finale « Créer » soumet toute la candidature.
8. Un dialogue non fermable affiche le code de suivi et permet d'ouvrir `/application-tracking`.

Le formulaire est un `AlertDialog` plafonné à 620 px. Il adapte certaines rangées sous 560 px, mais demeure un formulaire monolithique, sans étapes, sommaire, sauvegarde, progression, retour explicite sur les champs incomplets ni relecture avant envoi. Le libellé « Créer » est orienté administration plutôt que candidat.

Les justificatifs sont trois chaînes URL facultatives (`cv_url`, `motivation_letter_url`, `attachment_url`). Aucun téléversement, aperçu, contrôle de type ou de taille, ni retour de progression n'est intégré.

### 4.2 Suivi d'une candidature

Le candidat renseigne son code de suivi et son e-mail. La validation locale exige un code d'au moins huit caractères et vérifie sommairement la présence de `@` et d'un point dans l'e-mail. La page utilise deux colonnes à partir de 900 px et une pile en dessous, avec une largeur maximale de 1 120 px.

Le résultat présente quatre étapes visuelles : réception, étude, entretien et décision. Les états finaux négatifs ou d'attente sont regroupés dans la dernière étape. La vue ne permet ni correction, ni ajout de document, ni réponse à une demande, ni prise de rendez-vous.

## 5. Parcours interne actuel

L'écran interne charge d'abord les campagnes, puis les candidatures, de manière séquentielle. Un indicateur global remplace l'écran pendant le chargement.

Les filtres disponibles sont : recherche, campagne, statut, genre, pôle, projet, département, classe et mode anonyme. Sous 760 px, tous les contrôles occupent la largeur disponible ; au-dessus, ils utilisent des largeurs fixes. La recherche doit être soumise manuellement, alors que la plupart des listes relancent immédiatement un chargement complet. Il n'existe pas d'action claire pour réinitialiser tous les filtres, de compteur de résultats ou de panneau compact sur mobile.

Les candidatures sont affichées sous forme de cartes dans une grille : trois colonnes à partir de 1 200 px, deux à partir de 780 px, une en dessous. Chaque carte montre notamment l'identité ou un code anonymisé, l'e-mail, la campagne, plusieurs attributs, le statut, une progression et un score de présélection calculé localement. Seules les quatre premières lignes de motivation sont visibles.

Actions présentes sur une carte :

- changement immédiat du statut par liste déroulante ;
- évaluation ;
- planification d'entretien ;
- création ou réactivation d'un compte pour une candidature acceptée.

Il n'existe pas de fiche candidat complète donnant accès à toutes les réponses, aux documents, à l'historique des évaluations et décisions, ni à une chronologie. Les états `accepted`, `rejected` et `cancelled` peuvent être appliqués directement, sans confirmation ni motif. Le backend n'impose pas de matrice de transition.

La création d'une campagne est disponible, mais pas son édition, son ouverture ou sa fermeture explicite, ni sa suppression, alors que le backend fournit ces opérations. L'export CSV copie le contenu complet dans le presse-papiers au lieu de produire un téléchargement. Aucune pagination n'est prévue : toutes les candidatures retournées sont construites en cartes.

La conversion en utilisateur charge les pôles et projets, crée ou réactive le compte, affecte rôles et adhésions, fixe un mot de passe initial, puis tente un onboarding Academy non bloquant. L'action sensible ne comporte pas de seconde confirmation explicite.

## 6. Contrats API Recrutement

Le backend expose 20 endpoints. « Accès Recrutement » désigne la dépendance d'autorisation détaillée en section 7.

| # | Méthode et route | Accès | Contrat et effet principal | Utilisation frontend actuelle |
|---:|---|---|---|---|
| 1 | `POST /api/recruitment/campaigns` | Recrutement | Crée une campagne | Oui |
| 2 | `GET /api/recruitment/campaigns` | Recrutement | Liste, filtre facultatif `is_active` | Oui |
| 3 | `GET /api/recruitment/campaigns/public` | Public | Campagnes réellement ouvertes selon activation et dates | Oui |
| 4 | `GET /api/recruitment/campaigns/{id}` | Recrutement | Détail d'une campagne | Non |
| 5 | `PATCH /api/recruitment/campaigns/{id}` | Recrutement | Modifie métadonnées, dates et activation | Non |
| 6 | `DELETE /api/recruitment/campaigns/{id}` | Recrutement | Supprime la campagne et ses candidatures en cascade | Non |
| 7 | `POST /api/recruitment/applications` | Public | Soumet une candidature | Oui |
| 8 | `POST /api/recruitment/applications/track` | Public | Recherche par référence et e-mail | Oui |
| 9 | `GET /api/recruitment/applications` | Recrutement | Liste filtrable, sans pagination | Oui |
| 10 | `GET /api/recruitment/applications/export.csv` | Recrutement | Exporte toutes les candidatures, sans filtres | Oui, vers presse-papiers |
| 11 | `GET /api/recruitment/applications/{id}` | Recrutement | Détail complet | Non |
| 12 | `POST /api/recruitment/applications/{id}/interview` | Recrutement | Planifie l'entretien et force son statut | Oui |
| 13 | `PATCH /api/recruitment/applications/{id}` | Recrutement | Modifie les champs et le statut | Non |
| 14 | `POST /api/recruitment/applications/{id}/status` | Recrutement | Applique tout statut valide | Oui |
| 15 | `DELETE /api/recruitment/applications/{id}` | Recrutement | Supprime une candidature | Non |
| 16 | `POST /api/recruitment/reviews` | Recrutement | Crée ou remplace l'évaluation du relecteur courant | Oui |
| 17 | `GET /api/recruitment/applications/{id}/reviews` | Recrutement | Liste les évaluations | Non |
| 18 | `PATCH /api/recruitment/reviews/{id}` | Auteur ou admin/TL | Modifie une évaluation | Non |
| 19 | `DELETE /api/recruitment/reviews/{id}` | Auteur ou admin/TL | Supprime une évaluation | Non |
| 20 | `POST /api/recruitment/applications/{id}/convert-to-user` | SG, TL ou admin | Crée/réactive utilisateur, rôle, adhésions et notification | Oui |

Filtres de la liste interne : `campaign_id`, `status_filter`, `search`, `preferred_pole`, `project_interest`, `department`, `class_name`, `gender`, `submitted_from`, `submitted_to` et `anonymized`. Aucun couple `page`/`limit`, curseur ou total n'est défini.

Erreurs métier principales : campagne ou candidature introuvable (`404`), campagne fermée, dates ou états invalides, score/recommandation invalides, mot de passe trop court ou conversion d'une candidature non acceptée (`400`), doublon d'e-mail dans une campagne (`409`), autorisation ou propriété d'une évaluation insuffisante (`403`). La génération impossible d'un code de suivi aboutit à une erreur serveur.

## 7. Rôles et permissions

### 7.1 Frontend

`canViewRecruitment` autorise l'administrateur, le team leader, le secrétaire général, le responsable Recrutement et tout profil considéré comme `Enacchef`. Cette dernière catégorie inclut aussi le financier, le faculty advisor et les responsables ou adjoints de pôles et projets.

Les alias techniques Recrutement reconnus sont : `pole_veille`, `veille`, `chef_pole_veille`, `adjoint_pole_veille`, `recrutement` et `recruiter`. Le membre simple et l'alumni n'ont pas accès à la route interne.

### 7.2 Backend

L'accès Recrutement comprend neuf rôles Enacchef — administrateur, team leader, secrétaire général, financier, chef et adjoint de pôle, chef et adjoint de projet, faculty advisor — auxquels s'ajoutent les six alias Recrutement, soit 15 rôles techniques distincts. Une adhésion active à un pôle nommé exactement `veille` donne également accès. L'utilisateur doit être actif et validé.

| Capacité | Public | Membre / alumni | Accès Recrutement | SG / TL / admin |
|---|---:|---:|---:|---:|
| Voir les campagnes ouvertes | Oui | Oui | Oui | Oui |
| Déposer et suivre sa candidature | Oui | Oui | Oui | Oui |
| Lire les campagnes et candidatures internes | Non | Non | Oui | Oui |
| Créer/modifier/supprimer campagnes et candidatures | Non | Non | Oui | Oui |
| Changer une décision ou planifier un entretien | Non | Non | Oui | Oui |
| Créer/lire des évaluations | Non | Non | Oui | Oui |
| Modifier/supprimer l'évaluation d'autrui | Non | Non | Non | Oui, avec règles d'auteur/admin/TL |
| Convertir une candidature en compte | Non | Non | Non | Oui |

Contrôle runtime en lecture avec les profils d'audit : administrateur, secrétaire, team leader, financier et chef de pôle ont reçu `200` sur les campagnes internes ; membre et alumni ont reçu `403`.

Le périmètre d'écriture est très large : un financier ou un responsable de n'importe quel pôle/projet peut techniquement créer ou supprimer des campagnes, supprimer une candidature ou décider de son statut. L'intention métier de cette règle doit être confirmée avant la refonte.

## 8. États métier et transitions

### 8.1 Campagnes

Il n'existe pas d'énumération persistée. L'état effectif résulte de `is_active`, `start_date` et `end_date` : planifiée, ouverte, expirée/fermée ou inactive. L'interface n'expose qu'une case « Campagne active », sans libellé métier ni garde contre des dates incohérentes côté fixture.

### 8.2 Candidatures

| État canonique | Libellé interne | Libellé public / effet |
|---|---|---|
| `submitted` | Reçue | Candidature reçue |
| `under_review` | En étude | Étude en cours |
| `interview_scheduled` | Entretien programmé | Étape entretien |
| `accepted` | Acceptée | Décision favorable |
| `rejected` | Rejetée | Non retenue |
| `waiting_list` | Liste d'attente | Décision en attente |
| `cancelled` | Clôturée | Parcours clôturé |

Le backend accepte aussi trois alias historiques et les normalise : `received` vers `submitted`, `preselected` vers `under_review`, `interview` vers `interview_scheduled`. La constante de validation contient donc dix valeurs techniques. Toute valeur inconnue risque d'être affichée brute par le frontend.

La liste interne propose les sept états canoniques et autorise actuellement n'importe quel passage direct entre eux. Aucun état initial obligatoire, aucune transition conditionnelle, aucun motif de rejet/annulation et aucune confirmation ne sont imposés. La planification d'un entretien force `interview_scheduled`.

### 8.3 Évaluation et décision

Une évaluation contient un score facultatif de 0 à 20, un commentaire et une recommandation parmi `favorable`, `reserve` et `defavorable`. Le score final est la moyenne des évaluations. La décision n'est pas un objet séparé : elle est encodée dans le statut de candidature.

En parallèle, l'interface calcule un `screeningScore` heuristique de 0 à 100 côté client, avec des appréciations telles que priorité élevée, bon potentiel, à creuser ou dossier incomplet. Ce second score n'est ni persistant ni produit par le backend et peut être confondu avec l'évaluation officielle sur 20.

## 9. Données et fixtures `ui_audit`

L'inspection a été effectuée en lecture seule, sans seed ni mutation.

### Campagnes

Quatre campagnes existent :

- une campagne inactive du 16 mai au 25 juin 2026 ;
- une campagne marquée active du 26 mai au 15 juin 2026, donc expirée ;
- une campagne inactive le 5 juin 2026 ;
- une campagne inactive avec début au 15 juin et fin au 26 mai 2026, donc dates inversées.

Au 3 août 2026, l'endpoint public retourne zéro campagne ouverte.

### Candidatures et évaluations

- 30 candidatures en base ;
- statuts : 8 `accepted`, 7 `received`, 8 `rejected`, 7 `reviewing` ;
- 30 codes de suivi ;
- 0 CV, lettre de motivation ou pièce jointe ;
- 0 entretien, 0 utilisateur converti ;
- 12 évaluations sur 12 candidatures ;
- recommandations : 6 `accept`, 6 `reserve` ;
- 24 motivations renseignées ;
- aucun contenu dans les autres réponses longues auditées.

Deux incompatibilités empêchent d'exploiter correctement ces fixtures :

1. `GET /api/recruitment/applications` répond `500`, car les adresses comme `applicant01@example.test` échouent à la validation `EmailStr` du schéma de sortie ; la liste dense ne peut donc pas être affichée.
2. Les fixtures utilisent `reviewing` et `accept`, qui ne font pas partie respectivement des états et recommandations acceptés par le contrat backend. Les suivis publics sont également exposés au rejet du domaine réservé `.test` par la validation d'e-mail.

## 10. Couverture des états de fixture

| État nécessaire à la future validation | Couverture | Observation |
|---|---|---|
| Campagne ouverte | Manquante | Zéro campagne publique à la date d'audit |
| Campagne planifiée | Manquante | Toutes les dates sont passées |
| Campagne fermée ou expirée | Présente | Campagne active mais expirée |
| Liste dense de candidatures | Présente en base, inutilisable | 30 lignes, endpoint en erreur `500` |
| Nouvelle candidature | Partielle | Ancien état `received` |
| Candidature en étude | Manquante | `reviewing` est invalide ; aucun `under_review` |
| Candidature acceptée | Présente | 8 lignes |
| Candidature rejetée | Présente | 8 lignes |
| Liste d'attente | Manquante | Aucun `waiting_list` |
| Candidature annulée | Manquante | Aucun `cancelled` |
| Entretien planifié | Manquante | Aucun entretien |
| Dossier complet | Manquant | Réponses longues et documents absents |
| Pièce jointe visualisable | Manquante | Les trois URL sont vides |
| Évaluations valides multiples | Partielle | `reserve` existe, `accept` est invalide |
| Décision actionnable | Partielle | États présents mais écran bloqué par le `500` |
| Suivi public exploitable | Partielle | Codes présents, e-mails `.test` incompatibles |
| Compte déjà converti | Manquant | Aucune conversion |

## 11. Écarts UX — candidat public

- Pas de page de campagne publique explicative ni de sélection contextualisée.
- Formulaire long dans une modale, sans découpage mobile-first, progression ou relecture.
- Même dialogue et vocabulaire que la création interne ; le verbe « Créer » est inadapté.
- Liens de documents saisis manuellement au lieu d'un téléversement guidé.
- Erreurs techniques susceptibles d'être présentées sous forme d'exception brute.
- Une erreur de chargement est assimilée à l'absence de campagne.
- Le suivi regroupe plusieurs décisions distinctes dans une seule étape et ne donne pas de prochaine action.
- Pas de mécanisme de récupération du code, de correction ou de complément de dossier.
- Peu de sémantique d'accessibilité explicite ; de nombreuses informations reposent sur couleur et badges.

## 12. Écarts UX — équipe interne

- Pas de fiche candidat complète, de documents, d'historique, ni de liste d'évaluations.
- Décisions sensibles instantanées, sans confirmation, motif ou garde de transition.
- Conversion en utilisateur et affectations sensibles sans confirmation finale dédiée.
- Grille de cartes peu adaptée à une liste dense ; aucune pagination ni virtualisation.
- Filtres volumineux sur mobile, sans panneau repliable, remise à zéro ou total.
- Chargement global et séquentiel qui efface le contexte.
- Gestion des campagnes limitée à la création malgré les capacités backend.
- Export CSV copié au presse-papiers, non téléchargé et non aligné sur les filtres.
- Méthode de recrutement et besoins en effectif codés en dur dans l'écran opérationnel.
- Double notation 0–100 locale et 0–20 officielle, sans distinction suffisamment forte.
- Écran principal monolithique, logique métier et présentation très couplées.

## 13. Risques et priorités

### P0 — Bloquants et intégrité

- Les e-mails de fixture rendent la liste interne inaccessible (`500`) et empêchent l'audit runtime du parcours central.
- Aucune campagne publique n'est actuellement ouverte.
- Acceptation, rejet et annulation sont immédiatement mutables, sans confirmation ni transition autorisée.
- La conversion crée ou réactive un compte, initialise un mot de passe et affecte des adhésions sans confirmation forte.
- Les futures opérations de suppression de campagne seraient en cascade et accessibles à un ensemble de rôles très large.

### P1 — Parcours incomplets

- Absence de détail candidat, réponses complètes, documents, évaluations et historique.
- Absence de gestion du cycle de vie des campagnes dans l'interface.
- Absence de pagination et de surface de travail adaptée aux volumes.
- Candidature publique monolithique et pièces jointes limitées à des URL.
- Permissions backend potentiellement excessives pour les décisions et suppressions.
- Absence de matrice de transition métier.

### P2 — Efficacité et compréhension

- Filtres et recherche peu efficaces, notamment sur mobile.
- Méthodologie statique mélangée aux opérations quotidiennes.
- Score heuristique local en concurrence avec la note officielle.
- Export par presse-papiers, erreurs peu contextualisées, absence de chargements locaux.

### P3 — Maintenabilité et qualité perçue

- Mapping des statuts dupliqué entre modèles et écrans.
- Fichiers très volumineux et responsabilités multiples.
- Statut de campagne sans modèle humain explicite.
- Chaînes potentiellement mal encodées dans certains libellés existants.
- Accessibilité sémantique et navigation clavier peu couvertes.

## 14. Proposition de découpage futur

### Surface publique

- page de découverte et détail d'une campagne ouverte ;
- formulaire progressif : identité, parcours, motivations, disponibilité, documents, relecture ;
- écran de succès avec copie et récupération du code ;
- suivi de candidature avec chronologie, explications et prochaine action.

### Surface interne

- vue d'ensemble et gestion du cycle de vie des campagnes ;
- workbench des candidatures sous forme de table ou liste dense, paginée et filtrable ;
- fiche candidat en page ou panneau avec onglets Résumé, Réponses, Documents, Évaluations et Historique ;
- dialogues de décision distincts avec confirmation, motif et règles de transition ;
- éditeur de campagne et actions explicites ouvrir, fermer, archiver ;
- conversion en membre séparée de la décision de recrutement.

### Découpage de code indicatif

Séparer les pages publiques et internes, le workbench, la fiche candidat, les dialogues métier, les composants de filtres, la présentation centralisée des statuts et la logique de permissions. Les modèles et services doivent rester indépendants de la mise en page ; les mutations sensibles doivent être encapsulées et testées.

## 15. Matrice de captures future

| # | Surface | État à montrer | Format conseillé |
|---:|---|---|---|
| 01 | Campagne publique | Campagne ouverte et informations clés | Mobile 390×844 |
| 02 | Candidature publique | Étape identité/études | Mobile 390×844 |
| 03 | Candidature publique | Motivations, disponibilité et progression | Tablette 768×1024 |
| 04 | Relecture publique | Dossier complet et documents | Desktop 1366×768 |
| 05 | Succès public | Code de suivi copiable | Mobile 390×844 |
| 06 | Suivi public | Candidature reçue | Mobile 390×844 |
| 07 | Suivi public | Entretien programmé | Desktop 1366×768 |
| 08 | Suivi public | Décision finale acceptée ou rejetée | Mobile 390×844 |
| 09 | Vue interne | Campagnes et indicateurs | Desktop 1366×768 |
| 10 | Liste interne | Liste dense, filtres et pagination | Desktop 1366×768 |
| 11 | Filtres internes | Panneau mobile ouvert | Mobile 390×844 |
| 12 | Fiche candidat | Réponses, document et évaluations | Desktop 1366×768 |
| 13 | Décision | Confirmation d'acceptation | Desktop 1366×768 |
| 14 | Décision | Rejet avec motif requis | Desktop 1366×768 |
| 15 | Campagne | Édition et cycle ouvert/fermé | Desktop 1366×768 |

Chaque capture devra être adossée à un état de fixture valide, déterministe et sans mutation irréversible pendant la capture.

## 16. Questions à trancher avant conception

1. Quels rôles peuvent réellement lire les dossiers, évaluer, décider, supprimer et convertir un candidat ?
2. Quelle matrice de transitions est autorisée et quelles transitions exigent un motif ou une confirmation renforcée ?
3. Acceptation et création de compte doivent-elles rester deux actions strictement séparées ?
4. Quel stockage, quels formats et quelles limites s'appliquent aux documents candidats ?
5. Quelles règles définissent précisément les états planifiée, ouverte, fermée et archivée d'une campagne ?
6. Le score heuristique 0–100 a-t-il une valeur métier validée, ou doit-il disparaître au profit des évaluations sur 20 ?
7. Quelles règles de conservation, confidentialité, anonymisation et suppression s'appliquent aux données candidates ?
8. Un rejet ou une annulation doit-il être communiqué au candidat, et avec quel niveau de détail ?
9. Le candidat peut-il compléter ou corriger son dossier après soumission ?
10. Quels volumes doivent dimensionner pagination, recherche et export ?

## 17. Baseline technique

Les commandes demandées ont été exécutées depuis `frontend`, sans modifier les dépendances :

| Contrôle | Résultat |
|---|---|
| `flutter analyze --no-pub` | OK — aucune anomalie, 4,5 s |
| `flutter test --no-pub --reporter expanded -j 1 --timeout 45s` | OK — 14 tests réussis |
| `flutter build web --release --pwa-strategy=none` | OK — `build/web` généré, 124,5 s |

La suite contient un test Recrutement ciblé sur le suivi en largeur mobile compacte. Elle ne couvre pas le dépôt public, les filtres internes, les changements de statut, les évaluations, les entretiens, les permissions ou la conversion en compte.

La build signale uniquement l'obsolescence future de l'option `--pwa-strategy` et une note de dry run WebAssembly ; elle se termine avec succès. Les fichiers de registrant plugins dont seuls les retours de ligne avaient été régénérés par la build ont été restaurés, sans toucher au code applicatif.
