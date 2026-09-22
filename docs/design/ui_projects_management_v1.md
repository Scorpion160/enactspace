# UI Projets — Création, édition et statuts sécurisés

## Périmètre

La phase 2E-B1 ajoute uniquement la gestion du projet lui-même au portefeuille
`/projects` et à la fiche `/projects/:projectId` : création, édition et
transition de statut. Les nominations de chef et d’adjoint, les affectations et
les retraits de membres restent reportés à 2E-B2.

## Contrat POST `/api/projects/`

La création dépend de `require_sg_or_admin`, dont le contrat réel autorise les
rôles `administrateur`, `team_leader` et `secretaire_generale`. Le corps
`ProjectCreate` accepte :

- `season_id` : UUID optionnel ;
- `name` : chaîne obligatoire ;
- `description`, `problem_statement`, `solution`, `objectives` et
  `expected_impact` : chaînes optionnelles ;
- `budget_estimated` : nombre, valeur par défaut `0` ;
- `status` : chaîne, valeur par défaut `idee` ;
- `started_at` et `ended_at` : dates ISO optionnelles.

Le backend crée puis retourne le projet. Cette route ne produit actuellement
ni audit métier ni notification. Pydantic retourne `422` pour une forme ou un
type invalide et la dépendance retourne `403` si le rôle est insuffisant. La
route ne possède ni `404` fonctionnel ni erreur `400` explicite. Elle ne
contrôle pas elle-même la liste canonique des statuts : l’interface limite donc
strictement la sélection aux sept valeurs officielles, sans prétendre remplacer
une validation serveur manquante.

## Contrat PATCH `/api/projects/{id}`

La mise à jour exige un utilisateur actif et validé. `require_project_manager`
autorise les trois rôles globaux ci-dessus ou un membership actif, sans
`left_at`, à la position `chef_projet` ou `adjoint_chef_projet` sur le projet
ciblé. Le corps `ProjectUpdate` accepte les mêmes champs, tous optionnels, et le
backend n’applique que les clés réellement présentes.

Le projet absent produit `404`, un gestionnaire insuffisant `403`, une valeur
de statut hors des sept valeurs `400`, et un type ou format invalide `422`.
Après succès, `updated_at` est remplacé puis la transaction est validée. Aucun
audit, notification, changement de tâche ou changement de membership n’est
déclenché.

## Création et édition

Le bouton « Nouveau projet » est visible uniquement pour les gestionnaires
globaux. Le dialogue structuré expose les champs du contrat réel, charge les
saisons via `GET /api/seasons/`, humanise la saison actuelle et utilise
uniquement les statuts Idée, Étude, Prototype, Test, Déploiement, Terminé et
Suspendu.

La validation locale impose un nom non vide, un budget numérique, des dates au
format `JJ/MM/AAAA` et une date de fin postérieure ou égale à la date de début.
Le formulaire d’édition est distinct de l’affichage, prérempli depuis le projet
et n’expose pas le statut : celui-ci suit le parcours sécurisé dédié. Les
valeurs restent en place après erreur, le message est humanisé et l’action
devient « Réessayer ». Pendant un envoi, l’action est désactivée et un garde
interne empêche aussi le double clic avant reconstruction du widget.

## Zone de gestion et permissions

La fiche affiche « Gestion du projet », « Modifier le projet » et « Changer le
statut » uniquement si le compte est gestionnaire global ou correspond à un
chef/adjointe ou adjoint actif réellement chargé dans les memberships du
projet. Aucun `can_manage` serveur n’est inventé et un rôle de responsabilité
global sans membership correspondant ne suffit pas à obtenir une gestion
locale.

## Transitions de statut

Le sélecteur ne déclenche aucune requête. Il masque le statut actuel, affiche le
résumé `statut actuel → statut cible`, puis attend une confirmation explicite.
Le backend n’impose aucune matrice de transitions ; l’interface n’en invente
donc pas et conserve seulement les protections de confirmation.

« Terminé » utilise « Marquer ce projet comme terminé ? » et affiche, à titre
informatif, les nombres de tâches non terminales, bloquées et en retard déjà
chargés. Ces nombres ne bloquent pas la transition et aucune tâche n’est
modifiée. « Suspendu » utilise « Suspendre ce projet ? », précise que le projet
reste consultable et ne demande aucun motif puisque l’API n’en persiste pas.
Les cinq autres statuts utilisent le dialogue standard « Mettre à jour le
statut du projet ».

## Comportement `ended_at`

Le backend accepte `ended_at` mais ne le synchronise jamais avec le statut.
Pour préserver le comportement historique de l’ancienne interface, une seule
fonction `ProjectStatusMutationPayload.build` :

- envoie la date de fin existante ou la date courante lors du passage à
  `termine` ;
- envoie `ended_at: null` lors d’une transition vers un autre statut si une
  date de fin existait.

Cette règle provient du frontend historique et reste une dette à contractualiser
côté métier. Elle n’est dupliquée dans aucun dialogue. L’édition explicite peut
également envoyer ou effacer `ended_at`, champ réellement supporté par PATCH.

## Succès, erreurs et rafraîchissement

Après une mutation réussie, le gateway invalide ses caches de projets, Impact,
membres, tâches, assignés et documents. L’écran relit alors les sources et
affiche discrètement « Projet mis à jour ». Les erreurs gardent le dialogue et
les valeurs ouverts. Les messages `400`, `403`, `404` et `422` fournis par
`ApiClient` sont présentés sans exposer de valeur technique brute.

## Testabilité

`ProjectsPortfolioGateway` injecte le compte courant, les saisons, toutes les
lectures et les trois mutations. Les tests utilisent exclusivement un gateway
mémoire. Les 31 tests 2E-B1 couvrent permissions globales et locales,
formulaires, validations, statuts canoniques, succès, erreurs, conservation,
double clic, confirmations sensibles, rafraîchissement, `ended_at`, absence de
pourcentage artificiel et largeur 390 px. Aucune requête réelle n’est émise.

## Runtime non mutatif

La trace `docs/design/screenshots/ui_projects_management_v1/runtime_check.json`
consigne l’ouverture en lecture seule du portefeuille, du formulaire de
création, du formulaire d’édition et du dialogue de statut. Aucun bouton final
n’est actionné, le nombre de projets reste neuf et `mutation_performed` reste
`false`.

## Validation visuelle

Les huit captures desktop et mobile de `ui_projects_management_v1` valident
visuellement la zone de gestion, la création, la validation locale, l’édition
préremplie et les dialogues de transition standard, de suspension et de
clôture. Les formulaires et dialogues ont été refermés sans action finale.

Le contrôle runtime avant et après les captures compte 9 projets inchangés.
Audit Horizon reste `idee`, Audit Canopée reste `suspendu` et Audit Solstice
reste `termine`. Aucune requête POST ou PATCH réelle n’a été envoyée,
`mutation_performed` reste `false` et `ended_at` n’a pas été muté. La gestion
des équipes et responsables demeure reportée à la phase 2E-B2.

## Limites backend restantes

- absence de validation canonique du statut sur POST ;
- absence de matrice de transitions métier ;
- absence de validation serveur de l’ordre des dates ;
- absence de contrainte métier explicite sur le signe du budget ;
- règle `status ↔ ended_at` non contractualisée côté serveur ;
- absence d’audit et de notification sur POST/PATCH ;
- aucune permission `can_manage` portée par `ProjectRead` : le frontend doit
  recouper le compte et les memberships ;
- aucun endpoint agrégé ne permet de rafraîchir une fiche en une seule lecture ;
- gestion des responsables et membres volontairement reportée à 2E-B2.
