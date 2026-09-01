# UI Archives + Hall of Fame v1

## Architecture

Le domaine suit le flux `ArchivesScreen / fiches → ArchivesGateway → ArchivesService → API`. Les widgets n’instancient aucun service de transport. Le gateway est injectable dans le centre et dans chaque fiche, ce qui permet des tests entièrement en mémoire.

`ArchivesService` est limité au transport HTTP. `ApiArchivesGateway` agrège l’accueil en parallèle, expose l’utilisateur courant sous forme de permissions UX, garde en cache la liste Hall of Fame et centralise les règles qui ne doivent pas être dispersées dans les widgets.

## Une seule source historique

Les anciens projets, chiffres, emplois, revenus, partenaires, leçons, distinctions et résumés historiques codés en dur dans Flutter ont été physiquement supprimés. Le frontend ne fournit aucun fallback métier en cas d’échec : il montre un état erreur avec une action **Réessayer**.

Les éléments intégrés au serveur obtenus avec `include_static=true` restent des données légitimes. Ils sont affichés en lecture seule avec la mention discrète **Mémoire historique Enactus ESP**. Les identifiants UUID désignent les enregistrements DB modifiables. Cette distinction repose sur le helper unique `isPersistedArchiveRecord`.

## Centre Archives

Le centre propose une navigation responsive en chips qui revient naturellement à la ligne : Vue d’ensemble, Archives, Projets historiques, Palmarès, Compétitions, Médias, Documents, Hall of Fame et Statistiques. L’accueil combine seulement les blocs chargés en parallèle, sans GET individuel par carte.

Les archives peuvent être recherchées et filtrées par catégorie, année, statut et visibilité. Les projets historiques acceptent recherche, année et statut. Le Hall of Fame accepte année, type et mise en avant. Les enums techniques de statut, visibilité, projet et média sont humanisés.

## Archive Items et workflow

La création et l’édition couvrent titre, description, catégorie, année, visibilité, saison, pôle, projet, document, fichier existant, source, tags, mise en avant et publication. `metadata_json` n’est jamais proposé en saisie brute. Le garde-fou `is_public=true` impose une visibilité `public` ou `alumni`. Les soumissions multiples sont bloquées et une erreur garde le dialogue et ses valeurs ouverts.

La fiche montre catégorie, année, statut, visibilité, relations, source, tags, fichier, dates disponibles, validation et rejet. Les URL sont exposées par des actions humaines : **Ouvrir la source**, **Prévisualiser**, **Télécharger**.

Le workflow gérable est : Brouillon → Soumettre → Soumis → Valider ou Rejeter → Archiver. Le motif de rejet est obligatoire. L’archivage n’est pas une suppression.

## Projets historiques

La fiche projet est narrative et suit les seules données du contrat : Contexte, Le problème, La réponse, Impact et héritage, Équipe, Récompenses, Documents & médias et projet moderne lié. Aucun revenu, bénéfice, emploi, partenaire ou indicateur absent du contrat n’est reconstitué.

## Palmarès et compétitions

Le Palmarès distingue explicitement compétition, rang, résultat et année. Les compétitions présentent étape, résultat, lieu et relations disponibles. La création est proposée aux rôles autorisés ; **Modifier** n’apparaît que pour un UUID DB. Aucun bouton de suppression n’existe.

## Médias et documents historiques

Les types médias sont humanisés. Les vrais `preview_url`, `download_url` et `external_url` déclenchent respectivement prévisualisation, téléchargement ou ouverture. Aucun système d’upload spécifique n’a été inventé : le formulaire accepte un `file_id` déjà produit par un mécanisme compatible.

Les documents historiques ont une section propre et ne remplacent pas le module Documents. Leur fichier réel, source, visibilité et mise en avant sont conservés.

## Hall of Fame

La section est ordonnée selon `order_index`, puis par année. Elle valorise l’année, le type, le titre, le sous-titre et le récit réellement fourni. Le score et son libellé ne sont rendus que si `score_value` existe.

