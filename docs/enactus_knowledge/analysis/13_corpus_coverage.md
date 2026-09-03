# Couverture du corpus

## Preuve d’exhaustivité

- **Sources cataloguées : 332**.
- **SHA-256 uniques lus : 314**.
- **Groupes de doublons exacts : 16**, représentant 34 chemins sources et 16 SHA.
- **Candidats larges à revue de confidentialité : 135**.
- **Caractères extraits déclarés pour les SHA uniques : 1 858 297**.
- **Caractères effectivement parcourus dans les 314 Markdown normalisés, métadonnées comprises : 2 004 539**.
- **Empreinte SHA-256 de la liste triée des 314 SHA :** `1F603B9810C325D3C49A1333A6E75B5A1DA3640BEE62F899E7CBCF39E86F1C52`.

La lecture a regroupé `source_to_normalized.csv` par SHA, ouvert chacun des 314 chemins normalisés une fois, puis réappliqué tous les chemins d’origine pour la classification multi-étiquettes. Aucun doublon exact n’a été analysé une seconde fois.

## Statut d’extraction

| Niveau | Texte OK | Métadonnées seulement | Sans couche texte | Total |
|---|---:|---:|---:|---:|
| Chemins sources | 264 | 66 | 2 | 332 |
| SHA uniques | 247 | 65 | 2 | 314 |

### Documents explicitement illisibles

1. `documents/Enactus 2025/Pôle Tech/Projets en cours/granuleuse.pdf`
2. `documents/Enactus 2025/PROJETS/Shery/shery_s teams.pdf`

Statut : `NO_TEXT_LAYER`. Aucun OCR n’a été exécuté et **aucune affirmation de contenu** de ces deux fichiers n’apparaît dans les rapports.

## Formats — SHA uniques

| Format | Nombre |
|---|---:|
| PDF | 197 |
| PNG | 53 |
| DOCX | 33 |
| JPG | 12 |
| XLSX | 11 |
| ODP | 2 |
| ODT | 2 |
| PPTX | 2 |
| RTF | 1 |
| TXT | 1 |
| **Total** | **314** |

## Domaines primaires — SHA uniques

Cette partition est exclusive et totalise 314.

| Domaine primaire | Nombre |
|---|---:|
| Opérations de pôles | 97 |
| Projets | 79 |
| Médias, métadonnées seulement | 65 |
| Opérations générales du club | 32 |
| Références et gouvernance | 30 |
| Événements, formation, compétitions | 8 |
| PDF sans couche texte | 2 |
| Autre connaissance | 1 |
| **Total** | **314** |

## Couverture par pôle — multi-étiquettes

| Pôle | SHA liés |
|---|---:|
| Chimie | 57 |
| Technique | 22 |
| Gestion | 13 |
| Communication | 10 |
| Veille | 8 |
| Organisation | 7 |
| IT | 5 |

La somme dépasse le nombre de documents de pôle car des doublons ou pièces projet sont reliés à plusieurs arbres d’origine.

## Couverture par projet — multi-étiquettes

| Projet | SHA liés |
|---|---:|
| Terrasen/Terassen | 33 |
| Aquatus | 19 |
| Shery/Cherry | 13 |
| Mën Nañ/Mën Nan/Mën Nagn | 10 |
| CAJOR | 8 |
| Dimbali | 7 |

Les projets historiques sans dossier textuel dédié sont couverts par `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf`. Les logos sont comptés comme actifs média sans inférence de contenu.

## Couverture temporelle primaire

| Période attribuée par chemin | Nombre |
|---|---:|
| Opérations 2024-2025 | 219 |
| Références 2024-2026 | 20 |
| Courant/2026 | 13 |
| Historique 2016 | 10 |
| Non daté/autre | 52 |
| **Total** | **314** |

La période est une classification de couverture, pas une date d’effet. Un même contenu peut raconter plusieurs années ; les rapports conservent alors son statut historique.

## Types documentaires — multi-étiquettes

| Type détecté par chemin | Nombre |
|---|---:|
| PV / compte rendu | 104 |
| Média / identité | 71 |
| Budget / prévisions | 38 |
| Guide / référence / manuel | 27 |
| Technique / recherche / recette | 21 |
| Rapport / bilan | 19 |
| Plan / feuille de route / calendrier | 16 |
| Projet / fiche / pitch | 11 |
| Modèle / formulaire / questionnaire | 10 |
| Produit EnactSpace | 4 |

## Signaux de contenu — SHA uniques

Les occurrences servent à vérifier la couverture thématique, pas à conclure automatiquement : réunion/PV 119 ; tâches/actions 86 ; budget/finance 111 ; impact 104 ; partenariats 48 ; recrutement 39 ; communication 82 ; événements 88 ; formation 142 ; archives/passation 11 ; approbation/validation 79 ; outils manuels 53.

## Matrice rapports × corpus

| Rapport | Domaine couvert | Principales familles sources |
|---|---|---|
| `00` | synthèse | tout le corpus et catalogues |
| `01` | gouvernance | textes ESP, organigramme, cadrage, PV récent |
| `02` | membres/recrutement | guides équipe/leadership et cadrage |
| `03` | pôles | sept arbres de pôles, bilans 2026 |
| `04` | projets | six dossiers principaux et histoire |
| `05` | finance/partenariats | guides, budgets, dossiers partenaires |
| `06` | impact/compétitions | guide 2025-2026, projets, World Cup |
| `07` | communication/événements/formation | PR, communication, voyages, supports |
| `08` | archives | doublons, histoire, modèles et cadrage |
| `09` | écarts produit | cadrage, corpus métier et implémentation existante |
| `10` | backlog | constats des rapports `01` à `09` |
| `11` | imports | catalogues et sources structurées |
| `12` | fiabilité/conflits | 314 SHA, 16 groupes de doublons, sources en tension |
| `13` | couverture | quatre catalogues et 314 normalisés |

## Confidentialité de l’analyse

Les rapports ne reproduisent ni adresse personnelle, ni téléphone, ni courriel, ni signature, ni date de naissance, ni identité de bénéficiaire, ni observation individuelle sensible. Les noms de personnes trouvés dans les sources ont été remplacés par des rôles dans l’analyse. Les chemins sources comportant un nom de projet ou d’organisation sont conservés pour la traçabilité ; aucun chemin cité n’est utilisé pour inférer une donnée personnelle.
