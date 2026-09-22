# UI Pôles v1 — Inventaire fonctionnel, technique et UX

## 1. Périmètre

Cet inventaire couvre uniquement l'état existant du module Pôles au commit de
départ `34769c7e54ebddf8e063a291f70c595b2090c323`, avant toute refonte. Le
périmètre principal est la route Flutter `/poles` et le préfixe backend
`/api/poles`. Les membres, projets, tâches, événements, documents,
publications, dashboard, Impact, permissions, audits et notifications ne sont
étudiés que lorsqu'ils portent réellement un `pole_id`, une membership ou une
permission de pôle.

Aucun backend ni code applicatif n'a été modifié. Aucun seed global ni endpoint
de mutation applicatif n'a été exécuté. La fixture locale Pôles a été appliquée
deux fois uniquement à la base isolée `ui_audit`; la seconde exécution n'a créé
ni mis à jour aucune ligne.

## 2. Fichiers inspectés

Les fichiers principaux inspectés sont :

- `frontend/lib/features/poles/models/pole_model.dart` ;
- `frontend/lib/features/poles/services/poles_service.dart` ;
- `frontend/lib/features/poles/screens/poles_screen.dart` ;
- `frontend/lib/app/app_router.dart` ;
- `frontend/lib/core/auth/user_experience.dart` ;
- les modèles, services et écrans liés de `members`, `projects`, `tasks`,
  `events`, `documents`, `posts`, `dashboard` et `impact` ;
- `backend/app/api/routes/poles.py`, `backend/app/models/pole.py` et
  `backend/app/schemas/pole.py` ;
- les routes, modèles et schémas liés de `users`, `projects`, `tasks`,
  `events`, `documents`, `posts`, `dashboard`, `impact`, `audit` et
  `notifications` ;
- `backend/app/api/deps.py`, `backend/app/core/roles.py`,
  `backend/app/services/audit_service.py` et
  `backend/app/services/notification_service.py` ;
- les traces runtime déjà validées sous `docs/design/screenshots/` et la
  définition déterministe de la fixture `ui_audit`.

Le module Pôles contient 2 160 lignes : 1 906 pour l'écran, 127 pour le service
et 127 pour le modèle.

## 3. Architecture actuelle

`poles_screen.dart` concentre 30 classes, dont 29 privées. Il réunit dans un
seul fichier : orchestration réseau, recherche, calcul local des permissions,
portefeuille, cartes, score de « santé », fiche détaillée, gouvernance,
affectation/retrait, création, édition et états loading/vide/erreur.

Le chargement initial déclenche :

1. `GET /poles/` ;
2. `GET /users/directory` ;
3. un `GET /poles/{id}/members` pour chaque pôle via `Future.wait` ;
4. `GET /users/me` via le service d'authentification.

Avec 7 pôles, cela représente 10 appels. Les membres sont donc chargés en N+1.
Une erreur d'une seule liste de memberships fait échouer tout le portefeuille,
alors que les erreurs d'annuaire et d'utilisateur courant sont silencieusement
remplacées par une liste vide ou des permissions nulles.

Les trois services sont instanciés directement dans le `State` : aucune
injection de gateway n'est prévue pour les tests widgets. Aucun test dédié à
`PolesScreen` ou `PolesService` n'existe ; deux objets `PoleModel` apparaissent
seulement dans les tests de conversion Recrutement.

L'écran utilise trois `showModalBottomSheet` imbriqués (détail, création,
édition), aucun dialogue de confirmation, un seul `IconButton` doté d'un
tooltip, et aucun widget `Semantics` explicite. Les largeurs notables sont 126,
178, 260–340 et 760 px. La grille passe de 3 à 2 puis 1 colonne aux seuils
1 100 et 720 px ; l'en-tête se replie sous 820 px.

Le score « Santé du pôle » n'est pas une donnée métier. Il additionne
localement nombre de membres et complétude de `description`, `objectives` et
`short_name`. Il ne mesure ni travail, retards, projets, charge, activité ni
gouvernance.

