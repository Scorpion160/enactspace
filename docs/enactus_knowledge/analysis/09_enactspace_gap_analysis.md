# Analyse des écarts EnactSpace

## Méthode

Le cadrage a été comparé au corpus métier et aux routes, schémas et écrans présents dans le dépôt. Les statuts signifient :

- `EXISTS_AND_ALIGNED` : capacité présente et conforme au besoin observé ;
- `EXISTS_BUT_INCOMPLETE` : socle présent, chaîne métier ou donnée manquante ;
- `EXISTS_BUT_MISALIGNED` : capacité présente mais comportement contraire à une référence ;
- `MISSING` : objet métier absent ;
- `SHOULD_NOT_BE_DIGITIZED` : donnée ou pratique à ne pas transformer en fonctionnalité.

## Matrice

| Domaine | Statut | Évaluation | Source métier principale |
|---|---|---|---|
| Authentification, rôles, audit | `EXISTS_AND_ALIGNED` | rôles, comptes, validation et journal d’audit existent | `documents/enactspace_cahier_cadrage.pdf` |
| Membres | `EXISTS_AND_ALIGNED` | cycle compte/membre et annuaire couverts | `DOCS/Building-an-Enactus-Team.pdf` |
| Pôles | `EXISTS_BUT_INCOMPLETE` | entités et membres existent ; nomenclature saisonnière, roadmap et revue mensuelle manquent | `Pole Veille/Bilan Pole Veille/juin/bilan_pole_veille_juin_2026_enactus.pdf` |
| Projets | `EXISTS_BUT_INCOMPLETE` | fiche, membres, budget estimé et statut existent ; besoins, stage-gates, propriété et graduation ne sont pas structurés | `DOCS/Enactus-Project-Guide.pdf` |
| Tâches | `EXISTS_AND_ALIGNED` | affectation, checklist, statuts, preuve et validation couvrent les pratiques observées | `Pole Veille/Bilan Pole Veille/mai/bilan_pole_veille_enactus.pdf` |
| Présences | `EXISTS_AND_ALIGNED` | sessions, pointage, justification, rapports et accès dédiés sont présents | `documents/ENACTUS ESP/TextesENACTUS-ESP.pdf` |
| Finance membre | `EXISTS_AND_ALIGNED` | frais, paiements, allocations, validation et preuves existent | `documents/enactspace_cahier_cadrage.pdf` |
| Finance projet/pôle | `EXISTS_BUT_INCOMPLETE` | transactions existent ; budget versionné, demande, engagement et rapprochement ligne à ligne manquent | `DOCS/Budgeting-Financial-Management.pdf` |
| Publications et chat | `EXISTS_AND_ALIGNED` | fil, périmètres, commentaires, réactions, chat et pièces sont présents | `documents/enactspace_cahier_cadrage.pdf` |
| Documents | `EXISTS_BUT_INCOMPLETE` | dépôt, validation, modèles, catégories et archivage existent ; provenance, SHA, version logique et conflit manquent | `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf` |
| Recrutement | `EXISTS_AND_ALIGNED` | campagne, formulaire, entretien, avis, statuts, export et conversion sont présents | `documents/enactspace_cahier_cadrage.pdf` |
| Alumni et mentorat | `EXISTS_AND_ALIGNED` | profils, recherche, mentorats et permissions sont présents | `DOCS/Connecting-With-Alumni-External-Stakeholders.pdf` |
| Événements | `EXISTS_BUT_INCOMPLETE` | événements, inscriptions, budget et rapport existent ; dossier mission, risques, approbations et rapprochement manquent | `documents/Pole Tech 2026/rapport_voyage_pole_technique_terrasen_2026.pdf` |
| Academy | `EXISTS_BUT_INCOMPLETE` | cours, leçons, quiz et progression existent ; provenance, droits et date de révision des sources manquent | `documents/formations/entreprenariat social/support_formation_entrepreneuriat_social.pdf` |
| Gamification | `EXISTS_AND_ALIGNED` | points/badges sont compatibles si seules les contributions positives sont visibles | `documents/enactspace_cahier_cadrage.pdf` |
| Impact | `EXISTS_BUT_MISALIGNED` | modèle, métriques, preuves et validation existent, mais des métriques de repli sont calculées depuis l’avancement/documents et des minima spécifiques à Terrasen sont imposés ; cela contredit l’interdiction d’estimer l’impact réalisé | `DOCS/Enactus-Impact-Reporting-Evaluation-Guide-2025-2026.pdf` |
| Archives | `EXISTS_BUT_INCOMPLETE` | archives, projets historiques, prix, compétitions, médias et impact historique existent ; déduplication, version canonique et import de provenance manquent | `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf` |
| Notifications | `EXISTS_AND_ALIGNED` | notifications, non lus et actions groupées sont présents | `documents/enactspace_cahier_cadrage.pdf` |
| Dashboard | `EXISTS_BUT_INCOMPLETE` | agrégation par rôle présente ; la qualité dépend de métriques validées et d’alertes sans données fictives | `documents/enactspace_cahier_cadrage.pdf` |
| CRM partenaires | `MISSING` | aucune chaîne structurée prospect→accord→contrepartie→rapport | `DOCS/Fundraising-101.pdf` |
| Registre réunions/décisions | `MISSING` | les événements et documents existent, mais décision et action liée ne sont pas des objets de premier rang | `PV 20.05.26.pdf` |
| Mode faible connexion/hors-ligne | `MISSING` | le cadrage l’attend mais aucun mécanisme métier de synchronisation contrôlée n’est visible | `documents/enactspace_cahier_cadrage.pdf` |
| Synchronisation calendrier externe | `MISSING` | explicitement prévue plus tard | `documents/enactspace_cahier_cadrage.pdf` |
| Import d’identités de bénéficiaires | `SHOULD_NOT_BE_DIGITIZED` | les tableaux de bord n’ont besoin que d’agrégats et de preuves minimisées | `DOCS/Enactus-Impact-Reporting-Evaluation-Guide-2025-2026.pdf` |
| Classement public de données individuelles négatives | `SHOULD_NOT_BE_DIGITIZED` | contraire à la confidentialité et à l’éthique de motivation | `documents/enactspace_cahier_cadrage.pdf` |

## Écart critique Impact

Le socle Impact est bien conçu autour de profils, métriques, preuves et validations. Cependant, la lecture de `backend/app/api/routes/impact.py` montre qu’en l’absence de profil validé, l’API dérive des volumes directs/indirects depuis le statut du projet et le nombre de documents, puis impose des valeurs minimales pour Terrasen. Ces valeurs ne sont pas des observations. Elles doivent être absentes ou marquées « non renseigné » tant qu’une métrique validée ne les fournit pas. La règle source est explicite : résultats réels uniquement, projections séparées. Source : `DOCS/Enactus-Impact-Reporting-Evaluation-Guide-2025-2026.pdf`.

## Conclusion produit

EnactSpace possède déjà le socle fonctionnel annoncé par le cadrage. Les prochains incréments doivent améliorer la qualité, la provenance et les liaisons entre modules, non multiplier des écrans isolés. L’ordre recommandé est : sécuriser Impact ; versionner documents et budgets ; normaliser portefeuille et décisions ; ajouter missions et partenaires ; terminer les fonctions de confort.
