# UI Pôles — Portefeuille opérationnel et fiche en lecture seule

## Périmètre

La phase 2F-A remplace l'ancienne expérience Pôles par un portefeuille
opérationnel et une fiche dédiée exclusivement en lecture. Elle ne modifie ni
le backend, ni les permissions, ni les données. Création, édition, gestion de
l'équipe et changements de gouvernance restent explicitement reportés à 2F-B.

## Architecture

Le module est séparé en quatre couches sous `frontend/lib/features/poles` :

- `models/pole_portfolio_models.dart` centralise les présentations de type,
  statut et priorité, les agrégats de gouvernance, alertes et prochaine action ;
- `services/poles_portfolio_gateway.dart` définit le contrat injectable en
  lecture et son implémentation API avec cache de durée de vie ;
- `screens/poles_portfolio_screen.dart` orchestre la liste, les enrichissements
  parallèles, les filtres et la navigation ;
- `screens/pole_detail_screen.dart` prend en charge l'URL directe et compose les
  sources de la fiche ;
- les widgets portefeuille et fiche portent la présentation responsive, les
  états et la sémantique.

`poles_screen.dart` n'est plus qu'un point d'entrée compatible. L'ancienne
grande bottom sheet et son calcul de santé ne sont plus utilisés.

## Routes

- `/poles` : portefeuille ;
- `/poles/:poleId` : vraie page de détail, compatible avec ouverture depuis le
  portefeuille, retour, URL directe et rafraîchissement navigateur.

Le passage portefeuille → fiche transmet le gateway et l'item déjà enrichi.
Membres et tâches ne sont donc pas rechargés immédiatement. Une URL directe
recompose le même item depuis les lectures mises en cache.

## Portefeuille

À partir de 900 px, une liste dense compare nom, sigle, type, chef, adjoint,
équipe active, blocages, retards, prochaine action, échéance et porteur. En
dessous, chaque pôle devient une carte verticale sans table compressée.

Les filtres client couvrent nom/sigle, type, responsable, blocage, retard,
absence de prochaine action, de chef, d'adjoint ou d'équipe. Ils sont compacts
sur desktop et repliables sur mobile. L'action `Réinitialiser` restaure tous
les critères.

Les états loading, erreur liste, liste vide et aucun résultat sont distincts.
Une erreur membres ou tâches d'un seul pôle marque seulement les informations
concernées comme indisponibles et ne fait pas échouer les sept autres pôles.

## Gouvernance

Le chef et l'adjoint proviennent exclusivement des memberships actives portant
respectivement `chef_pole` et `adjoint_chef_pole`. Les rôles globaux ne servent
pas de repli et les anciennes valeurs `chef`/`adjoint` ne sont jamais
interprétées.

Les absences sont présentées par `Aucun chef de pôle affecté` et `Aucun adjoint
affecté`. Une source members en erreur produit `Information indisponible`. Un
pôle sans aucune membership active affiche `Aucune équipe affectée`.

## Types

La présentation est centralisée :

- `metier` → `Pôle cœur` ;
- `support` → `Pôle support` ;
- toute autre valeur → `Type non reconnu`.

Aucune valeur technique inconnue n'est rendue dans la nouvelle expérience.

## Prochaine action, blocages et retards

Les tâches viennent de `GET /api/tasks/pole/{pole_id}`.

