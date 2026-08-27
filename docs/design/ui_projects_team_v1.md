# UI Projets — Gestion de l’équipe v1

## Périmètre

Cette phase couvre uniquement la consultation et la gestion humaine de
`/projects/:projectId` : membres ordinaires, chef de projet et adjoint. Elle ne
modifie ni le projet, ni son statut, ni ses tâches, documents, données Impact
ou permissions backend.

## Contrat GET memberships

`GET /api/projects/{project_id}/members` exige un compte actif et validé. Le
projet absent produit `404 Projet introuvable`. La réponse contient uniquement
les memberships `is_active=true`, triées par position puis date d’arrivée, avec
`id`, `project_id`, `user_id`, `position`, `joined_at`, `left_at`, `is_active`,
nom, e-mail, photo et statut du compte. Le filtre ne vérifie pas explicitement
`left_at IS NULL`; une incohérence historique active avec une date de départ
serait donc renvoyée par l’API, tandis que l’interface exige les deux conditions
pour reconnaître une responsabilité locale active.

## Contrat POST membership

`POST /api/projects/{project_id}/members` reçoit :

```json
{
  "user_id": "UUID",
  "position": "membre"
}
```

`position` vaut exclusivement `membre`, `chef_projet` ou
`adjoint_chef_projet`. Le projet ou l’utilisateur absent produit `404`. Une
position invalide ou un compte dont `status != active` ou `is_active=false`
produit `400`. Un gestionnaire insuffisant produit `403`.

Le POST crée la membership si elle n’existe pas. Si la contrainte unique
`project_id + user_id` trouve une ligne existante, il change la position,
réactive `is_active=true` et efface `left_at`. La réponse ne contient aucun
indicateur permettant au client de distinguer de façon fiable création et
réactivation. Le libellé de confirmation reste donc neutre; le feedback
« Membre réintégré à l’équipe » n’est utilisé que lorsqu’un gateway simulé ou
une évolution future du contrat fournit explicitement cette information.

## Positions et terminologie

- `membre` → Membre du projet ;
- `chef_projet` → Chef de projet ;
- `adjoint_chef_projet` → Adjoint chef de projet.

L’interface parle de « Responsabilité dans le projet » et n’affiche jamais les
valeurs techniques.

## Permissions

Les gestionnaires globaux sont `administrateur`, `team_leader` et
`secretaire_generale`. Une membership active, sans date de départ, à la
position chef ou adjoint accorde la gestion locale de son projet.

Les deux catégories peuvent ajouter et retirer un membre ordinaire. Seuls les
gestionnaires globaux peuvent nommer, remplacer ou retirer un chef ou un
adjoint. Le sélecteur générique d’ajout propose uniquement « Membre du
projet »; les responsabilités passent par les dialogues dédiés.

Le backend ne permet donc pas à un chef ou adjoint local de se retirer
lui-même : sa position de responsable déclenche la protection globale. Un
gestionnaire global qui retire sa propre membership reçoit néanmoins
l’avertissement qu’il perdra sa capacité locale après succès.

## Annuaire

`GET /api/users/directory` exige un compte actif validé et renvoie les comptes
`is_active=true` dont le statut vaut `active` ou `alumni`. Le schéma
`UserDirectoryRead` n’expose pas `is_active`, mais expose `status` et
`profile_type`. Comme le POST refuse tout statut autre que `active`, le picker
conserve uniquement `status=active` et exclut les alumni. La liste est chargée
une fois puis mise en cache par le gateway; la recherche nom/e-mail est locale
et ne recharge pas à chaque frappe.

Une personne déjà membre active reste visible avec « Déjà dans l’équipe » et
sa responsabilité humanisée, mais elle n’est pas sélectionnable dans le
parcours d’ajout. « Aucun membre disponible » est distinct d’une erreur de
chargement.

## Ajout et réactivation

« Ajouter un membre » présente la personne, le projet et « Membre du projet »
avant « Ajouter à l’équipe ». Le bouton est désactivé pendant l’envoi, un garde
empêche le double clic, et les erreurs gardent sélection et dialogue ouverts
avec « Réessayer ». Après succès, le cache memberships du projet est invalidé,
la fiche est relue et le feedback est « Membre ajouté à l’équipe » ou, si le
résultat le distingue, « Membre réintégré à l’équipe ».

Le projet sans membership affiche « Aucune équipe affectée » comme état vide,
avec « Constituer l’équipe » pour un gestionnaire autorisé.

## Chef, adjoint et remplacement

Les dialogues « Nommer/Changer de chef de projet » et « Nommer/Changer
d’adjoint » sont réservés à la gestion globale. Ils présentent le titulaire
actuel, le nouveau titulaire et la responsabilité cible.

Lorsqu’un titulaire existe, le POST rétrograde automatiquement toute autre
membership active à la même position vers `membre`. L’interface annonce avant
confirmation que l’ancien titulaire quitte cette responsabilité et reste
membre du projet. Aucun remplacement automatique supplémentaire n’est inventé.

