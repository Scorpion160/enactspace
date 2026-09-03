# Backlog d’opportunités produit

## Distribution

Le backlog contient **18 opportunités** : **P0 = 5**, **P1 = 7**, **P2 = 5**, **P3 = 1**. La priorité combine risque de vérité/confidentialité, valeur opérationnelle et dépendances.

## P0

### OP-01 — Impact strictement probant

- **Sources :** `DOCS/Enactus-Impact-Reporting-Evaluation-Guide-2025-2026.pdf`, `DOCS/2025-2026-Standardized-Impact-Page.pdf`
- **Utilisateurs / fonction :** responsables impact et projets ; supprimer tout impact réalisé dérivé ou forcé, agréger seulement les valeurs validées.
- **Données / permissions :** définition, période, valeur, méthode, preuve, statut ; saisie projet, validation impact/gouvernance, lecture selon visibilité.
- **Relation module / valeur :** Impact, Dashboard, Compétitions ; vérité des rapports et prévention du double comptage.
- **Complexité / risques / priorité :** moyenne ; migration des vues et distinction zéro/non renseigné ; **P0**.

### OP-02 — Provenance et version canonique des documents

- **Sources :** `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf`, `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf`
- **Utilisateurs / fonction :** archives et propriétaires métier ; SHA, document logique, versions, relations et décision canonique.
- **Données / permissions :** provenance, version, saison, relations, classification ; dépôt contrôlé, validation métier et confidentialité séparées.
- **Relation module / valeur :** Documents, Archives ; réduit doublons, ambiguïtés et règles périmées.
- **Complexité / risques / priorité :** élevée ; reprise des documents existants ; **P0**.

### OP-03 — Référentiel canonique du portefeuille

- **Sources :** `documents/enactspace_cahier_cadrage.pdf`, `PV 20.05.26.pdf`, `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf`
- **Utilisateurs / fonction :** gouvernance et chefs projet ; normaliser nom, alias, statut, saison, propriété et décision de transition.
- **Données / permissions :** projet, alias, statut daté, motif, propriété ; édition gouvernance, proposition responsable projet.
- **Relation module / valeur :** Projets, Archives, Impact ; empêche les confusions Shery/Cherry, Terrasen/Terassen et Mën Nan/Nagn.
- **Complexité / risques / priorité :** moyenne ; fusion d’identités et références ; **P0**.

### OP-04 — Budget versionné et rapprochement réel

- **Sources :** `DOCS/Budgeting-Financial-Management.pdf`, `documents/Enactus 2025/PROJETS/Terrasen/Budgets/Budgétisation Terrasen agro et IT (1).xlsx`
- **Utilisateurs / fonction :** finance, pôles et projets ; lignes budgétaires, révisions, demandes, transactions, justificatifs et écarts.
- **Données / permissions :** montants, versions, preuves, décisions ; séparation demande, approbation, paiement et contrôle.
- **Relation module / valeur :** Finance, Projets, Événements ; responsabilité financière et rapports fiables.
- **Complexité / risques / priorité :** élevée ; règles de seuil et migration ; **P0**.

### OP-05 — Import contrôlé et respectueux de la vie privée

- **Sources :** `documents/enactspace_cahier_cadrage.pdf`, `Pole Veille/Bilan Pole Veille/juin/bilan_pole_veille_juin_2026_enactus.pdf`
- **Utilisateurs / fonction :** administrateurs et responsables de données ; prévisualiser, mapper, minimiser, détecter doublons et appliquer après validation.
- **Données / permissions :** uniquement champs approuvés ; import à deux rôles, journal et rapport d’exclusion.
- **Relation module / valeur :** Membres Import, Documents, Archives ; migration sûre sans import massif de données personnelles.
- **Complexité / risques / priorité :** élevée ; faux positifs et qualité des sources ; **P0**.

## P1

### OP-06 — Stage-gates projet et évaluation des besoins

