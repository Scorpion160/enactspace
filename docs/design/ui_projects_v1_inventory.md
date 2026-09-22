# UI Projets v1 — Inventaire fonctionnel, technique et UX

## 1. Périmètre

Cet inventaire couvre la phase 2E avant toute refonte du module Projets. Il
s'appuie sur le commit de départ
`697f56f35c29ccffc4f7bc09dd773388263e2e10`, sur le contrat backend présent
dans le dépôt et sur des lectures non mutatives de `ui_audit` le 23 août 2026.

Le périmètre principal est `/projects`. Les modules membres, tâches, documents,
événements, impact, publications, notifications et pôles ne sont étudiés que
lorsqu'un identifiant projet, une permission ou une navigation les relie
réellement à cette surface. Aucun seed, upsert, backend, fixture ou donnée n'a
été modifié.

## 2. Fichiers inspectés

51 fichiers ont été inspectés, intégralement ou par sections ciblées :

- les 4 fichiers de `frontend/lib/features/projects/` ;
- `frontend/lib/app/app_router.dart` et
  `frontend/lib/core/auth/user_experience.dart` ;
- les modèles, services et écrans de `members`, `poles`, `tasks`, `documents`,
  `events`, `impact` et `posts` ;
- `frontend/lib/features/notifications/models/notification_model.dart` ;
- les routes, modèles et schémas backend de `projects`, `tasks`, `documents`,
  `events`, `impact`, `posts` et `users` ;
- `backend/app/api/deps.py` et `backend/app/core/roles.py`.

Le module Projets contient actuellement :

| Fichier | Lignes |
|---|---:|
| `project_model.dart` | 90 |
| `project_member_model.dart` | 56 |
| `projects_service.dart` | 170 |
| `projects_screen.dart` | 2 565 |

Il n'existe aucun test dédié au module Projets dans `frontend/test`.

## 3. Architecture actuelle

`projects_screen.dart` concentre 31 classes, dont 30 privées, trois appels à
`showModalBottomSheet` et deux sélecteurs de date. Il mélange :

- chargement réseau et récupération de l'utilisateur courant ;
- calcul local des permissions ;
- filtrage et recherche ;
- portefeuille, cartes et fiche détaillée ;
- création, édition, changement de statut et gestion d'équipe ;
- présentation des statuts, calculs de progression et score de préparation ;
- contenu spécifique TERRASEN et navigation vers les autres modules.

Le chargement est séquentiel : projets, annuaire membres, puis `Future.wait`
sur un appel membres par projet, puis utilisateur courant. Avec 8 projets, une
ouverture déclenche 1 appel projets, 1 appel annuaire, 8 appels membres et 1
appel utilisateur. La fiche relance encore l'appel membres du projet. Une
erreur sur un seul appel membres fait échouer tout le portefeuille ; à
l'inverse, les erreurs annuaire et utilisateur sont silencieusement remplacées
par une liste vide ou une permission nulle.

Les services sont instanciés directement dans le State : aucune injection
n'est prévue pour les tests widgets. La liste utilise une grille de cartes à
3/2/1 colonnes. La fiche, l'édition et la création sont trois feuilles modales
longues. Les largeurs fixes ou semi-fixes les plus notables sont 240, 260, 360,
720 et 780 px, une étiquette membre de 220 px et des blocs de détail bornés à
280–360 px.

## 4. Parcours et surfaces