## 4. Surfaces fonctionnelles

| Besoin | Contrat réel | Surface actuelle |
|---|---|---|
| Liste des pôles | Oui, liste complète | Grille et recherche locale nom/sigle/type |
| Fiche pôle | Aucun endpoint détail dédié | Grande feuille construite depuis la liste |
| Chef / adjoint | Positions de membership | Affichage par position ou heuristique sur les rôles |
| Membres | Liste active, affectation, retrait logique | Dans la feuille de détail |
| Projets liés | Table `project_poles` | Aucun affichage ni gestion |
| Tâches liées | `Task.pole_id`, endpoint dédié | Lien générique vers `/tasks`, sans filtre |
| Événements | `Event.pole_id` | Lien générique vers `/events`, sans filtre |
| Documents | `Document.pole_id`, filtre disponible | Lien générique vers `/documents`, sans filtre |
| Activité | Posts/audits portent un pôle | Non affichée dans la fiche |
| Statistiques | Comptage dashboard global seulement | Total pôles/membres et score local artificiel |
| Création | Oui | Feuille modale, gestion globale seulement |
| Édition | Oui | Feuille modale, gestion globale ou locale |
| Activation/inactivation | Aucun champ sur `Pole` | Absente |
| Ajout/retrait membre | Oui | Action immédiate dans la fiche |
| Changement chef/adjoint | Oui via affectation | Même formulaire que l'ajout |
| Suppression/archivage | Aucun endpoint ni champ | Absents |

Les liens « Tâches », « Documents » et « Événements » quittent la fiche vers
une route générale et perdent le contexte du pôle. Aucun résumé de projets,
activité, documents, charge ou prochaine action n'est chargé par l'écran.

## 5. Endpoints

### A. Endpoints Pôles utilisés par l'écran actuel

| Méthode et route | Permission backend | Paramètres / corps / réponse | Mutations, erreurs et usage |
|---|---|---|---|
| `GET /api/poles/` | Compte actif validé ou alumni | Aucun filtre ni pagination ; tri par nom ; `list[PoleRead]` | Charge le portefeuille complet. 401/403 d'authentification |
| `GET /api/poles/{pole_id}/members` | Compte actif validé ou alumni | Membres actifs avec `left_at=null`, tri position/date ; `list[PoleMemberDirectoryRead]` | Appelé N fois. 404 pôle ; aucune pagination |
| `POST /api/poles/` | Admin, Team Leader ou SG | `season_id?`, `name`, `short_name?`, `type`, `description?`, `objectives?` ; `PoleRead` | Création. 401/403/422 ou erreur DB ; aucun audit/notification |
| `PATCH /api/poles/{pole_id}` | Gestion globale ou chef/adjoint canonique actif du pôle | Patch partiel des cinq champs éditables ; `PoleRead` | Édition. 403/404/422 ; aucun audit/notification |
| `POST /api/poles/{pole_id}/members` | Gestion globale ou chef/adjoint canonique actif | `user_id`, `position` ; `PoleMemberRead` | Crée, réactive ou change la position. 400 position/membre inactif, 403, 404 ; audit et notifications |
| `DELETE /api/poles/{pole_id}/members/{user_id}` | Même gestion ; responsable retirable uniquement par gestion globale | Aucun corps ; `PoleMemberRead` désactivé | Retrait logique. 403/404 ; audit, notification et synchronisation de rôle |

Les six endpoints Pôles sont intégrés. L'écran appelle aussi
`GET /api/users/directory` pour le sélecteur et `GET /api/users/me` pour les
permissions. Il n'existe ni `GET /poles/{id}`, ni filtre serveur, ni
pagination, ni agrégat, ni endpoint d'activation, archivage ou suppression.

### B. Endpoints liés disponibles mais non intégrés à la fiche