La fiche `/archives/hall-of-fame/:entryId` n’appelle aucun endpoint individuel inexistant : le gateway charge ou réutilise `GET /archives/hall-of-fame`, puis retrouve l’entrée par identifiant. L’absence produit un état introuvable propre.

La composition **Le moment / Pourquoi il compte / Trace & média** masque chaque partie sans donnée. Aucun storytelling n’est généré. **Pourquoi il compte** n’apparaît que lorsque sous-titre et description fournissent réellement cette information.

## Statistiques historiques

Chaque statistique montre label, valeur, unité, description, source, statut et date de validation disponible. Une valeur serveur non validée porte **Historique à confirmer** ; une valeur DB validée porte **Validé**.

Le gateway différencie deux écritures : un UUID est modifié par `PATCH`; une valeur serveur dont l’id est le `metric_key` est persistée par `POST` avec ce même `metric_key`. Une valeur DB existante de même clé est réutilisée afin d’éviter les doublons.

## Permissions

- Création et édition : `isEnacchef || isAdmin` côté UX.
- Validation, rejet, archivage et export : `isAdmin || isTeamLeader || isSecretary` côté UX.
- Le backend reste autoritaire pour toute requête.

## Endpoints volontairement absents

Aucune fonction ni action DELETE n’a été ajoutée. Aucun GET individuel Hall of Fame n’a été inventé. L’export utilise exclusivement `GET /archives/export/items.csv`; aucun CSV local n’est généré.

## Responsive et accessibilité

La navigation et les filtres utilisent des `Wrap`, les fiches suivent une narration verticale, les formulaires sont scrollables et les actions Material disposent de cibles tactiles d’au moins 44 px. Les vues visent 390×844, 768×1024, 1366×768 et 1440×900 sans scroll horizontal obligatoire.

## Tests

`frontend/test/archives_hall_of_fame_test.dart` utilise uniquement des gateways/services mémoire. Il couvre humanisation, distinction serveur/DB, erreur sans fallback, recherche/filtres, responsive mobile, formulaires, double-submit, permissions/export, workflow, absence de suppression, projets narratifs, collections, médias/documents, Hall of Fame listé et deep-linké, storytelling absent, et création/mise à jour des statistiques selon le type d’identifiant.

## Validation visuelle finale

Les huit captures finales sont conservées dans `docs/design/screenshots/ui_archives_hall_of_fame_v1/`. Elles couvrent le centre Archives, le workflow d’une archive DB, un projet historique serveur en lecture seule, les médias et documents, la liste et la fiche Hall of Fame, les statistiques historiques ainsi que le détail mobile en 390×844.

La capture repose sur un harness Flutter widget temporaire, un `ArchivesGateway` mémoire déterministe, le vrai `ThemeData` EnactSpace et le vrai `AppShell`. Poppins et Material Icons ont été chargées explicitement par `FontLoader` depuis des ressources locales contrôlées. Aucun navigateur intégré, backend, Docker, seed, export réel ou requête de mutation n’a été utilisé.

Le contrôle 8/8 confirme le thème EnactSpace, la hiérarchie typographique Poppins, les icônes Material sans glyphes carrés, les enums humanisés, l’absence d’identifiant UUID ou de `metadata_json` affiché, l’absence de loader bloqué et d’overflow. Les éléments serveur sont identifiés par **Mémoire historique Enactus ESP** et restent sans action d’édition ; les enregistrements DB exposent seulement les actions autorisées par le gateway mémoire. Les chiffres non validés portent **Historique à confirmer** et les récits Hall of Fame n’affichent que les données réellement fournies.

La méthode, les marqueurs atteints, les empreintes SHA-256 et les compteurs de mutations à zéro sont consignés dans `docs/design/screenshots/ui_archives_hall_of_fame_v1/capture_state_results.json`. Le harness, les fontes et les ressources temporaires de capture ont été supprimés après génération.