La prochaine action est la tâche non terminale dont l'échéance future est la
plus proche. `termine`, `valide` et `annule` sont ignorés. Son titre, son
échéance et ses assignés réels sont affichés. L'absence produit `Aucune
prochaine action planifiée`; une erreur de source produit `Prochaine action
indisponible`.

Les blocages comptent uniquement `status=bloque`. Les retards exigent une
`due_date` réellement passée et un statut non terminal. Aucun motif, ETA ou
responsable de résolution n'est inventé.

## Fiche

La page dédiée comporte cinq sections :

1. Résumé : identité, type, description, objectifs, gouvernance, équipe,
   prochaine action, blocages et retards ;
2. Équipe : chef, adjoint et membres actifs sans action de mutation ;
3. Travail : tâches, statut, priorité, assignés, échéance et retard ;
4. Activité : événements portant le `pole_id` et posts filtrés par `pole_id` ;
5. Documents : documents filtrés par `pole_id`, état, catégorie, date et lien
   de consultation lorsqu'un fichier est disponible.

Les statuts `a_faire`, `en_cours`, `bloque`, `termine`, `valide`, `annule` et
les quatre priorités sont humanisés par un mapping unique. Les valeurs
inconnues deviennent `Statut non reconnu` ou `Priorité non reconnue`.

Une donnée absente produit `Non renseigné`. Une source en erreur produit un
état `indisponible`. Activité et documents distinguent aussi clairement le vide
de l'erreur.

## Relations projets et métriques

Les relations projets ne sont volontairement pas affichées. La table
`project_poles` existe, mais aucun contrat de lecture Pôles/Projets ne restitue
actuellement la relation complète et fidèle. `Impact.pole_name` ne conserve
que le premier pôle et ne peut pas servir de source officielle. Aucun compteur,
projet principal ni gestion de relation n'est fabriqué.

Le faux score `Santé du pôle`, son calcul local et toute progression
équivalente sont entièrement absents de la nouvelle expérience.

## Résilience et cache

La liste des pôles est la seule source globale bloquante. Pour chaque pôle,
membres et tâches sont chargés en parallèle et capturés indépendamment. Le
gateway mémorise pôles, événements, annuaire, membres, tâches, assignés,
documents et posts pendant sa durée de vie. Les événements sont chargés une
seule fois puis filtrés localement.

La dette N+1 reste réelle : le backend ne fournit aucun endpoint agrégé et le
frontend doit encore effectuer deux lectures d'enrichissement par pôle. Cette
dette est limitée par le parallélisme, le cache et l'isolation des erreurs ;
elle ne peut être supprimée fidèlement sans nouveau contrat backend.

## Responsive et accessibilité

Les viewports cibles sont 390×844, 768×1024, 1366×768 et 1440×900. Les filtres
se replient sur mobile, les cartes gardent une largeur unique et les actions
restent tactiles. La fiche utilise une colonne bornée et défilante, adaptée au
zoom et aux grands textes.

Des `Semantics` décrivent chaque pôle, son type, sa gouvernance, son équipe, ses
alertes, sa prochaine action, l'ouverture de fiche et les sections. Les
alertes associent icône et texte ; aucune information n'est portée uniquement
par la couleur ou un avatar.

## Tests

`frontend/test/poles_portfolio_test.dart` utilise exclusivement un gateway
mémoire. Ses 39 tests couvrent présentations, gouvernance canonique, loading,
erreur, vide, recherche, filtres, reset, équipe vide, prochaine action,
blocages, retards, erreurs partielles, absence du score Santé, navigation,
route directe, résumé, équipe, travail humanisé, activité, documents, données
partielles et largeur 390 px sans overflow.

Les 212 tests préexistants sont conservés, soit 251 tests au total.

## Runtime en lecture seule

La trace `docs/design/screenshots/ui_poles_portfolio_v1/runtime_check.json`
atteste les lectures `ui_audit` : 8 pôles, gouvernance canonique de Technique,
pôle sans équipe, tâche future, blocage, retard, événement, document et
activité. Aucun endpoint de mutation n'a été appelé.

## Validation visuelle 2F-A

Le navigateur intégré Codex est resté indisponible à cause d'une erreur
d'infrastructure lors de l'écriture des assets kernel. Les huit captures ont
donc été produites par un harness Flutter temporaire déterministe, supprimé
après usage. Ce harness a rendu les widgets applicatifs réels dans le vrai
`AppTheme.lightTheme`, avec Poppins, les tokens et l'`AppShell` EnactSpace. Il
n'a modifié aucune logique fonctionnelle et son gateway mémoire ne constitue
pas une nouvelle lecture runtime.

Les captures couvrent le portefeuille desktop, ses filtres ouverts, le
portefeuille mobile, puis les sections Résumé, Équipe, Travail,
Activité/Documents et l'équipe vide. Les dimensions, tailles et SHA-256 sont
consignés dans
`docs/design/screenshots/ui_poles_portfolio_v1/capture_state_results.json`.
Les huit hashes sont distincts. La palette observée est celle d'EnactSpace :
les couleurs Material par défaut `#6750A4`, `#FEF7FF` et `#ECE6F0` ne sont pas
les couleurs dominantes.

Docker n'a pas été redémarré pour cette validation. La preuve runtime reste
explicitement issue des traces 2F-0 déjà validées
`docs/design/screenshots/ui_poles_v1/poles_fixture_results.json` et
`docs/design/screenshots/ui_poles_v1/poles_runtime_check.json`. Elles attestent
8 pôles, la gouvernance canonique de Technique, l'absence de positions legacy,
le pôle sans équipe, la prochaine action, le blocage, le retard, l'événement,
le document, l'activité et l'absence de mutation. Une relecture runtime n'était
pas disponible pendant la capture (`runtime_recheck_available=false`).

Aucune mutation applicative n'a été effectuée. Les créations, éditions,
changements de gouvernance et autres mutations restent reportés à 2F-B.

## Limites backend et report 2F-B

- absence d'endpoint agrégé et de fiche Pôle dédiée ;
- absence de lecture contractuelle complète de `project_poles` ;
- événements sans filtre serveur `pole_id` ;
- aucune agrégation d'activité ou de statistiques par pôle ;
- liste members active sans historique des memberships retirées ;
- aucune activation, désactivation, suppression ou archive de pôle.

La création, l'édition, l'ajout/réactivation/retrait d'un membre, la nomination
ou le remplacement d'un responsable et toute future gestion de
`project_poles` restent hors périmètre et sont reportés à 2F-B.