| Besoin métier | Contrat réel | Surface actuelle |
|---|---|---|
| Liste des projets | Oui, liste complète | Grille de cartes, recherche locale et filtre statut |
| Fiche projet | Pas d'endpoint détail dédié | Feuille reconstruite depuis l'objet de liste |
| Chef / adjoint | Positions de membership | Affichés si les valeurs sont exactement reconnues |
| Membres | Lecture, affectation, retrait logique | Gestion directement dans la fiche |
| Statut | Champ texte, 7 valeurs validées à l'édition | Sélecteur immédiat sans confirmation |
| Progression | Aucun champ dans `ProjectRead` | Pourcentage fixe dérivé du statut |
| Objectifs | Texte libre | Bloc de texte et champ d'édition |
| Échéances | Début/fin projet ; échéances dans les tâches | Début/fin seulement dans le pilotage |
| Tâches | Contrat lié par `project_id` | Bouton vers `/tasks`, sans filtre projet |
| Jalons / phases | Aucun modèle ni endpoint | Absents |
| Blocages | Statut `bloque` d'une tâche uniquement | Non agrégés dans Projets |
| Actualités | Posts avec `project_id`/`project_only` | Non affichées dans la fiche |
| Documents | Documents avec `project_id` | Redirection générique vers `/documents` |
| Événements | Événements avec `project_id` | Non affichés dans la fiche |
| Impact | Agrégat `/impact/projects` et records | Texte `expected_impact` seulement ; agrégat ignoré |
| Pôles | Table `project_poles`, utilisée par Impact | Aucun endpoint de gestion ni surface Projets |
| Création | Oui | Feuille modale ; préremplissage TERRASEN codé en dur |
| Édition | Oui | Feuille modale |
| Archivage / suppression | Aucun endpoint Projet | Absents |
| Historique | Audit sur les affectations seulement | « Journal de bord » synthétique, non issu du serveur |

Les puces Équipe, Tâches, Documents, Budget, Photos et Partenaires quittent la
fiche vers une route générale. Elles ne transmettent pas le projet sélectionné.
Le « Journal de bord » concatène les dates du projet et une phrase générique ;
ce n'est pas un historique. Le score « Préparation compétition » additionne le
pourcentage de statut et la complétude de champs ; il n'existe pas dans le
contrat backend.

## 5. Endpoints

### Endpoints effectivement appelés par l'écran

| Méthode et route | Permission backend | Paramètres / réponse | Mutation, erreurs et usage frontend |
|---|---|---|---|
| `GET /api/projects/` | Compte actif validé ou alumni | Aucun filtre, tri serveur par création décroissante, aucune pagination ; `list[ProjectRead]` | Lecture de tout le portefeuille par `getProjects()` |
| `POST /api/projects/` | Administrateur, Team Leader ou SG | `ProjectCreate` ; `ProjectRead` | Crée un projet. Le statut n'est pas contrôlé ici. Erreurs 401/403/422 ou DB |
| `PATCH /api/projects/{id}` | Gestion globale ou chef/adjoint actif du projet | Patch libre des champs de `ProjectUpdate` ; `ProjectRead` | Modifie contenu, dates, budget, saison ou statut. 400 statut invalide, 403, 404. Aucune règle de transition |
| `GET /api/projects/{id}/members` | Compte actif validé ou alumni | Membres actifs uniquement, sans pagination ; `list[ProjectMemberRead]` | Appelé N fois au chargement puis à l'ouverture de la fiche. 404 projet |
| `POST /api/projects/{id}/members` | Gestion globale ou chef/adjoint du projet | `user_id`, `position` ; `ProjectMemberRead` | Crée/réactive/change la position. 400 position ou membre inactif, 403, 404. Journalise et notifie |
| `DELETE /api/projects/{id}/members/{user_id}` | Gestion globale ou chef/adjoint du projet | `ProjectMemberRead` | Retrait logique (`is_active=false`, `left_at`). 403/404. Journalise et notifie |
| `GET /api/users/directory` | Compte actif validé ou alumni | Tous les comptes actifs et alumni ; aucune pagination | Alimente le sélecteur d'affectation. Un alumni est proposé mais sera refusé par l'affectation, qui exige `status=active` |

Il y a donc 7 endpoints réellement sollicités par l'écran, dont 6 sous le
préfixe Projets. Aucun endpoint ne fournit une fiche agrégée, des permissions
par projet, un résumé d'avancement ou un historique.

### Endpoints liés disponibles mais non intégrés