| Endpoint | Données utiles | Situation actuelle |
|---|---|---|
| `GET /api/tasks/pole/{pole_id}` | Toutes les tâches du pôle, `can_manage`, état, priorité, échéance | Disponible dans le service Tâches mais non appelé par Pôles |
| `GET /api/tasks/late` | Tâches visibles en retard | Disponible, mais pas de filtre `pole_id` et non appelé par Pôles |
| `GET /api/documents/?pole_id=…` | Documents visibles du pôle et nombreux filtres | Le service sait transmettre `pole_id`, la fiche ne le fait pas |
| `GET /api/posts/?pole_id=…` | Publications visibles du pôle | Le service et l'écran Posts savent filtrer, la fiche ne le fait pas |
| `GET /api/events/` | Réponses portant `pole_id` | Aucun filtre serveur `pole_id`; filtrage client possible mais absent de Pôles |
| `GET /api/dashboard/summary` | Compte global des pôles et données bornées au scope utilisateur | Aucun agrégat par pôle |
| `GET /api/impact/projects` | Nom du premier pôle associé à chaque projet | Relation utilisée en lecture par Impact, non par Pôles |

Ces sept lectures liées portent le recensement utile à 13 endpoints, dont 6
Pôles directs. Elles ne constituent pas une fiche agrégée et plusieurs
nécessiteraient encore des appels multiples ou du filtrage client.

## 6. Permissions

Le backend est la source de vérité. « Voir » distingue l'API, très ouverte,
de la route Flutter, plus restrictive.

| Rôle | API liste/détail membres | UI `/poles` | Modifier | Gérer membres ordinaires | Nommer chef/adjoint | Retirer responsable | Tâches associées | Supprimer/archiver |
|---|---|---|---|---|---|---|---|---|
| Administrateur | Tous | Oui | Tous | Tous | Oui | Oui | Toutes | Indisponible |
| Team Leader | Tous | Oui | Tous | Tous | Oui | Oui | Toutes | Indisponible |
| Secrétaire générale | Tous | Oui | Tous | Tous | Oui | Oui | Toutes | Indisponible |
| Chef de pôle | Tous | Oui | Son pôle si membership canonique | Son pôle | Non | Non | Toutes celles de son pôle | Indisponible |
| Adjoint de pôle | Tous | Oui | Son pôle si membership canonique | Son pôle | Non | Non | Toutes celles de son pôle | Indisponible |
| Chef de projet | Tous | Oui | Non, sauf autre membership pôle | Non | Non | Non | Son projet, pas le pôle | Indisponible |
| Adjoint de projet | Tous | Oui | Non, sauf autre membership pôle | Non | Non | Non | Son projet, pas le pôle | Indisponible |
| Membre simple | Tous via API | Non | Non | Non | Non | Non | Assignées/créées seulement | Indisponible |
| Alumni | Tous via API | Non | Non | Non | Non | Non | Non | Indisponible |

La liste API ne filtre pas par membership : tout compte validé, y compris un
alumni, peut lire tous les pôles et leurs membres. Le frontend expose la route
à tous les profils `isEnacchef`, donc aussi aux responsables de projet, mais
pas au membre simple ni à l'alumni.

La gestion globale Pôles comprend Admin, Team Leader et SG. Un chef/adjoint
local peut modifier son pôle, ajouter ou retirer un membre ordinaire, mais ne
peut ni nommer ni retirer un responsable. Les projets liés ne sont pas
gérables depuis Pôles : les permissions Projet restent indépendantes.

## 7. Memberships

Le modèle `PoleMember` contient : `id`, `pole_id`, `user_id`, `position`,
`joined_at`, `left_at` et `is_active`. La contrainte
`uq_pole_user(pole_id,user_id)` impose une seule ligne par couple pôle/membre.

Valeurs canoniques backend :

- `membre` → membre du pôle ;
- `chef_pole` → chef du pôle ;
- `adjoint_chef_pole` → adjoint du chef de pôle.

