# Gouvernance et organisation

## Autorités documentaires

- `DOCS/Enactus_Equipe_Organigramme.pdf` est une référence Enactus structurante pour les responsabilités génériques : Team Leader, conseil pédagogique, secrétariat, finance, communication, responsables projet et fonctions support.
- `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf` décrit les règles locales : mission, qualité de membre, responsables, réunions, vacance des postes et création d’équipes projet. Son statut d’approbation et sa date d’effet ne sont toutefois pas visibles dans le corpus ; il est donc `NEEDS_VALIDATION` avant traduction en règle bloquante.
- `documents/enactspace_cahier_cadrage.pdf` formalise la cible numérique et les permissions souhaitées, mais ne remplace pas une politique adoptée.
- `PV 20.05.26.pdf` constitue une preuve opérationnelle récente sur le travail des Enac’chefs, les bilans projets et les roadmaps, sans être une règle générale.

## Modèle organisationnel consolidé

| Niveau | Responsabilité stable | Points à valider |
|---|---|---|
| Gouvernance | Le Team Leader coordonne, représente et arbitre ; le Faculty Advisor relie l’équipe à l’établissement. | Étendue exacte de la lecture globale et des validations du Faculty Advisor. |
| Administration | Le secrétariat prépare les réunions, conserve les PV et suit les dossiers institutionnels. | Quel document constitue le registre officiel et combien de temps le conserver. |
| Finance | La fonction finance prépare les budgets, suit les flux et rend compte. | Seuils d’approbation et séparation entre création, validation et rapprochement. |
| Pôles | Les responsables de pôle organisent les activités spécialisées et rendent compte. | Liste canonique : les sources locales ne donnent pas toutes les mêmes pôles. |
| Projets | Le responsable projet pilote le cycle de vie, l’équipe, les données, les rapports et l’impact. | Autorité de création, transfert, graduation et archivage. |
| Membres | Les membres contribuent aux projets ou équipes permanentes et participent aux réunions. | Quotas de présence et procédure de perte de qualité de membre. |

Sources : `DOCS/Enactus_Equipe_Organigramme.pdf`, `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf`, `DOCS/Building-an-Enactus-Team.pdf`.

## Conflit sur les pôles

Le texte local annonce six pôles mais en énumère sept, dont GCBA et Fundraising & Benchmarking. Le cadrage EnactSpace énumère Technique, Chimie, Gestion, IT, Communication, Veille et Organisation. Le corpus 2026 apporte par ailleurs une preuve d’activité du Pôle Veille. La configuration applicative ne doit donc pas figer une liste issue d’un seul document ; une décision datée de gouvernance doit désigner la nomenclature canonique et les alias historiques. Sources : `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf`, `documents/enactspace_cahier_cadrage.pdf`, `Pole Veille/Bilan Pole Veille/juin/bilan_pole_veille_juin_2026_enactus.pdf`.

## Processus GOV-01 — Réunion de gouvernance et décisions

- **PROCESS:** préparer, tenir et clôturer une réunion générale ou d’Enac’chefs.
- **ACTORS:** secrétariat, présidence de séance, responsables de pôles/projets, membres concernés.
- **INPUTS:** ordre du jour, bilans précédents, tâches ouvertes, contraintes, documents à décider.
- **STEPS:** programmer ; notifier ; enregistrer la participation ; traiter les points ; formuler les décisions ; attribuer responsable et échéance ; produire le PV ; diffuser selon visibilité.
- **APPROVALS:** validation du PV par la présidence de séance ou le rôle mandaté ; validation distincte des décisions financières.
- **OUTPUTS:** PV versionné, registre des décisions, tâches liées, alertes et pièces jointes.
- **DATA:** type/date de réunion, périmètre, rôles présents, décision, responsable de rôle, échéance, statut, lien de preuve.
- **CURRENT_MANUAL_TOOLS:** documents PDF/Word, messagerie, listes et tableurs.
- **PAIN_POINTS:** décisions enfouies dans les PV, identités répétées, absence de lien automatique avec les tâches, versions multiples.
- **ENACTSPACE_AUTOMATION_OPPORTUNITY:** modèle de réunion, décision convertible en tâche, validation du PV, rappels et vue des décisions non closes.

Sources : `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf`, `documents/Enactus 2025/PVs de Réunions/PV 29.03.2025.pdf`, `PV 20.05.26.pdf`.

## Processus GOV-02 — Nomination et passation d’un responsable

- **PROCESS:** sélectionner un responsable, transférer les connaissances et activer ses droits.
- **ACTORS:** instance de sélection, Faculty Advisor selon mandat, responsable sortant, responsable entrant, administrateur EnactSpace.
- **INPUTS:** description de rôle, critères, candidatures, état des projets, budget, documents et risques ouverts.
- **STEPS:** définir le rôle ; constituer le comité ; évaluer ; décider ; consigner ; préparer le dossier de passation ; transférer les responsabilités ; ajuster les accès ; faire une revue post-transition.
- **APPROVALS:** décision par l’instance locale autorisée ; activation des permissions par un administrateur distinct.
- **OUTPUTS:** mandat daté, checklist de passation, inventaire des accès et plan des 30 premiers jours.
- **DATA:** rôle, périmètre, dates, décision, documents transférés, accès remis/révoqués, points ouverts.
- **CURRENT_MANUAL_TOOLS:** documents de poste, échanges directs, dossiers partagés.
- **PAIN_POINTS:** critères locaux non datés, passation informelle, risque de perte documentaire et de droits persistants.
- **ENACTSPACE_AUTOMATION_OPPORTUNITY:** workflow de nomination, checklist par rôle, attestation de remise, révocation programmée des anciens droits.

Sources : `DOCS/Student-Leader-Selection-Process-.pdf`, `DOCS/Building-an-Enactus-Team.pdf`, `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf`.

## Règles de conception

1. Les permissions sont portées par des rôles et périmètres datés, pas par des noms de personnes.
2. Une règle issue d’un document sans approbation vérifiable reste informative.
3. Toute décision sensible conserve auteur de rôle, validateur, date, motif et objet lié.
4. Les bilans individuels restent privés ; les tableaux de gouvernance présentent des agrégats et des exceptions autorisées.
5. Les évolutions de structure sont historisées par saison plutôt qu’écrasées.