| Route utile | Situation actuelle |
|---|---|
| `GET /api/tasks/project/{project_id}` | Existe ; la fiche ouvre seulement `/tasks` sans contexte |
| `GET /api/documents/` avec `project_id` | Le modèle et le filtre existent ; la fiche ouvre une liste générique |
| `GET /api/events/` | Les réponses portent `project_id` ; aucun événement n'est affiché dans Projets |
| `GET /api/impact/projects` | Fournit progression, tâches, retards, preuves, documents et scores ; non consommé par Projets |
| `GET /api/posts/` avec `project_id` | Les publications projet existent ; aucune activité récente dans la fiche |

Ces cinq endpoints portent le total recensé à 12, mais ne doivent pas être
présentés comme des appels actuels de l'écran.

## 6. Permissions

La source de vérité backend distingue la gestion globale
(`administrateur`, `team_leader`, `secretaire_generale`) et la gestion locale
par membership actif `chef_projet` ou `adjoint_chef_projet`.

| Rôle | Voir tous via API | Accès UI `/projects` | Modifier | Gérer membres | Nommer chef/adjoint | Gérer tâches projet | Supprimer/archiver |
|---|---|---|---|---|---|---|---|
| Administrateur | Oui | Oui | Tous | Tous | Oui | Oui | Non disponible |
| Team Leader | Oui | Oui | Tous | Tous | Oui | Oui | Non disponible |
| Secrétaire générale | Oui | Oui | Tous | Tous | Oui | Oui | Non disponible |
| Chef de projet | Oui, non filtré | Oui | Son projet | Son projet | Non | Son projet | Non disponible |
| Adjoint de projet | Oui, non filtré | Oui | Son projet | Son projet | Non | Son projet | Non disponible |
| Chef de pôle | Oui, non filtré | Oui | Non, sauf autre membership projet | Non | Non | Selon règles Tâches du pôle, pas le projet | Non disponible |
| Adjoint de pôle | Oui, non filtré | Oui | Non, sauf autre membership projet | Non | Non | Selon règles Tâches du pôle, pas le projet | Non disponible |
| Membre simple | Oui via API | Non exposé | Non | Non | Non | Tâches assignées seulement | Non disponible |
| Alumni | Oui via API | Non exposé | Non | Non | Non | Non | Non disponible |

Il n'existe pas de notion « voir uniquement son projet » : l'API de liste
renvoie tout à chaque compte validé. Le frontend masque la route aux membres et
alumni, mais un chef de projet ou de pôle voit tout le portefeuille. Les objets
`ProjectRead` ne contiennent aucun `can_manage`; l'interface recalcule les
droits après avoir téléchargé toutes les memberships. Le backend reste
néanmoins protecteur sur chaque mutation.

Un chef/adjoint de projet peut affecter ou retirer un membre ordinaire. Seule
la gestion globale peut nommer ou retirer un chef/adjoint. La nomination d'un
nouveau responsable démote automatiquement l'ancien titulaire de la même
position, synchronise les rôles globaux, journalise et notifie.

## 7. États métier

### Projet

| Valeur API canonique | Libellé UI | Progression UI | Observations |
|---|---|---:|---|
| `idee` | Idée | 8 % | Valeur par défaut |
| `etude` | Étude | 18 % | Transition libre |
| `prototype` | Prototype | 38 % | Transition libre |
| `test` | Test | 58 % | Transition libre |
| `deploiement` | Déploiement | 78 % | Transition libre |
| `termine` | Terminé | 100 % | L'UI renseigne la date de fin au jour du changement |
| `suspendu` | Suspendu | 28 % | Aucun motif ni propriétaire du blocage |

La progression n'est pas stockée dans `projects` et ne mesure ni tâches ni
jalons. L'endpoint Impact expose une autre progression, actuellement ignorée.
La création accepte n'importe quelle chaîne de statut ; seule l'édition valide
les sept valeurs. Toute valeur inconnue devient « Idée » et 8 % côté frontend.

### Membership projet

- positions : `membre` → Membre projet, `chef_projet` → Chef de projet,
  `adjoint_chef_projet` → Adjoint chef de projet ;