Une affectation existante est réactivée avec `is_active=true` et
`left_at=null`; `joined_at` n'est pas remis à la date de réactivation. Un
retrait conserve la ligne, fixe `is_active=false` et `left_at=date.today()`.
La lecture publique interne ne renvoie que les memberships actives non
quittées : l'écran ne peut donc jamais afficher son compteur « inactifs ».

Il ne peut y avoir qu'un titulaire actif par position de chef et d'adjoint :
la nomination d'un nouveau titulaire démote tous les anciens de la même
position vers `membre`. Les rôles globaux `chef_pole` et
`adjoint_chef_pole` sont synchronisés selon l'existence d'au moins une
membership active de cette position. Affectation, remplacement et retrait
génèrent notifications et audit (`affectation_pole` ou `retrait_pole`).

La fixture `ui_audit` contenait les positions legacy `chef` et `adjoint` sur
Technique. Elles ont été normalisées vers `chef_pole` et
`adjoint_chef_pole`. Le contrôle final en base ne trouve plus aucune position
legacy et les deux responsables satisfont désormais les règles canoniques de
`require_pole_manager`. Les valeurs legacy ne sont pas ajoutées au nouveau
contrat UI.

## 8. Relations projets et tâches

### Pôles ↔ projets

`project_poles` contient `id`, `project_id`, `pole_id` et une unicité par
couple. Le schéma autorise plusieurs pôles par projet et plusieurs projets par
pôle. Aucun champ ne désigne un pôle principal.

Aucun endpoint backend ne crée, liste explicitement ou supprime ces liens.
Les routes Projets et Pôles ne les exposent pas, et le frontend ne les utilise
pas. Impact joint `ProjectPole`, trie les pôles par nom et ne retient que le
premier pour produire `pole_name`; il ne gère donc pas fidèlement le cas
multi-pôles. La future UI peut afficher les liens existants seulement après un
contrat de lecture approprié ; elle ne doit pas inventer leur gestion.

La fixture initiale associe chacun des huit projets d'audit à exactement un
pôle : Technique porte deux projets, chacun des six autres pôles en porte un.
Le pôle synthétique sans équipe n'a aucun lien projet. L'upsert Pôles n'a pas
modifié `project_poles`, dont le compteur reste à 8.

### Pôles ↔ tâches

`Task.pole_id` est exploitable. `GET /tasks/pole/{pole_id}` renvoie les tâches
du pôle triées par création, sans pagination. Un responsable canonique du pôle
peut voir et gérer toutes ses tâches, en créer et assigner uniquement des
membres actifs du même pôle. Un membre ordinaire ne voit que les tâches dont
il est assigné ou créateur ; il peut progresser sur un sous-ensemble de
statuts. Les gestionnaires globaux voient et gèrent tout.

Les six statuts canoniques sont `a_faire`, `en_cours`, `bloque`, `termine`,
`valide`, `annule`; les priorités sont `basse`, `normale`, `haute`, `urgente`.
Le retard est calculable par `due_date` pour une tâche non terminée, validée ou
annulée. Le statut `bloque` permet un compteur de blocages, mais aucun champ ne
porte motif, propriétaire de résolution ou ETA.

Une future fiche peut donc réellement afficher tâches du pôle, tâches en
retard, tâches bloquées et prochaine échéance. « Prochaine action » ne peut
être qu'une tâche ouverte ordonnée par échéance, avec ses assignés chargés en
complément ; elle ne doit pas prétendre être une recommandation métier.

## 9. Données `ui_audit`

Le contrôle runtime en lecture seule du 27 août 2026 atteste 8 pôles chargés.
Tous les endpoints consultés ont répondu HTTP 200. Les données ci-dessous
croisent cette lecture API, la fixture déterministe et le contrôle direct final
de la base isolée, sans mutation applicative.

