# Recrutement interne v1 — Workbench et fiche candidat

## Objectif

La phase 2D-B1 refond la lecture, le tri et l’examen des candidatures internes.
Elle n’ajoute aucune mutation métier. Les décisions, changements de statut,
entretiens, conversions et opérations de campagne restent reportés à 2D-B2.

## Architecture

La route interne `/recruitment` charge `InternalRecruitmentScreen`. Une
`InternalRecruitmentGateway` injectable isole quatre lectures : campagnes,
liste complète, détail d’un dossier et évaluations. L’adaptateur de production
réutilise `RecruitmentService`; les tests emploient exclusivement une fausse
passerelle en mémoire et n’émettent aucune requête réelle.

L’ancien écran monolithique reste conservé dans le dépôt mais n’est plus routé.
Cette stratégie préserve le code des mutations existantes jusqu’à 2D-B2 sans
les exposer dans le nouveau workbench.

## Liste et workbench

L’en-tête présente la campagne sélectionnée, le nombre filtré, le nombre total,
le compteur de filtres et le rafraîchissement. Le workbench desktop est une
liste dense avec candidat, référence, campagne, parcours, pôle, statut,
évaluation officielle, documents et ouverture du dossier. Sur mobile, chaque
ligne devient une carte compacte sans table horizontale.

Le score calculé 0–100 n’est jamais présenté comme une note officielle. Il est
nommé « Indice de présélection » dans la fiche. La note issue des évaluations
est nommée « Évaluation » ou « Moyenne officielle » et reste sur 20.

## Filtres

La recherche, la campagne et le statut restent dans la barre principale. Les
filtres de genre, pôle, projet, département, classe, période de soumission et mode anonymisé sont
secondaires. Sur les écrans étroits, ils sont repliés derrière « Filtres » avec
« Appliquer » et « Réinitialiser ». Tous les filtres sont appliqués localement
après le chargement complet : la recherche ne remplace donc jamais la liste par
un écran blanc.

La période de soumission est filtrée localement à partir de `created_at`.

## Pagination client

Le backend ne fournit ni `page` ni `limit`. Le workbench segmente donc la liste
chargée par pages de 15 dossiers et affiche par exemple « 1–15 sur 37
candidatures ». Cette pagination est uniquement frontend. Une pagination
serveur sera nécessaire avant de traiter des volumes importants.

## Fiche candidat

Sur desktop, la fiche s’ouvre dans un panneau latéral large. Sur mobile et
tablette, elle utilise une page plein écran à une colonne. Elle recharge le
dossier avec `GET /api/recruitment/applications/{id}` et affiche :

- résumé, identité, coordonnées, campagne, statut, dates et parcours ;
- réponses longues avec intitulés humains ;
- CV, lettre et document complémentaire avec action « Consulter » ;
- évaluations, score sur 20, recommandation humanisée, commentaire et moyenne ;
- entretien avec date, lieu, jury et détails lorsqu’ils existent ;
- historique limité aux dates réellement déductibles du contrat.

Les recommandations `favorable`, `reserve` et `defavorable` deviennent
respectivement « Favorable », « Avec réserves » et « Défavorable ». Les sept
statuts réutilisent le mapping centralisé de 2D-A et aucun enum brut n’est
affiché.

## Responsive et accessibilité

La mise en page cible 390×844, 768×1024, 1366×768 et 1440×900. Les contrôles
interactifs ont une hauteur tactile minimale de 44 px. Les éléments Semantics
annoncent compteur, filtres, lignes candidat, statuts, évaluation officielle,
documents, évaluations et fermeture de la fiche. Les statuts associent texte,
icône/contexte et couleur afin de ne pas dépendre de la couleur seule.

## États

Les états initial, rafraîchissement local, aucun dossier, aucun résultat,
erreur API et accès refusé sont distincts. Une erreur ne peut pas être rendue
comme une liste vide.

## Runtime en lecture seule

Le contrôle du 21 août 2026 a utilisé `audit.admin` dans `ui_audit`, sans seed,
upsert ni mutation :

- `GET /api/recruitment/applications` : HTTP 200, 37 candidatures ;
- `AUDIT-REC-COMPLETE-001` : `under_review`, réponses et trois documents
  présents, deux évaluations, moyenne officielle 16,5/20 ;
- `AUDIT-REC-INTERVIEW-001` : `interview_scheduled`, entretien le 10 août 2026
  à 14:30, Salle Audit Synthétique A1 ;
- `mutation_performed=false`.

Le résultat structuré est conservé dans
`docs/design/screenshots/ui_recruitment_internal_v1/runtime_check.json`.

## Validation visuelle

Les huit captures de validation sont conservées dans
`docs/design/screenshots/ui_recruitment_internal_v1/`. Elles couvrent le
workbench et ses filtres en desktop/mobile, le résumé du dossier complet, les
réponses et trois documents, les deux évaluations, l’entretien sur tablette et
la fiche candidat mobile. Les huit fichiers ont une empreinte SHA-256 distincte
et leur état détaillé est consigné dans `capture_state_results.json`.

Le runtime a été contrôlé avant puis après les captures, uniquement par des
requêtes GET : 37 candidatures sont restées chargées. La pagination actuelle
reste client-side, par pages de 15. `AUDIT-REC-COMPLETE-001` est toujours
`under_review`, avec ses trois documents, ses deux évaluations et sa moyenne
officielle de 16,5/20. `AUDIT-REC-INTERVIEW-001` est toujours
`interview_scheduled`, avec l’entretien du 10 août 2026 à 14:30 dans la Salle
Audit Synthétique A1. Aucune mutation n’a été réalisée
(`mutation_performed=false`). Les actions sensibles restent reportées à 2D-B2.

## Stratégie de tests

Les tests widgets injectent une fausse passerelle et couvrent autorisation,
liste dense, chargement, erreur, vide, zéro résultat, recherche, statut,
réinitialisation, pagination locale, ouverture de fiche, résumé, réponses,
documents, évaluations, moyenne, entretien, sept statuts, absence d’enum brut,
mobile 390 px et distinction présélection/évaluation officielle. Les 26 tests
déjà validés sont conservés.

## Limites backend et suite 2D-B2

- aucune pagination serveur ni total paginé ;
- aucun véritable journal de transitions ;
- l’identifiant évaluateur n’est pas enrichi d’un nom dans le contrat actuel ;
- les dates historiques restent limitées à création et dernière mise à jour ;
- accepter, rejeter, annuler, planifier/modifier un entretien, convertir en
  utilisateur, supprimer et changer de statut restent reportés à 2D-B2 ;
- le cycle de vie complet des campagnes reste reporté à 2D-B2.