- cycle : actif (`is_active=true`, `left_at=null`) ou retiré
  (`is_active=false`, `left_at` renseigné) ;
- la liste de l'écran ne reçoit que les memberships actifs.

### Tâches et blocages

- statuts canoniques : `a_faire` → À faire, `en_cours` → En cours,
  `bloque` → Bloqué, `termine` → Terminé, `valide` → Validé,
  `annule` → Annulé ;
- priorités : `basse`, `normale`, `haute`, `urgente` ;
- un membre assigné peut avancer entre à faire, en cours, bloqué et terminé ;
  validation et gestion complète suivent les permissions du module Tâches ;
- une preuve peut être obligatoire avant le passage à terminé ;
- aucun champ ne décrit la cause, le responsable ou la résolution du blocage.

Il n'existe aucun état de jalon, phase ou objectif structuré. Au total, 22
valeurs métier principales sont recensées : 7 statuts projet, 3 positions, 2
états de membership, 6 statuts de tâche et 4 priorités.

## 8. Données `ui_audit`

Les lectures ont trouvé 8 projets, 50 tâches, 30 documents et 10 événements.
`GET /api/impact/projects` renvoie 8 agrégats. `GET /api/impact/records` répond
500 dans cet environnement ; cette erreur a seulement été observée.

| Projet | Statut brut | Membres | Tâches | Documents | Événements | Impact |
|---|---|---:|---|---:|---:|---|
| Audit Horizon | `active` | 7 | 7 `a_faire`, toutes en retard | 4 | 2 | 70 %, 120 direct, 350 indirect |
| Audit Rivage | `active` | 5 | 7 `en_cours`, toutes en retard | 4 | 2 | 70 %, 240 direct, 700 indirect |
| Audit Canopée | `suspended` | 3 | 6 `terminee` | 4 | 1 | 40 %, 360 direct, 1 050 indirect |
| Audit Solstice | `completed` | 3 | 6 `bloquee`, toutes en retard | 4 | 1 | 100 %, 480 direct, 1 400 indirect |
| Audit Passage | `active` | 4 | 6 `a_faire`, toutes en retard | 4 | 1 | 70 %, 600 direct, 1 750 indirect |
| Audit Mosaic | `completed` | 4 | 6 `en_cours`, toutes en retard | 4 | 1 | 100 %, 720 direct, 2 100 indirect |
| Audit Dense Budget | `active` | 4 | 6 `terminee` | 3 | 1 | 70 %, 840 direct, 2 450 indirect |
| Audit Sans Impact | `suspended` | 4 | 6 `bloquee`, toutes en retard | 3 | 1 | 40 %, impact attendu et ODD absents |

Toutes les dates de tâche et d'événement sont passées ; aucune prochaine
échéance ni prochain événement ne couvre le cas nominal futur. Aucun projet
n'est sans membre. Les 8 projets ont problème, solution et objectifs ; seul
Audit Sans Impact manque d'impact attendu. Deux projets sont terminés, deux
suspendus et deux contiennent des tâches bloquées.

Les fixtures révèlent trois incompatibilités majeures :

1. les statuts projet sont `active`, `suspended`, `completed`, alors que le
   contrat et l'UI attendent les sept valeurs françaises ;
2. Audit Horizon utilise la position `chef`, non reconnue à la place de
   `chef_projet`; aucun chef ni adjoint n'est donc détecté par l'écran ;
3. les tâches utilisent `terminee` et `bloquee` alors que le contrat attend
   `termine` et `bloque` ; ces valeurs peuvent apparaître brutes et échappent
   aux colonnes/compteurs attendus.

En conséquence, le portefeuille actuel peut afficher tous les projets comme
« Idée » à 8 %, ne trouver aucun responsable et ignorer des tâches terminées ou
bloquées. Un projet `completed` possède par ailleurs six tâches `bloquee`, ce
qui constitue une incohérence métier utile pour une future alerte mais pas un
scénario nominal.

## Décisions après inventaire