| Pôle | Type | Memberships actives | Projets reliés connus | Tâches fixture | Événements fixture | Documents fixture |
|---|---|---:|---:|---:|---:|---:|
| Technique | métier | 8 | 2 | 8 | 2 | 5 |
| Chimie | métier | 4 | 1 | 7 | 2 | 5 |
| Gestion | métier | 5 | 1 | 7 | 2 | 4 |
| IT | métier | 4 | 1 | 7 | 1 | 4 |
| Communication | support | 4 | 1 | 7 | 1 | 4 |
| Veille | support | 4 | 1 | 7 | 1 | 4 |
| Organisation | support | 5 | 1 | 7 | 1 | 4 |
| Audit Pôle Sans Équipe | support | 0 | 0 | 0 | 0 | 0 |

Les 34 memberships historiques restent actives et une membership synthétique
inactive, retirée le 1er juillet 2026, est disponible pour le scénario de
réactivation. Elle n'apparaît pas dans `GET /api/poles/{id}/members`.
Technique a un chef et un adjoint canoniques. Le pôle synthétique sans équipe
a aussi `description` et `objectives` absents pour couvrir l'état partiel. Les
50 tâches d'origine ont été normalisées lors de la phase Projets : les valeurs
legacy `terminee`/`bloquee` n'y restent plus. Une tâche future dédiée et
assignée a été ajoutée à Technique ; son runtime expose 1 tâche bloquée et 5
tâches en retard.

Les 8 liens `project_poles` couvrent les 8 projets d'origine et sont restés
inchangés. Le pôle sans équipe est également sans projet. Le contrôle runtime
de Technique atteste 5 documents et 2 publications, ainsi qu'un événement
futur dédié au 20 avril 2027, sans qu'aucune activité soit encore agrégée dans
la fiche.

Scénarios de permissions présents : Admin, Team Leader, SG, chef de pôle,
adjoint de pôle, chef de projet, adjoint de projet, membre, alumni, financier
et compte multi-rôle. Les comptes inactifs existent mais n'ont pas de
membership ; le candidat n'en a aucune.

## 10. Incohérences et couverture des fixtures

| État nécessaire | Couverture | Constat |
|---|---|---|
| 7 pôles cœur/support historiques | Couvert | 4 métier, 3 support, plus 1 pôle synthétique support |
| Pôle avec chef canonique | Couvert | Technique utilise `chef_pole` |
| Pôle avec adjoint canonique | Couvert | Technique utilise `adjoint_chef_pole` |
| Pôle sans chef | Couvert | 7 pôles sans titulaire |
| Pôle sans adjoint | Couvert | 7 pôles sans titulaire |
| Pôle sans membre | Couvert | `Audit Pôle Sans Équipe`, 0 membership active |
| Membership retirée/réactivable | Couvert | Membership inactive dédiée sur Technique, masquée par la lecture active |
| Membre inactif dans le sélecteur | Couvert côté annuaire | 5 comptes inactifs, mais le chargement annuaire silencieux masque les erreurs |
| Pôle avec plusieurs projets | Couvert | Technique en a 2 |
| Projet multi-pôles | Manquant | Tous les liens existants sont mono-pôle |
| Projet sans pôle | Couvert/incomplet | Neuvième projet sans lien documenté |
| Pôle sans projet | Couvert | `Audit Pôle Sans Équipe`, sans lien ; compteur global inchangé à 8 |
| Tâches canoniques | Couvert | Valeurs legacy normalisées par la phase Projets |
| Blocage canonique | Couvert | Technique expose 1 tâche `bloque` au runtime |
| Prochaine tâche future de pôle | Couvert | `AUDIT-POLE-NEXT-ACTION-001`, assigné connu et `project_id=null` |
| Événement futur de pôle | Couvert | `AUDIT-POLE-EVENT-FUTURE-001`, lié à Technique et sans projet |
| Documents/activité | Couvert | Technique expose 5 documents et 2 publications au runtime |
| Loading/vide/erreur | Manquant en runtime | À couvrir par gateway injectée en tests widgets |

## 11. Diagnostic UX priorisé

### P0