- **Sources :** `DOCS/Enactus-Project-Guide.pdf`, `DOCS/Needs-Assessment-Template-French.pdf`
- **Utilisateurs / fonction :** porteurs et gouvernance ; idée→besoin→faisabilité→pilote→actif→gradué/archivé.
- **Données / permissions :** gates, critères, risques, décisions ; proposition projet, approbation gouvernance.
- **Relation module / valeur :** Projets ; décisions explicites et portefeuille comparable.
- **Complexité / risques / priorité :** moyenne ; rigidité excessive à éviter ; **P1**.

### OP-07 — Décision de réunion vers tâche

- **Sources :** `PV 20.05.26.pdf`, `documents/Enactus 2025/PVs de Réunions/PV 29.03.2025.pdf`
- **Utilisateurs / fonction :** secrétariat, responsables, membres ; registre de décisions et conversion en tâches reliées.
- **Données / permissions :** décision, rôle responsable, échéance, preuve ; validation du PV avant diffusion.
- **Relation module / valeur :** Événements, Documents, Tâches ; réduit les actions perdues.
- **Complexité / risques / priorité :** moyenne ; éviter l’extraction automatique non relue ; **P1**.

### OP-08 — Dossier de mission terrain

- **Sources :** `documents/Pole Tech 2026/rapport_voyage_pole_technique_terrasen_2026.pdf`, `documents/Enactus 2025/Voyages/Voyage 14 au 18 Mars 2025/Bugetisation VOYAGE 14mars .pdf`
- **Utilisateurs / fonction :** organisation, finance, projet ; proposition, risques, participants nécessaires, budget, rapport et suites.
- **Données / permissions :** mission, logistique, coûts, livrables ; accès restreint aux détails participants.
- **Relation module / valeur :** Événements, Finance, Documents, Impact ; chaîne terrain complète.
- **Complexité / risques / priorité :** moyenne ; usage mobile et données locales ; **P1**.

### OP-09 — CRM partenaires institutionnel

- **Sources :** `DOCS/Fundraising-101.pdf`, `documents/Enactus 2025/PROJETS/Aquatus/Partenariats et fundraising/Tableau de bord Partenariat.docx`
- **Utilisateurs / fonction :** partenariats, finance, projets ; pipeline, accords, contributions, contreparties et rapports.
- **Données / permissions :** organisation, étape, engagements ; équipe partenariat, approbation gouvernance/finance.
- **Relation module / valeur :** nouveau sous-module Finance/Projets ; continuité relationnelle.
- **Complexité / risques / priorité :** moyenne ; minimiser les contacts individuels ; **P1**.

### OP-10 — Instruments d’impact versionnés

- **Sources :** `DOCS/Enactus-Impact-Reporting-Evaluation-Guide-2025-2026.pdf`, `documents/Enactus 2025/WORD CUP🏆 THAILANDE 2025/6. Project Beneficiary Questionnaire.pdf`
- **Utilisateurs / fonction :** impact et terrain ; questionnaires, protocoles, consentement, période et agrégats.
- **Données / permissions :** réponses minimales, agrégats et preuve ; accès terrain limité, export contrôlé.
- **Relation module / valeur :** Impact ; reproductibilité des mesures.
- **Complexité / risques / priorité :** élevée ; données de personnes et consentement ; **P1**.

### OP-11 — Roadmap et revue mensuelle de pôle

- **Sources :** `Pole Veille/Bilan Pole Veille/mai/bilan_pole_veille_enactus.pdf`, `documents/Enactus 2025/Pôle Comm/Feuille de route/Feuille de route COM 2025.pdf`
- **Utilisateurs / fonction :** responsables de pôles et Veille ; objectifs, tâches, blocages, bilan et décisions.
- **Données / permissions :** agrégats, livrables, alertes ; gestion pôle, lecture gouvernance.
- **Relation module / valeur :** Pôles, Tâches, Dashboard ; remplace la consolidation Excel.
- **Complexité / risques / priorité :** moyenne ; ne pas exposer d’évaluation individuelle ; **P1**.

### OP-12 — Passation et succession par rôle