Pour chaque ancien titulaire rétrogradé, le backend synchronise le rôle global
de responsabilité, puis envoie une notification. Il synchronise également les
rôles de l’utilisateur nommé, notifie l’affectation si sa position change et
écrit un audit `affectation_projet` avec valeurs avant/après et adresse IP.

## Contrat DELETE et retrait

`DELETE /api/projects/{project_id}/members/{user_id}` exige les mêmes droits de
gestion. Le projet absent ou la membership absente produit `404`; le retrait
d’un chef/adjoint par un gestionnaire local produit `403`.

Le backend ne supprime pas la ligne : il fixe `is_active=false` et
`left_at=date.today()`. Pour un responsable, son rôle synchronisé est retiré
s’il ne porte plus cette position dans aucun autre projet actif. Une
notification de fin d’affectation est envoyée et un audit `retrait_projet`
conserve l’avant/après.

Le dialogue « Retirer ce membre du projet ? » affiche personne, projet,
responsabilité et conséquence. Pour chef ou adjoint, il avertit que le projet
restera sans ce responsable jusqu’à une nomination ultérieure. Le backend ne
nomme aucun remplaçant. L’action « Retirer de l’équipe » n’envoie le DELETE
qu’après confirmation explicite.

## Erreurs et sécurité UX

Les erreurs réelles sont humanisées : compte inactif, projet ou utilisateur
introuvable, responsabilité invalide, permission insuffisante, membership
absente, réseau et serveur. Tous les dialogues conservent leur état après
erreur, désactivent leur action pendant l’envoi et empêchent la duplication.
Les feedbacks sont : membre ajouté/réintégré, chef mis à jour, adjoint mis à
jour et membre retiré.

## Testabilité

`ProjectsPortfolioGateway` injecte l’annuaire, l’ajout/changement de position
et le retrait. Les tests widgets utilisent exclusivement un gateway mémoire et
couvrent lecture, état vide, permissions globales/locales, filtrage annuaire,
recherche, ajout, réactivation simulée, erreurs, double clic, chef, adjoint,
remplacement, retrait, confirmations, feedback, rafraîchissement, absence
d’enum brut et largeur 390 px. Aucune requête réelle n’est émise.

## Runtime non mutatif

La trace
`docs/design/screenshots/ui_projects_team_v1/runtime_check.json` conserve les
lectures `ui_audit` : 9 projets, 7 memberships actives sur Audit Horizon avec
chef, adjoint et membres ordinaires, et 0 membership active sur Audit Projet
Sans Équipe. Ces données proviennent des traces runtime en lecture déjà
validées. La politique de navigation du navigateur intégré a bloqué l’URL
locale avant le contrôle interactif de cette exécution; aucun contournement
n’a été utilisé. Les dialogues et permissions sont donc validés par gateway
widget sans action finale ni requête réelle. Les compteurs POST members et
DELETE members restent à zéro et `mutation_performed=false`.

## Validation visuelle 2E-B2

Les huit captures de `docs/design/screenshots/ui_projects_team_v1/` sont
validées : équipe desktop, ajout d’un membre, changement de chef, changement
d’adjoint, retrait d’un membre, retrait d’un responsable, projet sans équipe
en tablette et équipe mobile. Leurs SHA-256 distincts et les marqueurs atteints
sont consignés dans `capture_state_results.json`.

Les lectures runtime conservées dans `runtime_check.json` confirment que les
9 projets restent inchangés, qu’Audit Horizon conserve 7 memberships actives,
son chef `Audit ProjectLead` et son adjoint `Audit Active03`, et qu’Audit Projet
Sans Équipe reste à 0 membership active. POST members = 0, DELETE members = 0
et aucune mutation n’a été effectuée.

Les remplacements de responsable et les retraits sont uniquement démontrés
visuellement par gateway widget déterministe : aucune action finale n’a été
envoyée. Les permissions globales et locales ont été validées par les tests
widgets. La limitation du navigateur intégré est documentée dans la trace :
l’URL locale a été bloquée avant contrôle interactif, sans contournement.

## Limites backend restantes

- GET members ne filtre pas explicitement `left_at IS NULL` ;
- l’annuaire omet `is_active` alors que le POST le vérifie ;
- le POST ne renvoie pas le type création/réactivation/changement ;
- aucun endpoint ne permet de lire les memberships inactives d’un projet ;
- aucune opération atomique distincte « remplacer un responsable » : le POST
  réalise implicitement la rétrogradation ;
- aucun remplacement automatique lors d’un DELETE responsable ;
- les notifications exposent encore la position technique dans le message du
  nouveau titulaire ;
- aucune permission `can_manage_team` n’est portée par la réponse projet ; le
  frontend recoupe compte et memberships.