- les positions legacy rendent le chef/adjoint visibles mais non gestionnaires
  locaux selon les mêmes règles que le backend ;
- retrait d'un membre et changement de responsabilité partent sans résumé ni
  confirmation, malgré audits, notifications et synchronisation de rôles ;
- le score « Santé » est présenté comme une mesure fiable alors qu'il est
  fabriqué à partir de la complétude éditoriale ;
- aucune donnée opérationnelle sur projets, retard, blocage ou prochaine action.

### P1

- N+1 des memberships et échec global si un seul pôle échoue ;
- permissions recalculées côté client à partir de toutes les memberships,
  sans flags serveur ;
- fiche longue en bottom sheet, difficile à retrouver, partager et parcourir ;
- liens vers Tâches/Documents/Événements sans filtre de pôle ;
- services non injectables et absence de tests Pôles ;
- la liste membres exclut les memberships retirées alors que l'UI prétend
  compter les inactifs.

### P2

- cartes narratives répétitives et hautes : description, objectifs, santé et
  avatars précèdent toute alerte/action ;
- hiérarchie insuffisante entre gouvernance, charge et risques ;
- annuaire entier chargé pour chaque visite, y compris quand l'utilisateur ne
  peut rien gérer ;
- édition, affectation et gouvernance mélangées dans une même feuille ;
- états partiels absents pour équipe, travail, projets, documents et activité.

### P3

- pluriels techniques « pôle(s) », « membre(s) », « actif(s) » ;
- type « métier » rendu « Pôle cœur » par heuristique locale ;
- avatars et indicateurs colorés sans description sémantique dédiée ;
- grands textes et zoom peuvent allonger fortement les feuilles imbriquées.

## 12. Mutations sensibles

| Mutation | Permission | Effet réel | Confirmation actuelle | Audit / notification / rôle | Risque |
|---|---|---|---|---|---|
| Créer un pôle | Admin/TL/SG | Insère le pôle | Soumission simple | Aucun | Doublon, type libre, saison absente |
| Éditer | Global ou responsable local canonique | Remplace les champs fournis | Aucune confirmation | Aucun | Changement de nom/type sans trace métier |
| Nommer chef | Admin/TL/SG | Affecte/réactive, démote l'ancien chef | Aucune | Audit, notifications, rôle synchronisé | Perte immédiate de responsabilité |
| Nommer adjoint | Admin/TL/SG | Affecte/réactive, démote l'ancien adjoint | Aucune | Audit, notifications, rôle synchronisé | Même risque |
| Ajouter membre | Global ou responsable local | Crée/réactive la membership | Aucune | Audit et notification | Réactivation sans nouveau `joined_at` |
| Retirer membre | Global ou responsable local ; responsable seulement global | `is_active=false`, `left_at` renseigné | Aucune, icône immédiate | Audit, notification, retrait du rôle si besoin | Clic accidentel et perte de scope |
| Désactiver pôle | Non disponible | Aucun champ/endpoint | Sans objet | Sans objet | Ne pas simuler |
| Supprimer/archiver | Non disponible | Aucun endpoint | Sans objet | Sans objet | Ne pas simuler |

Le frontend ferme la fiche après affectation ou retrait et recharge la totalité
des pôles, ce qui augmente le coût et peut masquer le contexte de l'action.

## 13. Proposition de découpage futur

### A. Portefeuille des pôles

- `PolesPortfolioScreen` : orchestration, accès et état global ;
- `PolesGateway` injectable : liste agrégée et erreurs testables ;
- `PolePortfolioItem` et présentation centralisée des types/alertes ;
- `PolesFilters` ;
- liste structurée desktop/tablette et cartes compactes mobile ;
- `PoleLeadershipSummary`, `PoleWorkSummary`, `PoleNextAction`.

Priorité d'affichage : nom, chef, adjoint, membres, projets, alertes et prochaine
action. Description et objectifs restent secondaires.

### B. Fiche pôle

