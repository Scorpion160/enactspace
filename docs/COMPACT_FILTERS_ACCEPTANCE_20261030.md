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

## Preuve et contrôle restant

- Journal : `Texte collé(20261030-184119).txt`.
- SHA-256 du journal : `187805684c100d8dbb38570d72f5de11551e0b9e303bab63b11020c6142d502a`.
- Sauvegarde locale produite : `compact-filters-adb2680e95a24be582512494d3304060`.
- Marqueur final : `FILTRES_COMPACTS_ANALYSE_ET_TESTS_OK`.

La vérification fonctionnelle automatisée est validée. Les 18 nouvelles captures n'ont pas encore été transmises et examinées visuellement. Ce contrôle reste nécessaire avant de conclure sur le rendu et de préparer le build web.