- Le contrat des sept statuts français est conservé.
- Les valeurs legacy de l'audit sont normalisées dans `ui_audit` et ne seront
  pas supportées par l'application.
- La progression artificielle dérivée du statut est abandonnée.
- La progression Impact ne sera affichée que comme une donnée sourcée.
- Aucun faux historique, archivage ou suppression ne sera inventé.
- Aucun motif de blocage, propriétaire de résolution ou ETA ne sera inventé en
  l'absence de champs backend.
- Le contenu TERRASEN sera retiré à terme du comportement générique, sans
  nouvelle fixture dédiée.
- La visibilité API actuelle est conservée ; aucune nouvelle sécurité ne sera
  simulée dans le frontend.

### Couverture nécessaire pour la future validation

| Besoin | Couverture actuelle | Fixture manquante ou à corriger |
|---|---|---|
| 7 statuts projet canoniques | Aucune valeur canonique | Un projet fiable par statut ou un jeu simulé injecté |
| Chef et adjoint reconnus | Aucun | `chef_projet` et `adjoint_chef_projet` actifs |
| Projet sans membre | Non | Un projet sans membership |
| Projet incomplet | Partiel | Cas sans description/objectifs et cas sans dates |
| Prochaine échéance/action | Non | Tâche future assignée avec propriétaire |
| Blocage exploitable | Statut seulement | Tâche `bloque` canonique, cause/owner non supportés par le contrat |
| Projet terminé cohérent | Non | Projet `termine` avec tâches `termine`/`valide` |
| Documents | Oui | Conserver pending/validated/rejected |
| Événement futur | Non | Événement futur lié au projet |
| Impact incomplet | Oui | Audit Sans Impact couvre absence d'ODD/impact |
| Erreur, vide, loading | Non runtime | Gateways simulés pour tests widgets |
| Permissions | Comptes disponibles partiellement | Scénarios injectés pour les 9 rôles de la matrice |

## 9. Problèmes UX priorisés

### P0

- statuts projet runtime incompatibles : libellé et progression deviennent faux ;
- positions et statuts de tâches legacy non reconnus : responsables et
  blocages disparaissent ;
- aucune vue opérationnelle des tâches en retard, blocages, prochaine action
  ou responsable de cette action ;
- changement de statut et retrait de membre partent immédiatement sans résumé
  ni confirmation, alors qu'ils modifient dates, rôles et notifications.

### P1

- progression artificielle par statut, distincte de l'agrégat Impact ;
- accès « tout ou rien » : pas de portefeuille scindé entre tous les projets et
  mes projets ;
- permissions recalculées côté client après une chaîne N+1, sans flags serveur ;
- fiche modale surchargée et modules liés ouverts sans filtre projet ;
- aucune injection de service ni tests Projets ;
- erreurs membres masquées dans la fiche et annuaire alumni proposé à une
  opération qui le refusera ;
- aucun historique réel, alors que le journal synthétique peut être pris pour
  une trace métier.

### P2

- cartes très longues et répétitives : problème, solution, impact, budget,
  équipe, deux progressions et date de création avant toute prochaine action ;
- hiérarchie faible entre état, alerte et responsabilité ;
- fiche en feuille modale difficile à partager, retrouver ou lier ;
- création/édition monolithiques sans validation de cohérence début/fin ;
- contenu TERRASEN codé en dur dans un écran générique ;
- absence d'états partiels par sous-section (équipe, tâches, documents, impact).

### P3

- libellés « projet(s) », « actif(s) » et « membre(s) » non pluralisés ;
- jargon « préparation compétition » sans source ni explication ;
- plusieurs icônes et couleurs portent du sens sans texte alternatif dédié ;
- formulations et accents du contenu TERRASEN sont hétérogènes.

## 10. Risques de mutation