- **Sources :** `DOCS/Building-an-Enactus-Team.pdf`, `DOCS/Student-Leader-Selection-Process-.pdf`
- **Utilisateurs / fonction :** responsables entrants/sortants ; checklist, actifs, risques, accès et acceptation.
- **Données / permissions :** rôle, saison, livrables, accès ; partage limité aux personnes mandatées.
- **Relation module / valeur :** Archives, Membres, Academy ; continuité annuelle.
- **Complexité / risques / priorité :** moyenne ; gestion précise des droits ; **P1**.

## P2

### OP-13 — Calendrier éditorial et approbations média

- **Sources :** `DOCS/PR-101.pdf`, `Pole Veille/Strategie_Media_Enactus_Complet.docx`
- **Utilisateurs / fonction :** communication et projets ; brief, actifs, droits, validation et publication.
- **Données / permissions :** contenu, canal, calendrier, droits ; approbation métier et institutionnelle.
- **Relation module / valeur :** Publications, Documents, Événements ; cohérence et preuve de droits.
- **Complexité / risques / priorité :** moyenne ; gestion des médias personnels ; **P2**.

### OP-14 — Parcours Academy liés aux rôles

- **Sources :** `documents/formations/entreprenariat social/support_formation_entrepreneuriat_social.pdf`, `DOCS/Building-an-Enactus-Team.pdf`
- **Utilisateurs / fonction :** membres et responsables ; parcours d’intégration, projet, impact, finance et leadership.
- **Données / permissions :** sources, versions, progression ; résultats individuels restreints.
- **Relation module / valeur :** Academy, Membres ; montée en compétence et succession.
- **Complexité / risques / priorité :** faible à moyenne ; droits de réutilisation ; **P2**.

### OP-15 — Registre de tests, recettes et technologies

- **Sources :** `documents/Enactus 2025/Pôle Chimie/Bilans/Modèle rapport de test.docx`, `documents/Enactus 2025/Pôle Tech/Projets en cours/Etat d avancement syst. irrigation.pdf`
- **Utilisateurs / fonction :** pôles techniques ; version, protocole, résultat, décision et projet lié.
- **Données / permissions :** paramètres, fichiers, statut ; validation experte avant réutilisation.
- **Relation module / valeur :** Documents, Projets ; mémoire technique structurée.
- **Complexité / risques / priorité :** moyenne ; sécurité et obsolescence ; **P2**.

### OP-16 — Mentorat relié aux besoins projet

- **Sources :** `DOCS/Connecting-With-Alumni-External-Stakeholders.pdf`, `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf`
- **Utilisateurs / fonction :** alumni et projets ; publier un besoin, proposer un mentor, cadrer l’accès et clôturer.
- **Données / permissions :** compétence, disponibilité, périmètre ; consentement et autorisation projet.
- **Relation module / valeur :** Alumni, Projets ; réutilise l’expérience sans ouvrir tout le dossier.
- **Complexité / risques / priorité :** faible ; confidentialité des projets ; **P2**.

### OP-17 — Mode faible connexion avec synchronisation contrôlée

- **Sources :** `documents/enactspace_cahier_cadrage.pdf`, `documents/Pole Tech 2026/rapport_voyage_pole_technique_terrasen_2026.pdf`
- **Utilisateurs / fonction :** équipes terrain ; lecture hors ligne, brouillons et envoi différé explicite.
- **Données / permissions :** cache chiffré minimal ; aucune donnée restreinte persistée sans nécessité.
- **Relation module / valeur :** Événements, Tâches, Impact ; continuité terrain.
- **Complexité / risques / priorité :** élevée ; conflits de synchronisation et sécurité locale ; **P2**.

## P3

### OP-18 — Synchronisation calendrier externe

- **Sources :** `documents/enactspace_cahier_cadrage.pdf`
- **Utilisateurs / fonction :** membres ; publier les événements autorisés dans un calendrier externe.
- **Données / permissions :** titre, date, lieu et visibilité ; consentement et périmètre.
- **Relation module / valeur :** Événements, Notifications ; confort et rappels.
- **Complexité / risques / priorité :** moyenne ; fuite d’événements internes et jetons externes ; **P3**.