- route dédiée `/poles/:poleId` ;
- `PoleOverview` ;
- `PoleTeam` ;
- `PoleProjects` seulement en lecture tant qu'aucun contrat de gestion
  `project_poles` n'existe ;
- `PoleWork` alimenté par les tâches réelles ;
- `PoleActivity` via posts/audits si le contrat est défini ;
- `PoleDocuments` via filtre `pole_id` ;
- dialogues indépendants pour édition, affectation, responsabilité et retrait.

Un endpoint agrégé devrait idéalement fournir permissions, gouvernance,
compteurs de membres/projets/tâches, retards, blocages, prochaine échéance,
documents et activité. Sans évolution backend, la gateway devra composer les
lectures existantes sans déplacer les règles métier dans Flutter.

## 14. Direction visuelle

Le portefeuille doit être un outil de coordination dense, pas une simple
recoloration des cartes actuelles. Sur desktop, une liste souple permet de
comparer immédiatement gouvernance, capacité, projets, alertes et prochaine
action. La fiche commence par une phrase de situation : responsable, charge,
blocage et prochaine échéance ; description et objectifs suivent.

Les alertes associent texte, icône et couleur. Les mutations sensibles sont
séparées du contenu de lecture, avec conséquences explicites avant l'action
finale. Aucun score de santé ne doit être affiché sans source métier.

## 15. Responsive

- **390×844** : statut de gouvernance, chef, alerte et prochaine action en
  premier ; carte unique, sections repliables, aucune table compressée ;
- **768×1024** : liste à une colonne enrichie ou master/detail, filtres en
  panneau ;
- **1366×768** : portefeuille dense et fiche dédiée/panneau stable ;
- **1440×900** : même structure avec davantage d'activité et de travail visible.

Les actions secondaires doivent être repliées sur mobile. Champs, menus et
boutons doivent utiliser la largeur disponible et garder des cibles tactiles
d'au moins 44 px. La fiche ne doit plus dépendre d'une cascade de bottom
sheets.

## 16. Accessibilité

- noms `Semantics` pour pôle, gouvernance, alertes, compteurs et actions ;
- ordre de focus cohérent entre recherche, portefeuille et fiche ;
- navigation clavier Web, fermeture explicite et restitution du focus ;
- labels visibles pour les boutons icônes, notamment le retrait ;
- contraste vérifié des badges, progressions et états désactivés ;
- aucune information portée uniquement par une couleur ou un avatar ;
- annonces distinctes pour chargement, vide, erreur, succès et échec partiel ;
- dialogues sensibles focalisés, annulables et utilisables au clavier ;
- vérification à 200 % de zoom et avec grands textes.

L'écran actuel n'emploie aucun `Semantics` explicite. Le tooltip du bouton de
retrait aide la souris mais ne remplace pas une description de conséquence et
une confirmation accessible.

## 17. Fixtures et scénarios restant à simuler

La fixture déterministe couvre désormais :

- Technique avec `chef_pole` et `adjoint_chef_pole` canoniques ;
- un pôle sans membre, sans projet et à données partielles ;
- une membership inactive et réactivable ;
- une tâche future directement liée à Technique avec assigné connu ;
- un événement futur directement lié à Technique ;
- blocage, retards, documents et activité réels en lecture seule.

Restent à couvrir sans inventer de contrat métier :

- un projet multi-pôles seulement si ce cas est confirmé et exposé par l'API ;
- des scénarios injectés loading, vide, erreur globale et erreur partielle ;
- des gateways de permission pour les neuf profils de la matrice.

Une future fixture ne doit pas ajouter de suppression/archivage, de motif de
blocage, de charge ou de « projet principal » tant que le backend ne porte pas
ces concepts.

## 18. Matrice future de captures

