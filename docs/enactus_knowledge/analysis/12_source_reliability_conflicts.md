# Fiabilité des sources et conflits

## Classification primaire

Une classification déterministe de triage a été appliquée aux 314 SHA uniques. Elle ne remplace pas une décision documentaire.

| Classe | SHA uniques | Usage |
|---|---:|---|
| `OFFICIAL_REFERENCE` | 18 | guide externe ou Enactus à appliquer selon édition et territoire |
| `ESP_CURRENT_EVIDENCE` | 8 | preuve opérationnelle 2026, limitée à son objet |
| `ESP_HISTORICAL` | 39 | mémoire ESP, non applicable comme politique courante |
| `PROJECT_SPECIFIC` | 78 | pièce limitée au projet et à la période |
| `POLE_SPECIFIC` | 86 | pièce limitée au pôle et à la période |
| `TEMPLATE` | 12 | structure à nettoyer avant réemploi |
| `CONFLICTING` | 4 | contenu impliqué directement dans un conflit structurant |
| `NEEDS_VALIDATION` | 69 | 65 métadonnées image, 2 PDF sans texte et 2 contenus non classables automatiquement |
| **Total** | **314** | |

## Conflits structurants

| ID | Sujet | Versions en tension | Décision requise |
|---|---|---|---|
| C-01 | Nombre et noms des pôles | le texte local annonce six mais en énumère sept ; le cadrage utilise une autre nomenclature | liste canonique et alias par saison |
| C-02 | Noms de projets | Terrasen/Terassen, Shery/Cherry, Mën Nañ/Mën Nan/Mën Nagn | nom canonique et alias recherchables |
| C-03 | Statut Shery | actif dans le cadrage ; transfert ou vente envisagé en 2026 | statut daté, type de transition et autorité |
| C-04 | Portefeuille courant | le cadrage 2026 reprend des statuts initiaux ; la réunion 2026 redéfinit certains objectifs | revue officielle de tout le portefeuille |
| C-05 | Périmètre CAJOR/Mën Nan | dossiers sur moringa/noix de cajou présents dans plusieurs arbres | séparation, filiation ou fusion explicite |
| C-06 | Règles de participation | texte local, cadrage et pratiques de suivi ne portent pas la même preuve d’actualité | politique datée et paramètres par saison |
| C-07 | Mesures d’impact | résultats attendus, récits historiques et projections sont parfois présentés côte à côte | dictionnaire d’indicateurs et validation par période |
| C-08 | Versions du cadrage | deux SHA distincts existent sous trois chemins, dont un groupe de doublons exacts | comparer, choisir la version canonique, archiver l’autre |

Sources : `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf`, `documents/enactspace_cahier_cadrage.pdf`, `documents/enactspace_cahier_cadrage/enactspace_cahier_cadrage.pdf`, `PV 20.05.26.pdf`, `documents/Projet CAJOR/CAJOR.docx`, `documents/Enactus 2025/PROJETS/Mën nañ/Moringa et Noix de Cajou.pdf`.

## Groupes de doublons exacts

Les chemins suivants sont des **candidats** canoniques, choisis pour leur emplacement métier ; le propriétaire doit confirmer.

| # | Candidat canonique | Alias exacts à conserver comme relations |
|---:|---|---|
| 1 | `documents/Projet TERRASEN/Plan_de_voyage_Repartition_travail_TERRASEN_2026.pdf` | `documents/Pole Tech 2026/Plan_de_voyage_Repartition_travail_TERRASEN_2026.pdf` |
| 2 | `documents/enactspace_cahier_cadrage.pdf` | `enactspace_cahier_cadrage.pdf` |
| 3 | `documents/Enactus 2025/PROJETS/Terrasen/PV de réunion/PV 13-01-2025.pdf` | même dossier, variante `(1)` |
| 4 | `documents/Projet CAJOR/POSTER CAJOR.pptx` | copie sous `documents/Enactus 2025/Pôle Chimie/CAJOR/` |
| 5 | `documents/Projet CAJOR/CAJOR.docx` | copie sous `documents/Enactus 2025/Pôle Chimie/CAJOR/` |
| 6 | `documents/Projet CAJOR/POSTER DU PROJET CAJOR.pdf` | copie sous `documents/Enactus 2025/Pôle Chimie/CAJOR/` |
| 7 | `documents/Enactus 2025/PROJETS/Aquatus/Recap OSTX/WEEK2_OSTX_Resume (2).pdf` | variante `(3)` |
| 8 | `documents/Projet CAJOR/PÔLE CHIMIE.docx` | copie sous `documents/Enactus 2025/Pôle Chimie/CAJOR/` |
| 9 | `documents/Projet CAJOR/IMG-20241231-WA0007.jpg` | copie sous `documents/Enactus 2025/Pôle Chimie/CAJOR/` |
| 10 | `documents/Enactus 2025/PROJETS/Mën nañ/PV Mën Nan 11 Mars.pdf` | `Men Nan/PV Mën Nan 11 Mars.pdf` |
| 11 | `documents/Enactus 2025/PROJETS/Aquatus/Recap OSTX/ostx_recap - week3 (1).pdf` | variante `(2)` |
| 12 | `documents/Enactus 2025/PROJETS/Terrasen/Budgets/Budgetisation syst irrigation.pdf` | copie sous `documents/Enactus 2025/Pôle Tech/Budgétisations/` |
| 13 | `documents/Projet CAJOR/Budgétisation CAJOR.xlsx` | copie sous `documents/Enactus 2025/Pôle Chimie/CAJOR/` |
| 14 | `documents/Projet CAJOR/POSTER DU PROJET PPT.pptx` | copie sous `documents/Enactus 2025/Pôle Chimie/CAJOR/` |
| 15 | `documents/Enactus 2025/PROJETS/Mën nañ/Moringa et Noix de Cajou.pdf` | copies sous Pôle Chimie/Rapports et `Men Nan/` |
| 16 | `documents/Projet CAJOR/Cahier des charges presse.pdf` | copies sous Pôle Chimie/CAJOR et Pôle Tech/Projets en cours |

Source exhaustive : `docs/enactus_knowledge/catalog/duplicates_exact.csv`.

## Douze validations métier nécessaires

1. version adoptée et date d’effet du texte de gouvernance local ;
2. liste des pôles et alias pour la saison courante ;
3. permissions exactes du Faculty Advisor ;
4. règle courante d’appartenance pôle/projet ;
5. noms et statuts actuels des projets ;
6. nature du transfert ou de la graduation de Shery ;
7. frontière fonctionnelle entre CAJOR et Mën Nan ;
8. valeurs et preuves des métriques historiques ;
9. paramètres financiers et seuils d’approbation courants ;
10. propriétaire des actifs à la graduation d’un projet ;
11. droits de diffusion des médias et supports ;
12. durées de conservation par catégorie de données.

## Politique de résolution

La récence seule ne suffit pas. L’ordre de décision est : autorité compétente, preuve d’approbation, portée, date d’effet, cohérence avec une référence officielle, puis récence. Un conflit reste visible jusqu’à décision ; aucune fusion de texte ni moyenne de chiffres n’est autorisée.
