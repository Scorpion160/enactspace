# Recrutement interne v1 — Gestion des campagnes

## Objectif

La phase 2D-B2B1 ajoute une surface dédiée de gestion des campagnes depuis le
workbench Recrutement. Elle couvre consultation, création, édition, activation,
fermeture et préparation d’une suppression sécurisée. La conversion d’un
candidat en utilisateur reste explicitement reportée à 2D-B2B2.

## Contrats API

Les cinq endpoints réutilisent strictement `require_recruitment_access` :

- `POST /api/recruitment/campaigns` accepte `season_id` facultatif, `title`
  requis, `description`, `start_date`, `end_date` et `is_active` ;
- `GET /api/recruitment/campaigns` retourne toutes les campagnes et accepte le
  filtre facultatif `is_active` ;
- `GET /api/recruitment/campaigns/{id}` retourne une campagne ;
- `PATCH /api/recruitment/campaigns/{id}` accepte uniquement `title`,
  `description`, `start_date`, `end_date` et `is_active`, tous facultatifs ;
- `DELETE /api/recruitment/campaigns/{id}` supprime définitivement la campagne.

Le backend impose seulement que la date de fin ne précède pas la date de début.
La surface ne propose pas `season_id`, car aucun catalogue de saisons n’est
fourni dans ce parcours. Aucun champ absent du schéma n’est inventé.

## États calculés

Le backend ne possède aucun enum de statut de campagne. Une présentation
frontend centralisée dérive l’état à partir de `is_active`, `start_date`,
`end_date` et de la date courante :

- **Planifiée** : campagne active dont le début est futur ;
- **Ouverte** : campagne active, commencée et non terminée ;
- **Terminée** : date de fin passée, même si `is_active` reste vrai ;
- **Inactive** : campagne désactivée et non terminée.

La date de fin passée est prioritaire. L’interface ne modifie jamais la base
automatiquement et n’affiche jamais `is_active=true` ou `is_active=false`.

## Surface de gestion

L’action « Gérer les campagnes » ouvre une page secondaire et laisse le
workbench candidats intact. La liste affiche titre, description, état humain,
période, nombre de candidatures calculé depuis les données déjà chargées,
activation humaine et actions disponibles. Chargement, erreur API, liste vide
et rafraîchissement sont des états distincts.

## Création et édition

Le formulaire de création utilise titre, description, dates et activation.
Le titre est requis, les dates doivent être valides et la fin doit suivre le
début. Une date future activée produit une campagne **Planifiée**, sans promesse
d’ouverture publique immédiate.

Le formulaire d’édition préremplit les valeurs existantes et utilise PATCH.
L’action « Enregistrer les modifications » reste distincte des actions
d’ouverture et de fermeture. Une erreur conserve le formulaire et les saisies.
Pendant tout envoi, le bouton est désactivé, une progression est affichée et la
double soumission est ignorée.

## Ouverture et fermeture

« Ouvrir cette campagne ? » présente le titre, la période, l’état actuel et
l’état attendu. Une campagne future activée reste **Planifiée**. Les dates sont
validées localement avant toute mutation simulée.

« Fermer cette campagne ? » explique que la campagne ne sera plus proposée aux
nouveaux candidats. Les candidatures existantes restent consultables : le PATCH
ne modifie que la campagne et le modèle conserve les candidatures associées.
Une campagne terminée n’est jamais présentée comme ouverte et n’est pas mutée
automatiquement.

## Suppression et risque de cascade

`Application.campaign_id` référence `recruitment_campaigns.id` avec
`ondelete="CASCADE"`. DELETE peut donc supprimer toutes les candidatures de la
campagne. La suppression reste secondaire, rouge et irréversible. Le dialogue
« Supprimer définitivement cette campagne ? » affiche le titre, le nombre de
candidatures, l’avertissement de cascade et exige une confirmation renforcée.
Le bouton final reste désactivé avant confirmation. Aucune suppression réelle
n’est effectuée dans `ui_audit`.

## Permissions et limites backend

La phase réutilise les droits existants sans les élargir côté Flutter. Le
backend accorde actuellement l’accès Recrutement à un ensemble large de rôles
et ne sépare pas lecture et gestion. Il ne fournit ni enum d’état de campagne,
ni compteur de candidatures dans `RecruitmentCampaignRead`, ni catalogue de
saisons dans ce parcours, ni protection serveur contre la suppression en
cascade d’une campagne contenant des dossiers.

## Responsive et accessibilité

La liste utilise une colonne à 390 px, deux colonnes à 768 px et jusqu’à trois
colonnes sur desktop. Les formulaires sont scrollables et les actions tactiles
restent accessibles sans overflow horizontal. Les campagnes, états, périodes,
actions ouvrir, fermer, modifier et supprimer ainsi que les confirmations ont
des libellés `Semantics`. L’état ne dépend jamais uniquement de la couleur.

## Stratégie de tests

Les tests injectent `InternalRecruitmentGateway` et n’envoient aucune requête
réelle. Ils couvrent les quatre états, les valeurs humaines, liste, vide,
erreur, création, validation, édition, activation, fermeture, cascade,
confirmation renforcée, conservation après erreur, double soumission et mobile
390 px. Les mutations succès/échec sont toutes simulées.

## Runtime non mutatif

Le runtime réel a été contrôlé uniquement par GET et par ouverture des surfaces
locales. Il contient 7 campagnes et 37 candidatures. Les fixtures ouverte et
planifiée sont affichées **Ouverte** et **Planifiée**. La fixture fermée a une
date de fin passée et s’affiche donc **Terminée**, sans modification de son
booléen backend. Les formulaires de création/édition et les confirmations de
fermeture/suppression ont été ouverts sans action finale. Aucune fixture inactive
non terminée ne permet d’ouvrir le dialogue d’activation réel ; celui-ci est
validé par gateway simulé. `mutation_performed=false`.

Le détail est conservé dans
`docs/design/screenshots/ui_recruitment_campaigns_v1/runtime_check.json`.

## Validation visuelle

Les huit captures desktop, tablette et mobile sont validées dans
`docs/design/screenshots/ui_recruitment_campaigns_v1/`. Elles couvrent la
liste, la création non soumise, la validation locale des dates, l’édition
préremplie, les confirmations de fermeture et de suppression, la campagne
planifiée et la liste mobile.

Les contrôles runtime avant et après les captures indiquent tous deux 7
campagnes et 37 candidatures. Les campagnes `AUDIT-REC-CAMPAIGN-OPEN`,
`AUDIT-REC-CAMPAIGN-PLANNED` et `AUDIT-REC-CAMPAIGN-CLOSED` restent
respectivement active et ouverte, active et planifiée, puis inactive et
terminée. Aucune campagne n’a été créée, modifiée, activée, désactivée ou
supprimée et aucune candidature n’a été supprimée :
`mutation_performed=false`.

Le risque de suppression en cascade est uniquement démontré visuellement : la
confirmation renforcée n’est pas satisfaite et aucune requête DELETE n’est
envoyée. La conversion d’un candidat en utilisateur reste reportée à la phase
2D-B2B2.
