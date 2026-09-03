# Synthèse exécutive

## Périmètre et méthode

L’analyse couvre les **332 sources cataloguées**, ramenées à **314 contenus uniques par SHA-256**. Chaque contenu normalisé unique a été lu une seule fois ; les 16 groupes de doublons exacts ont ensuite été reliés à leurs chemins d’origine avec `source_to_normalized.csv`. Le corpus contient 264 extractions textuelles au niveau source, 66 images traitées uniquement par métadonnées et 2 PDF sans couche texte. Au niveau des SHA uniques, cela représente 247 contenus textuels, 65 contenus image par métadonnées et 2 PDF illisibles sans OCR.

Les constats citent exclusivement des chemins sources d’origine. Les documents normalisés servent à la lecture, jamais comme autorité. Les classes de fiabilité utilisées sont : `OFFICIAL_REFERENCE`, `ESP_CURRENT_EVIDENCE`, `ESP_HISTORICAL`, `PROJECT_SPECIFIC`, `POLE_SPECIFIC`, `TEMPLATE`, `CONFLICTING`, `NEEDS_VALIDATION`.

## Conclusions structurantes

1. **Le corpus décrit une organisation mature, mais sans référentiel unique.** Les rôles, projets, décisions, budgets, tâches et preuves existent dans des fichiers séparés. Les règles locales, le cadrage EnactSpace et les pratiques 2024-2026 ne sont pas toujours synchronisés. Sources : `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf`, `documents/enactspace_cahier_cadrage.pdf`, `PV 20.05.26.pdf`.
2. **Le besoin prioritaire n’est pas de numériser davantage de texte, mais de relier les objets métier.** Une décision de réunion devrait produire des tâches, un budget approuvé, une mission, des livrables et des preuves d’impact traçables. Sources : `Pole Veille/Bilan Pole Veille/mai/bilan_pole_veille_enactus.pdf`, `documents/Pole Tech 2026/rapport_voyage_pole_technique_terrasen_2026.pdf`, `DOCS/Enactus-Impact-Reporting-Evaluation-Guide-2025-2026.pdf`.
3. **Le portefeuille de projets est riche mais son état courant doit être validé.** Aquatus et Terrasen disposent de dossiers techniques et budgétaires substantiels ; Shery est documenté comme actif dans le cadrage mais comme candidat au transfert dans une preuve plus récente ; Mën Nañ, CAJOR et Dimbali ont des niveaux de maturité et d’actualité différents. Sources : `documents/Enactus 2025/PROJETS/Aquatus/Fiche de projet/Document de synthése AQUATUS[1] (1).pdf`, `documents/Projet TERRASEN/document projet terrasen.pdf`, `PV 20.05.26.pdf`, `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf`.
4. **La mesure d’impact doit être strictement probante.** La référence 2025-2026 sépare ressources, productions, résultats, impact durable et projections, et interdit de présenter des estimations comme des réalisations. Toute métrique doit porter une méthode, une période, une source et une preuve validée. Source : `DOCS/Enactus-Impact-Reporting-Evaluation-Guide-2025-2026.pdf`.
5. **La confidentialité impose un import sélectif.** Les 135 candidats à revue de confidentialité ne doivent pas être importés en bloc. Les PV, listes, bilans de présence et documents terrain peuvent contenir des données individuelles inutiles au produit. Seules les données minimales, validées et affectées à un périmètre d’accès doivent être migrées. Sources : `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf`, `Pole Veille/Bilan Pole Veille/juin/bilan_pole_veille_juin_2026_enactus.pdf`, `documents/enactspace_cahier_cadrage.pdf`.

## Domaines couverts

Le corpus permet d’étudier : gouvernance, membres et leadership, opérations des sept pôles observés, portefeuille projets, finances, fundraising et partenariats, impact, compétitions, communication, événements, formation, archives et passation. Les projets disposant du plus grand nombre de pièces dédiées sont Terrasen (33 SHA liés), Aquatus (19), Shery (13), Mën Nan/Nagn (10), CAJOR (8) et Dimbali (7). Ces décomptes sont multi-étiquettes et ne préjugent ni du statut actuel ni de la qualité des preuves.

## Décisions recommandées

- **P0 — Gouvernance des données :** désigner une fiche canonique par projet et un propriétaire de validation ; conserver les variantes comme archives.
- **P0 — Impact :** ne publier aucune métrique calculée par défaut ; exiger méthode, période, preuve et validation.
- **P0 — Documents :** introduire provenance, version, relation canonique/doublon et niveau de fiabilité.
- **P0 — Finance projet :** relier budget, approbation, transaction réelle, justificatif et écart.
- **P0 — Migration :** imposer prévisualisation, détection des doublons, minimisation et validation humaine avant application.
- **P1 — Opérations :** convertir les décisions de réunion en tâches reliées, avec responsable de rôle, échéance et preuve.

## Limites

Les fichiers `documents/Enactus 2025/Pôle Tech/Projets en cours/granuleuse.pdf` et `documents/Enactus 2025/PROJETS/Shery/shery_s teams.pdf` n’ont pas de couche texte exploitable. Aucun constat de contenu n’en est tiré. Les images sans OCR contribuent uniquement à la couverture et à l’inventaire des actifs, jamais à une conclusion métier.

## Livrables liés

Les rapports `01` à `08` décrivent le fonctionnement métier ; `09` compare le corpus au produit ; `10` priorise 18 opportunités ; `11` sépare les imports possibles des données à ne pas migrer ; `12` qualifie fiabilité, doublons et conflits ; `13` apporte la preuve de couverture exhaustive.
