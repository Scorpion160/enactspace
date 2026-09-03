# Archives et gestion des connaissances

## Diagnostic

Le corpus est une mémoire opérationnelle riche : guides, textes locaux, PV, budgets, feuilles de route, rapports, recettes, recherches, supports de compétition, images et actifs de marque. Sa faiblesse n’est pas l’absence de documents mais l’absence d’un graphe de provenance et de décisions : une pièce peut apparaître dans un dossier pôle et projet, une version peut être renommée sans être révisée, et un document historique peut sembler actuel.

Les 332 chemins correspondent à 314 SHA uniques. Les 16 groupes de doublons exacts concernent notamment le cadrage, Terrasen, Aquatus, Mën Nan et CAJOR. Les doublons exacts ne doivent pas être republiés comme documents distincts ; leurs emplacements d’origine restent des alias de classement. Source de contrôle : `docs/enactus_knowledge/catalog/duplicates_exact.csv` ; exemples originaux : `documents/Enactus 2025/Pôle Chimie/CAJOR/CAJOR.docx`, `documents/Projet CAJOR/CAJOR.docx`.

## Modèle de connaissance recommandé

| Objet | Rôle |
|---|---|
| Source | Fichier reçu, chemin d’origine, SHA, date et classification. |
| Document logique | Identité métier commune à plusieurs versions ou formats. |
| Version | Contenu figé, auteur institutionnel si connu, période, statut et preuve d’approbation. |
| Relation | doublon exact, dérivé, remplace, traduit, annexe, preuve de, lié à. |
| Référence canonique | Version approuvée pour un usage et une période donnés. |
| Décision | Autorité, date, périmètre et motif du choix canonique. |
| Rétention | Conservation, archivage, restriction ou suppression selon catégorie. |

## Classes de traitement

- **Canonique :** règle ou modèle approuvé, daté, propriétaire identifié et périmètre explicite.
- **Historique :** utile pour la mémoire et l’apprentissage, jamais appliqué comme règle courante sans validation.
- **Projet/pôle :** preuve locale limitée à son périmètre et à sa période.
- **Modèle :** structure réutilisable sans valeurs métier héritées.
- **Doublon exact :** un seul binaire, plusieurs alias de chemin.
- **Conflit :** aucune promotion automatique ; décision requise.
- **Métadonnées seulement :** actif inventorié, contenu non interprété.
- **Restreint :** accès au besoin de connaître, export et indexation limités.

## Processus KM-01 — Publication d’une référence canonique

- **PROCESS:** qualifier, dédupliquer, réviser et publier un document de référence.
- **ACTORS:** déposant, propriétaire métier, documentaliste/archives, validateur, administrateur de droits.
- **INPUTS:** fichier, contexte, catégorie, saison, périmètre, version antérieure et preuve d’approbation.
- **STEPS:** calculer le SHA ; rechercher les doublons ; classer ; détecter les données à risque ; relier au document logique ; comparer la version ; faire réviser ; approuver ; publier ; archiver la version remplacée.
- **APPROVALS:** validation métier, contrôle de confidentialité et validation de visibilité sont distincts.
- **OUTPUTS:** version canonique, relations de provenance, alias de chemins, journal de décision et politique de rétention.
- **DATA:** SHA, titre, type, version, saison, propriétaire de rôle, périmètre, statut, relations, visibilité, dates et décision.
- **CURRENT_MANUAL_TOOLS:** arborescences Drive/locales, noms de fichiers et copies.
- **PAIN_POINTS:** doublons, noms ambigus, variantes non datées, recherche par emplacement et exposition potentielle de données inutiles.
- **ENACTSPACE_AUTOMATION_OPPORTUNITY:** déduplication par SHA, graphe de versions, revue de confidentialité, workflow canonique et recherche filtrée par fiabilité.

Sources : `DOCS/Building-an-Enactus-Team.pdf`, `documents/enactspace_cahier_cadrage.pdf`, `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf`.

## Processus KM-02 — Passation annuelle

- **PROCESS:** clôturer une saison et transmettre une mémoire exploitable.
- **ACTORS:** gouvernance sortante, responsables de pôles/projets, finance, archives, équipe entrante.
- **INPUTS:** objectifs, décisions ouvertes, projets, budgets, preuves, accès, risques, documents canoniques et leçons.
- **STEPS:** geler le périmètre ; compléter les dossiers ; rapprocher ; classer ; valider les bilans ; archiver ; créer la nouvelle saison ; transférer les droits ; faire accepter la passation.
- **APPROVALS:** chaque propriétaire métier valide son dossier ; la gouvernance accepte la clôture ; l’administration confirme les droits.
- **OUTPUTS:** archive de saison, dossiers de pôle/projet, points ouverts, export et attestation de passation.
- **DATA:** saison, entité, responsable de rôle, checklist, statut, exceptions, versions et preuves.
- **CURRENT_MANUAL_TOOLS:** dossiers partagés et documents de bilan.
- **PAIN_POINTS:** connaissance tacite, documents orphelins, responsabilités et accès non clôturés.
- **ENACTSPACE_AUTOMATION_OPPORTUNITY:** checklist de clôture, contrôle de complétude, export, copie sélective vers la nouvelle saison et révocation planifiée.

Sources : `DOCS/Building-an-Enactus-Team.pdf`, `documents/enactspace_cahier_cadrage.pdf`.

## Références candidates

- Références Enactus : guides sous `DOCS/`, à conserver avec édition, provenance et portée géographique.
- Gouvernance ESP : `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf`, à valider avant promotion canonique.
- Histoire : `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf`, canonique possible pour la mémoire après revue factuelle, mais pas pour les statuts actuels.
- Cadrage produit : les variantes de `enactspace_cahier_cadrage.pdf` doivent être comparées et une seule version désignée.
- Modèles : budgets, PV, tests et voyages doivent être nettoyés de toute valeur héritée avant publication comme gabarits.
