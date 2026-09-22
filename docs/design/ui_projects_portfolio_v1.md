# UI Projets — Portefeuille et fiche en lecture seule

## Périmètre et routes

La phase 2E-A remplace l’expérience active de `/projects` par un portefeuille
orienté pilotage et ajoute la fiche dédiée `/projects/:projectId`. La fiche est
accessible depuis le portefeuille, par URL directe et après rafraîchissement
Web. Le retour privilégie l’historique de navigation, puis `/projects`.

Cette phase est strictement en lecture seule. Elle n’expose aucune création,
édition, transition de statut, nomination, affectation, retrait, clôture,
archive ou suppression. Ces mutations sont reportées à 2E-B.

## Architecture

L’implémentation active est répartie en quatre responsabilités :

- `models/project_status_presentation.dart` centralise les sept statuts projet ;
- `models/project_portfolio_models.dart` porte les agrégats de présentation,
  les tâches, alertes, prochaines actions et métriques Impact ;
- `services/projects_portfolio_gateway.dart` définit le contrat injectable de
  lecture et son implémentation API mise en cache ;
- les écrans `projects_portfolio_screen.dart` et
  `project_detail_screen.dart` orchestrent respectivement le portefeuille et
  la fiche ; leurs composants visuels résident dans `widgets/`.

Les écrans acceptent un `ProjectsPortfolioGateway`. Les tests utilisent une
implémentation mémoire et n’émettent donc aucune requête réelle.

## Portefeuille

Le desktop utilise une liste dense et souple : projet, statut, chef,
progression opérationnelle, prochaine action et échéance, porteur, alertes et
action « Ouvrir le projet ». Le mobile utilise des cartes compactes sans
tableau horizontal. Avec neuf projets, aucun mécanisme de pagination artificiel
n’est ajouté.

La recherche et les filtres statut, responsable et alerte sont appliqués côté
client. Les alertes couvrent les blocages, retards, projets sans prochaine
action et données incomplètes. « Réinitialiser » restaure l’ensemble du
portefeuille. Sur mobile, les filtres sont regroupés dans un panneau
repliable.

Les états chargement, erreur projets, liste vide et aucun résultat filtré sont
distincts. L’échec des membres, des tâches ou d’Impact pour un projet reste
local et n’interrompt pas la liste.

## Statuts, progression et prochaines actions

Les valeurs `idee`, `etude`, `prototype`, `test`, `deploiement`, `termine` et
`suspendu` sont présentées comme Idée, Étude, Prototype, Test, Déploiement,
Terminé et Suspendu. Une valeur inconnue devient « Statut non reconnu » et
n’est jamais affichée brute.

La seule source de progression est `GET /api/impact/projects`. Son libellé est
toujours « Progression opérationnelle ». Sans métrique exploitable ou si la
source échoue, l’interface affiche « Progression non disponible ». Aucun
pourcentage n’est déduit du statut projet.

La prochaine action est la tâche non terminale dont l’échéance future est la
plus proche. Les tâches terminées, validées et annulées sont ignorées. Le titre,
l’échéance et les assignés résolus depuis l’annuaire sont affichés. Une liste
de tâches vide produit « Aucune prochaine action planifiée » ; un échec de la
source produit « Prochaine action indisponible ».

Les blocages comptent uniquement les tâches `bloque`. Les retards sont calculés
uniquement depuis une échéance passée et un statut non terminal. Aucun motif,
responsable de déblocage ou délai de résolution n’est inventé.

## Fiche projet

La fiche est une page dédiée à six onglets sobres :

1. **Résumé** : nom, statut, problème, solution, objectifs, dates, chef,
   adjoint, progression opérationnelle, prochaine action et alertes ;
2. **Équipe** : chef, adjoint et membres actifs, avec « Aucune équipe affectée »
   lorsque la liste est réellement vide ;
3. **Travail** : tâches groupées en À faire, En cours, Bloqué, Terminé, Validé
   et Annulé, avec priorité, assignés, échéance et retard ;
4. **Activité** : événements réellement liés par `project_id`, sans faux
   journal de bord ;
5. **Documents** : documents chargés avec le filtre serveur `project_id`, état,
   date et action « Consulter » lorsque le fichier existe ;
6. **Impact** : uniquement les métriques contractuelles présentes dans
   l’agrégat Impact.

