# Opportunités d’import de données

## Principe

Un document présent dans le corpus n’est pas automatiquement une source importable. Tout import suit : sélection de la source canonique, prévisualisation, mappage, détection des doublons, minimisation, validation humaine, application, rapport et possibilité de revenir sur le lot. Aucun import automatique de données personnelles de bénéficiaires, candidatures, observations individuelles ou pièces de signature n’est recommandé.

## Imports envisageables

| Lot | Source d’origine | Destination | Données proposées | Contrôles obligatoires | Décision |
|---|---|---|---|---|---|
| Catalogue documentaire | `docs/enactus_knowledge/catalog/source_to_normalized.csv` | Documents/Archives | chemin, SHA, extension, relation de doublon | source canonique, visibilité, propriétaire, revue de confidentialité | importer les métadonnées après revue |
| Projets actuels | `documents/enactspace_cahier_cadrage.pdf`, `PV 20.05.26.pdf` | Projets | nom canonique, alias, statut, saison | arbitrage gouvernance ; ne pas importer le statut automatiquement | saisie assistée |
| Projets historiques | `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf` | Archives | nom, période, résumé, statut historique | revue factuelle, séparation récit/preuve | saisie éditoriale |
| Budgets | `documents/Enactus 2025/Pôle Chimie/Budgétisations/Budgétisation projets.xlsx` | Finance/Projets | version, postes, quantités, montants estimés | devise, date des prix, totaux, périmètre, aucune transaction créée | prévisualisation seulement |
| Budgets projet | `documents/Enactus 2025/PROJETS/Aquatus/Budgétisations AQUATUS/Prix matériels .xlsx` | Finance/Projets | lignes estimatives | doublons, unité, période, validation propriétaire | lot révisé |
| Événements/missions | `documents/Pole Tech 2026/Plan_de_voyage_Repartition_travail_TERRASEN_2026.pdf` | Événements | dates, objet, rôles, livrables | retirer les personnes non nécessaires, valider la période | métadonnées minimales |
| Rapports de mission | `documents/Pole Tech 2026/rapport_voyage_pole_technique_terrasen_2026.pdf` | Documents/Événements | titre, projet, période, catégorie, fichier | accès, droits média, version finale | import documentaire |
| Indicateurs d’impact | `DOCS/2025-2026-Standardized-Impact-Page.pdf` | Impact | définitions et gabarits, pas de valeurs ESP | version, droits, validation impact | modèle uniquement |
| Valeurs d’impact | `documents/Projet TERRASEN/document projet terrasen.pdf` | Impact | propositions de métriques en brouillon | période, méthode, preuve, dédoublonnage, validation indépendante | aucune valeur auto-validée |
| Ressources Academy | `documents/formations/entreprenariat social/support_formation_entrepreneuriat_social.pdf` | Academy | titre, objectifs, source, version | droits de réutilisation, revue pédagogique | métadonnées puis édition |
| Modèles de documents | `documents/Enactus 2025/Pôle Chimie/Bilans/Modèle rapport de voyage.docx` | Documents/Templates | structure nettoyée | supprimer valeurs héritées, versionner, approuver | modèle contrôlé |
| Organisations partenaires | `documents/Enactus 2025/PROJETS/Aquatus/Partenariats et fundraising/Tableau de bord Partenariat.docx` | CRM partenaires | organisation, segment, étape institutionnelle | ne pas reprendre les coordonnées personnelles ; vérifier l’actualité | revue ligne par ligne |
| Décisions et tâches | `PV 20.05.26.pdf` | Réunions/Tâches | décision, rôle, échéance, projet | extraction proposée en brouillon, confirmation humaine | pas d’application automatique |
| Actifs visuels | `img/logos_enactus_visibles/README.txt` | Archives média | nom d’actif, dimensions, SHA | droits, projet associé, statut public | catalogue seulement |

## Données à ne pas importer automatiquement

| Catégorie | Motif | Traitement acceptable |
|---|---|---|
| Identités de bénéficiaires | inutiles aux agrégats et à haut risque | preuves restreintes hors tableau de bord ; agrégats validés |
| Coordonnées personnelles extraites des documents | finalité et actualité inconnues | nouveau contact institutionnel obtenu et consenti |
| Signatures et autorisations | preuve sensible, portée juridique | fichier restreint si conservation obligatoire, jamais indexé en clair |
| Observations individuelles de comportement ou de participation | risque de stigmatisation | décision administrative minimale dans un espace habilité |
| Candidatures historiques | absence de finalité actuelle | ne pas migrer ; conserver selon politique séparée si obligation |
| Feuilles de présence nominatives historiques | aucun besoin produit démontré | statistiques agrégées ou archivage restreint |
| Valeurs d’impact extraites d’un récit | méthode et période insuffisantes | créer une proposition à confirmer, jamais une valeur réalisée |
| Prix anciens | obsolescence | référence datée, non réutilisée comme prix courant |
| Procédures techniques ou alimentaires anciennes | sécurité et version inconnues | document historique jusqu’à validation experte |

## Processus DATA-01 — Import en deux étapes

- **PROCESS:** prévisualiser puis appliquer un lot validé.
- **ACTORS:** préparateur, propriétaire métier, contrôleur confidentialité, applicateur autorisé.
- **INPUTS:** source canonique, schéma cible, règles de mapping, clé de déduplication et politique de rétention.
- **STEPS:** charger en zone temporaire ; détecter format et doublons ; mapper ; exclure les champs interdits ; afficher erreurs ; corriger ; obtenir les validations ; appliquer ; produire le rapport ; contrôler l’échantillon.
- **APPROVALS:** propriétaire métier et contrôleur confidentialité avant application ; droits renforcés pour appliquer.
- **OUTPUTS:** lot, lignes acceptées/rejetées, raisons, identifiants créés et journal.
- **DATA:** source/SHA, mapping, acteur de rôle, dates, erreurs, exclusions et résultat.
- **CURRENT_MANUAL_TOOLS:** fichiers Excel/CSV, dossiers et copies.
- **PAIN_POINTS:** doublons, colonnes variables, données non nécessaires, absence de retour sur erreur.
- **ENACTSPACE_AUTOMATION_OPPORTUNITY:** moteur commun preview/apply, règles par type, rapport de confidentialité et idempotence par SHA+ligne.

Sources : `documents/enactspace_cahier_cadrage.pdf`, `DOCS/Budgeting-Financial-Management.pdf`.