| Capture | Viewport | État attendu | Mutation |
|---|---:|---|---|
| Portefeuille opérationnel | 1440×900 | 8 pôles, gouvernance, projets, alertes, prochaine action | Non |
| Portefeuille compact | 1366×768 | Densité et filtres ouverts | Non |
| Portefeuille tablette | 768×1024 | Liste lisible et filtres | Non |
| Portefeuille mobile | 390×844 | Chef/alerte/action d'abord, aucun overflow | Non |
| Fiche résumé | 1366×768 | Gouvernance, capacité, projets, prochaine échéance | Non |
| Équipe | 1366×768 | Chef, adjoint, membres et permissions | Non |
| Travail | 1366×768 | Retards, blocages et prochaine tâche | Non |
| Documents/activité | 1366×768 | Données réellement filtrées par pôle | Non |
| Nomination chef | 1366×768 | Effet de remplacement expliqué, non confirmé | Non |
| Retrait membre | 390×844 | Avertissement visible, action finale non déclenchée | Non |
| Lecture seule | 1366×768 | Actions absentes selon rôle | Non |
| Loading/vide/erreur | 390×844 et 1366×768 | États distincts via gateway simulée | Non |

## 19. Baseline technique

Depuis `frontend`, sans `flutter pub get` :

- `flutter analyze --no-pub` : **OK**, aucune anomalie ;
- `flutter test --no-pub --reporter expanded -j 1 --timeout 45s` : **OK**,
  212/212 tests exécutés et réussis. Les 210 déclarations statiques incluent
  une boucle paramétrée qui génère trois cas, soit deux exécutions de plus ;
- `flutter build web --release --no-pub --pwa-strategy=none` : **OK** (seul
  l'avertissement de dépréciation connu de `--pwa-strategy` est émis).

## Décisions après inventaire

- Les seules positions Pôles canoniques restent `membre`, `chef_pole` et
  `adjoint_chef_pole`.
- Les valeurs legacy `chef` et `adjoint` doivent être migrées uniquement dans
  les données synthétiques `ui_audit`; elles ne seront pas supportées par le
  frontend ni ajoutées au contrat backend.
- Le score local « Santé du pôle » sera supprimé de la future expérience :
  aucune mesure non sourcée ne le remplacera.
- La prochaine action proviendra uniquement d'une tâche réelle ouverte et de
  son échéance ; elle ne sera pas présentée comme une recommandation métier.
- Blocages et retards proviendront uniquement des statuts et échéances des
  tâches réellement liées au pôle, sans motif, responsable de déblocage ou ETA
  inventés.
- Aucune gestion de `project_poles` ne sera simulée. Le cas multi-pôles est
  reporté tant qu'un contrat de lecture et de gestion adapté n'existe pas.
- Aucune activation, inactivation, suppression ou archivage de pôle ne sera
  inventé en l'absence de contrat backend.
- Aucun faux historique ou journal de bord ne sera construit.
- Les règles de gouvernance backend sont conservées : gestion globale pour
  Admin, Team Leader et SG ; gestion locale bornée aux memberships actives et
  canoniques de chef/adjoint.

## 20. Questions réellement bloquantes

1. La liste API doit-elle rester visible à tout compte validé, y compris
   alumni, ou être alignée sur l'accès UI `isEnacchef` ?
2. Faut-il un contrat agrégé par pôle pour éviter le N+1 et fournir des flags
   de permission, ou la composition frontend est-elle acceptée ?
3. La relation `project_poles` doit-elle devenir administrable, et si oui un
   projet multi-pôles est-il réellement attendu ?
4. Quelle source officielle définit la charge et la prochaine action : tâches,
   calendrier, ou futur modèle dédié ?
5. Une activité de pôle doit-elle agréger posts, audits, événements et
   documents, et avec quelle politique de visibilité ?
6. L'activation, l'archivage ou la suppression d'un pôle sont-elles de vrais
   besoins ? Aucun contrat ne les supporte aujourd'hui.
7. La réactivation d'une membership doit-elle conserver `joined_at` ou tracer
   une nouvelle date d'entrée/historique ?

Ces décisions conditionnent la fidélité métier d'une future refonte, mais pas
la séparation technique ni les tests non mutatifs.