Les champs textuels absents sont présentés comme « Non renseigné ». Une source
secondaire en échec possède son propre état indisponible. Un projet sans
métrique exploitable affiche « Informations d’impact à compléter » ; aucun ODD
ou impact attendu n’est fabriqué. Une métrique Impact disponible n’implique pas
que toutes les informations de contexte du projet sont complètes. L’interface
conserve les métriques réelles et signale séparément les informations restant à
renseigner.

## Chargement, cache et résilience

Le gateway charge projets et Impact en parallèle, puis exécute en parallèle les
lectures membres et tâches de chaque projet. Toutes les lectures sont mises en
cache pour la durée de l’instance. La navigation portefeuille → fiche transmet
le gateway et l’agrégat déjà chargé : membres, tâches, Impact et assignés utiles
ne sont pas relancés inutilement. Une URL directe reconstruit la fiche à partir
des mêmes lectures en cache.

Les événements sont chargés une fois puis filtrés localement par `project_id`.
Les documents exploitent le filtre serveur existant. Chaque sous-source est
capturée indépendamment pour éviter un échec global.

## Responsive et accessibilité

Les seuils adaptent la liste dense desktop aux cartes mobile. Les largeurs
390 × 844, 768 × 1024, 1366 × 768 et 1440 × 900 sont couvertes par des layouts
souples, des onglets défilables et des actions tactiles d’au moins 44 px.

Des `Semantics` décrivent projet, statut, chef, progression opérationnelle,
prochaine action, responsable, alertes, ouverture de fiche et chacune des six
sections. Les alertes et états sont toujours textuels et ne dépendent pas de la
couleur. Les composants Material conservent la navigation clavier Web.

## Tests

`frontend/test/projects_portfolio_test.dart` ajoute 37 tests dédiés : mappings
des statuts, parsing Impact, chargement, vide, erreur, filtres, reset,
progression sourcée ou absente, prochaine action, blocages, retards,
chef/adjoint, projet sans équipe, navigation, route directe, six contenus de
fiche, erreurs partielles et largeur mobile. Le gateway mémoire garantit
l’absence de requête et de mutation réelle.

## Runtime en lecture seule

La trace `docs/design/screenshots/ui_projects_portfolio_v1/runtime_check.json`
reprend les contrôles API en lecture seule validés le 23 août 2026 : neuf
projets, sept statuts canoniques, neuf agrégats Impact, chef et adjoint d’Audit
Horizon, blocage d’Audit Canopée, projet sans équipe, prochaine action future,
événement futur, Audit Sans Impact incomplet et cohérence d’Audit Solstice.
`mutation_performed` reste `false`.

## Validation visuelle

Huit fichiers PNG distincts ont été produits aux viewports demandés. Les
captures du portefeuille desktop et mobile, des filtres, de l’équipe Audit
Horizon, du blocage Audit Canopée, de l’activité future, et du projet sans
équipe sont conformes et non mutatives. Les contrôles avant/après conservent
neuf projets, neuf agrégats Impact, le chef et l’adjoint, la tâche bloquée, la
prochaine action future, l’événement futur et le statut terminé d’Audit
Solstice. Aucune donnée projet, tâche, membre, document, événement ou Impact
n’a été modifiée.

La cible « Audit Sans Impact » expose, via `GET /api/impact/projects`, une
progression opérationnelle et plusieurs métriques exploitables, tout en ayant
un contexte projet incomplet. La capture 07 conserve ces valeurs réelles et
affiche séparément « Informations d’impact à compléter ». Les huit captures
sont ainsi conformes, distinctes et non mutatives ; aucune métrique manquante
ni aucun ODD n’a été fabriqué.

La progression reste exclusivement sourcée par Impact, la prochaine action par
la tâche future réelle et les blocages par le statut canonique `bloque`. Toutes
les mutations restent reportées à 2E-B.

## Limites backend

- aucun endpoint de fiche projet agrégée : membres et tâches conservent une
  dette N+1, atténuée par parallélisme, isolation des erreurs et cache écran ;
- les événements ne proposent pas encore de filtre serveur `project_id` ;
- les assignés nécessitent un appel par tâche et la résolution via l’annuaire ;
- `ProjectRead` ne fournit ni progression, ni permission `can_manage`, ni
  historique ;
- aucun jalon, motif de blocage, archive ou suppression projet n’existe dans le
  contrat actuel ;
- `/impact/records` n’est pas consommé : la fiche utilise uniquement
  `/impact/projects`.
