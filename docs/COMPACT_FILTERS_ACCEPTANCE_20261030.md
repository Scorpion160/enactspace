# Validation des recherches et filtres compacts — 30 octobre 2026

## Version contrôlée

- Dépôt : `Scorpion160/enactspace`.
- Branche : `feat/compact-search-filters-20261030`.
- Sources validées : `a25bc136f4ef4de917e688adaa69b666112f2f3d`.
- Installeur : `tools/sync_compact_filters_windows.ps1`.
- SHA-256 de l'installeur : `567d19ac00600f0846d42176060ea5ad3bc41cde89af44ab78bf05b12de24124`.

Ce compte rendu ne modifie aucun fichier de l'application ni de l'installeur.

## Résultats Windows

Le journal transmis par l'utilisateur confirme :

| Contrôle | Résultat |
|---|---|
| Analyse des 9 fichiers Dart du correctif | Aucune erreur ni alerte |
| Barre de recherche et filtres | 20 tests réussis |
| Régression des 23 suites de modules | 486 tests réussis |
| Total | **506 tests réussis, aucun échec** |
| Captures | 18 PNG et archive `filtres-captures.zip` créés |
| Build et déploiement | Non effectués |

Les contrôles couvrent notamment le montage sans Scaffold, la recherche et les filtres réels, la conservation des saisies, le focus, les petites largeurs, le texte à 200 %, les thèmes clair et sombre, Academy et la démo native.

Les onze échecs du premier passage ne se reproduisent plus : tâches, réinitialisation des portefeuilles, interactions avec les Archives et les Minutes, contrôle des données d'exemple et accès aux informations Academy.

## Preuves Windows

- Journal : `Texte collé(20261030-184119).txt`.
- SHA-256 du journal : `187805684c100d8dbb38570d72f5de11551e0b9e303bab63b11020c6142d502a`.
- Sauvegarde locale produite : `compact-filters-adb2680e95a24be582512494d3304060`.
- Marqueur final : `FILTRES_COMPACTS_ANALYSE_ET_TESTS_OK`.

## Contrôle visuel des 18 captures

L'archive `filtres-captures.zip` transmise ensuite par l'utilisateur a été extraite et ses 18 PNG ont été examinés individuellement le 30 octobre 2026.

- SHA-256 de l'archive : `2c314c6e141265187ebc240a7006cd8eff25298ab0e6221425e051297b9ac573`.
- 16 captures du composant partagé : largeurs de fenêtre 320, 390, 768 et 1440 pixels, thèmes clair et sombre, filtres fermés et ouverts.
- 2 captures du catalogue Academy réel à 390 pixels, en clair et en sombre, avec des données de test.
- Les images excluent les 12 pixels de marge de chaque côté de la fenêtre. Les dimensions ci-dessous correspondent à la barre elle-même.

| Fenêtre | Barre fermée | Barre ouverte | Constat visuel |
|---|---|---|---|
| 1440 px | 48 px de haut | 48 px de haut | Recherche, quatre choix rapides et deux listes sur une ligne |
| 768 px | 104 px de haut | 162 px de haut | Recherche et bouton Filtres, choix rapides dessous, listes révélées à l'ouverture |
| 390 px | 104 px de haut | 162 px de haut | Recherche et bouton accessibles, quatre choix rapides, listes sur deux colonnes |
| 320 px | 104 px de haut | 220 px de haut | Choix rapides dans une rangée défilante, listes empilées à l'ouverture |

Les captures Academy confirment l'intégration dans la page : recherche et choix rapides compacts, cartes visibles sans panneau de filtres permanent, couleurs et typographie cohérentes dans les deux thèmes. Aucun débordement involontaire n'a été constaté dans les états montrés. Le choix partiellement visible à droite à 320 pixels appartient à la rangée défilante prévue pour cette largeur. Les textes agrandis sont également couverts par les tests Windows.

Les captures isolées de la barre sont recadrées à sa boîte de rendu ; le haut des libellés flottants sur la première ligne peut dépasser ce recadrage. Elles ne montrent pas un en-tête de page rogné.

Ce contrôle visuel porte sur le composant partagé et son intégration Academy. Il ne constitue pas une inspection par capture de chacune des autres pages ; leur couverture fonctionnelle repose sur les suites de régression indiquées plus haut.

## Conclusion de validation

La vérification fonctionnelle automatisée et le contrôle visuel sont validés pour les sources `a25bc136f4ef4de917e688adaa69b666112f2f3d`. Aucun correctif supplémentaire de l'application n'a été apporté après ces contrôles. La refonte Academy et les filtres compacts sont prêts pour la préparation du build web. Aucun build ni déploiement n'a été effectué dans cette étape.