| Mutation | Effet réel | Protection actuelle |
|---|---|---|
| Création | Nouveau projet | Permission backend, validation du nom UI ; aucun contrôle backend du statut |
| Édition | Tous champs, y compris saison, budget et dates via API | Permission backend ; aucune confirmation |
| Changement statut | Statut immédiat ; l'UI fixe/efface `ended_at` | Permission backend ; aucune transition ni confirmation |
| Nomination chef/adjoint | Démote l'ancien, synchronise rôle, notifie et audite | Réservée Admin/TL/SG ; aucune confirmation UI |
| Affectation membre | Crée ou réactive une membership, notifie et audite | Manager projet ; aucune vérification préalable visible |
| Retrait membre | Désactive membership, retire éventuellement le rôle, notifie et audite | Règles backend ; clic de suppression sans confirmation |
| Clôture | Pas d'opération dédiée ; assimilée au statut `termine` | Aucune confirmation ni précondition sur les tâches |
| Archivage/suppression projet | Non supportés | Aucun endpoint, donc aucune protection à évaluer |

Les changements de responsable, retraits, clôtures et transitions vers un état
suspendu ou terminé doivent être traités comme sensibles dans la future UI.

## 11. Proposition de découpage

### A. Vue portefeuille

- `ProjectsPortfolioScreen` : orchestration, accès et état global ;
- `ProjectsPortfolioGateway` : liste agrégée et testable ;
- `ProjectPortfolioItem` : présentation centralisée des états ;
- `ProjectPortfolioFilters` : recherche, statut, responsabilité, alertes ;
- `ProjectPortfolioTable` desktop et `ProjectPortfolioCard` mobile ;
- `ProjectAlertSummary` : retard, blocage, données manquantes ;
- `ProjectNextAction` : action, échéance et porteur.

### B. Fiche projet

- route dédiée `/projects/:projectId` plutôt qu'une feuille modale ;
- `ProjectOverview`, `ProjectTeam`, `ProjectObjectives`, `ProjectWork`,
  `ProjectActivity`, `ProjectDocuments`, `ProjectImpact` et `ProjectHistory` ;
- gateways injectables pour projets, tâches, documents, événements, impact et
  posts ;
- dialogues séparés et renforcés pour statut, responsable et retrait ;
- modèles de présentation communs pour statuts, progression, permissions et
  alertes.

Le backend gagnerait à fournir une lecture agrégée par projet : permissions,
chef/adjoint, compteurs de tâches, retards/blocages, prochaine échéance,
documents, événements et impact. Cela évite le N+1 sans déplacer la logique
métier vers Flutter.

## 12. Direction visuelle

La vue portefeuille doit être un outil de pilotage, pas une collection de
cartes narratives. Sur desktop, une liste structurée ou table souple doit
prioriser : projet, état humain, progression sourcée, chef, prochaine échéance,
blocage et prochaine action. Les descriptions, budgets et détails d'impact
restent secondaires.

La fiche doit commencer par une phrase de situation : « où en est le projet,
ce qui bloque, ce qui vient ensuite et qui le porte ». L'équipe, les objectifs,
les tâches/jalons, l'activité, les documents et l'impact suivent en sections
claires. Les alertes utilisent texte, icône et couleur ; aucune couleur seule
ne porte une décision.

## 13. Responsive

- **390×844** : cartes compactes, statut/chef/prochaine action en premier,
  détails repliables, actions sensibles dans un menu explicite ;
- **768×1024** : liste à une colonne enrichie ou master/detail, filtres dans un
  panneau ;
- **1366×768** : portefeuille dense, fiche dédiée ou panneau latéral stable ;
- **1440×900** : même structure avec davantage d'activité et d'impact visibles.

La future UI ne doit pas compresser une table sur mobile. Les champs, chips et
boutons doivent utiliser la largeur disponible, conserver des cibles tactiles
d'au moins 44–48 px et éviter le label membre fixe de 220 px.

## 14. Accessibilité

