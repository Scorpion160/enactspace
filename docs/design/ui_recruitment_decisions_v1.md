# Recrutement interne v1 — Décisions sécurisées et entretiens

## Objectif

La phase 2D-B2A ajoute les actions opérationnelles sur une candidature sans
élargir les permissions ni introduire de règle métier serveur : passage en
étude, entretien, liste d’attente, acceptation, rejet et clôture. La création
et le cycle de vie des campagnes ainsi que la conversion en utilisateur restent
reportés à 2D-B2B.

## Contrats backend réutilisés

Le changement de statut utilise
`POST /api/recruitment/applications/{application_id}/status` avec uniquement
`{"status": "..."}`. Les sept valeurs supportées et humanisées sont
`submitted`, `under_review`, `interview_scheduled`, `accepted`, `rejected`,
`waiting_list` et `cancelled`.

Le contrat ne possède aucun champ de motif, note ou commentaire pour une
transition. L’interface n’affiche donc aucun faux champ « Motif ». Les décisions
sensibles utilisent une confirmation renforcée, mais son état n’est pas présenté
comme une donnée persistée.

La planification utilise
`POST /api/recruitment/applications/{application_id}/interview` avec
`interview_at` obligatoire, puis `interview_location`, `interview_link`,
`interview_jury` et `interview_note` facultatifs. Le même endpoint accepte la
replanification d’un entretien existant et place le statut à
`interview_scheduled`.

## Actions et dialogues

La zone « Actions sur la candidature » masque l’action correspondant au statut
actuel. La sélection d’une action n’envoie rien : chaque parcours affiche le
candidat, la référence, la campagne, le statut actuel et le statut cible avant
confirmation.

- « Passer en étude » et « Placer en liste d’attente » utilisent un dialogue
  standard.
- « Retenir cette candidature ? » rappelle la moyenne officielle et le nombre
  d’évaluations. Cette décision n’entraîne aucune conversion en utilisateur.
- « Ne pas retenir cette candidature ? » distingue le rejet et exige la case
  « Je confirme avoir vérifié le dossier avant cette décision. ».
- « Clôturer cette candidature ? » reste distinct du rejet et exige la même
  confirmation renforcée.
- « Planifier un entretien » valide localement date et heure. « Modifier
  l’entretien » préremplit les données existantes lorsque le dossier possède
  déjà un entretien.

Pendant chaque envoi, les contrôles sont désactivés, un indicateur de progression
est visible et les doubles soumissions sont ignorées. Une erreur garde le
dialogue et ses données ouverts afin de permettre une nouvelle tentative. Un
succès ferme le dialogue, affiche un retour humain, recharge le dossier et met à
jour la ligne du workbench.

## Permissions

La phase réutilise strictement `require_recruitment_access` : rôles déjà admis
par `RECRUITMENT_ACCESS_ROLES` ou appartenance active au pôle Veille. Aucune
permission backend ni règle locale plus large n’est ajoutée. Le fait que la même
permission couvre lecture et mutations reste une dette métier à traiter côté
serveur.

## Testabilité

`InternalRecruitmentGateway` expose désormais les changements de statut et la
planification d’entretien. Les tests widgets injectent une fausse passerelle et
simulent succès, erreur, rafraîchissement et envoi en attente sans aucune requête
réelle. Ils couvrent aussi les confirmations dédiées, la prévention du double
clic, la conservation du formulaire, les statuts humanisés et l’absence de
conversion automatique.

## Runtime non mutatif

Le runtime `ui_audit` est contrôlé uniquement en lecture et par ouverture des
actions ou dialogues. Aucun bouton final de confirmation n’est activé. Les
fixtures restent dans leur statut initial et `mutation_performed=false`. Le
résultat est conservé dans
`docs/design/screenshots/ui_recruitment_decisions_v1/runtime_check.json`.

## Validation visuelle et contrôle après captures

Les huit captures desktop, tablette et mobile sont validées dans
`docs/design/screenshots/ui_recruitment_decisions_v1/`. Elles couvrent la zone
d’actions, les décisions de liste d’attente, acceptation, rejet et clôture,
ainsi que la planification et la modification d’un entretien. Les dialogues ont
été ouverts sans activer leur action finale ; la confirmation renforcée du rejet
est restée décochée et son bouton final désactivé.

Le contrôle API en lecture seule avant et après les captures retourne 37
candidatures. `AUDIT-REC-COMPLETE-001` reste `under_review`,
`AUDIT-REC-INTERVIEW-001` reste `interview_scheduled`,
`AUDIT-REC-ACCEPTED-001` reste `accepted`, `AUDIT-REC-WAITING-001` reste
`waiting_list` et `AUDIT-REC-REJECTED-001` reste `rejected`. L’entretien
existant reste fixé au 10/08/2026 à 14:30, Salle Audit Synthétique A1. Aucune
requête de mutation n’a été envoyée et `mutation_performed=false`.

Le backend ne fournit toujours aucun motif persistable et aucune matrice serveur
de transitions. La conversion d’un candidat en utilisateur reste une opération
séparée, explicitement reportée à la phase 2D-B2B.

## Limites backend

- aucun motif de rejet ou de clôture persistant ;
- aucune matrice serveur de transitions autorisées : le backend accepte
  largement les sept statuts ;
- aucune séparation de permission entre lecture et mutations Recrutement ;
- aucun journal détaillé des transitions ;
- création, modification, ouverture et fermeture des campagnes reportées à
  2D-B2B ;
- conversion candidat vers utilisateur reportée à 2D-B2B et jamais déclenchée
  par une acceptation.