- ordre de focus cohérent entre filtres, liste et fiche ;
- noms sémantiques pour projet, statut, progression, alerte et actions ;
- libellés explicites pour les actions icônes, notamment retrait et édition ;
- annonces des chargements, erreurs et confirmations ;
- contraste vérifié des puces de statut et progressions ;
- aucune information portée uniquement par la couleur ;
- progression accompagnée de sa source et de sa valeur textuelle ;
- dialogues sensibles focalisés, annulables et utilisables au clavier ;
- tests à 200 % de zoom et avec grandes tailles de texte.

## 15. Matrice future de captures

| Capture | Viewport | État attendu | Mutation |
|---|---:|---|---|
| Portefeuille opérationnel | 1440×900 | Statuts variés, chef, échéance, alerte, prochaine action | Non |
| Portefeuille compact | 1366×768 | Densité et filtres ouverts | Non |
| Portefeuille tablette | 768×1024 | Filtres et liste lisibles | Non |
| Portefeuille mobile | 390×844 | Priorités essentielles, aucun overflow | Non |
| Fiche résumé/équipe | 1366×768 | Chef, adjoint, membres, état, prochaine action | Non |
| Travail et blocages | 1366×768 | Tâches, retard, blocage, porteur | Non |
| Documents/activité/impact | 1366×768 | Données liées réellement chargées | Non |
| Changement de statut | 1366×768 | Résumé et confirmation non cochée | Non |
| Changement responsable | 1366×768 | Effet de remplacement expliqué, non confirmé | Non |
| Retrait membre | 390×844 | Avertissement, action finale non déclenchée | Non |
| Permission lecture seule | 1366×768 | Actions absentes selon rôle | Non |
| Vide/erreur/loading | 390×844 et 1366×768 | États distincts via gateway simulé | Non |

## 16. Fichiers probablement concernés

Sans engager l'implémentation, le périmètre probable est :

- `frontend/lib/features/projects/models/` pour les modèles de présentation ;
- `frontend/lib/features/projects/services/` pour un gateway injectable ;
- `frontend/lib/features/projects/screens/` pour portefeuille et fiche ;
- un nouveau dossier `frontend/lib/features/projects/widgets/` ;
- `frontend/lib/app/app_router.dart` pour `/projects/:projectId` ;
- `frontend/lib/core/auth/user_experience.dart` seulement si la politique de
  visibilité évolue ;
- les tests widgets/services Projets ;
- éventuellement les services de tâches, documents, événements, impact et
  posts pour transmettre un filtre projet explicite.

Toute évolution backend, migration des états ou création d'un agrégat devra
faire l'objet d'une phase autorisée séparément.

## 17. Baseline technique

Depuis `frontend`, sans `flutter pub get` :

- `flutter analyze --no-pub` : **OK**, aucune anomalie ;
- `flutter test --no-pub --reporter expanded -j 1 --timeout 45s` : **OK**,
  105/105 tests réussis ;
- `flutter build web --release --no-pub --pwa-strategy=none` : **OK**.

Cette baseline ne contient toujours aucun test dédié à Projets.

## 18. Questions réellement bloquantes

1. Les valeurs runtime anglaises doivent-elles être migrées vers le contrat
   français, ou le contrat officiel doit-il adopter une nouvelle taxonomie ?
2. La progression officielle doit-elle venir des tâches, de l'Impact, de
   jalons futurs ou rester saisie manuellement ?
3. Quelle visibilité cible est voulue : tous les projets, mes projets, ou une
   combinaison dépendant du rôle ? L'API renvoie actuellement tout.
4. Faut-il un historique serveur agrégé pour les changements de statut,
   responsables et échéances, au-delà des audits d'affectation ?
5. « Archiver » et « supprimer » sont-ils des besoins réels ? Aucun contrat
   Projet ne les supporte aujourd'hui.
6. Un blocage doit-il porter un motif, un responsable et une date de résolution
   estimée ? Le statut de tâche actuel ne suffit pas à présenter cela.
7. Le contenu TERRASEN codé en dur doit-il devenir une fixture, un modèle ou
   être retiré de l'expérience générique ?

Ces décisions bloquent la fidélité métier de la future refonte, mais pas le
découpage technique ni les tests non mutatifs.
