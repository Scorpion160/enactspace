# Recrutement interne v1 — Intégration d’un candidat retenu

## Objectif

La phase 2D-B2B2 ajoute au dossier d’une candidature retenue un parcours
d’intégration dans EnactSpace. La décision « Candidature retenue » et la
création ou l’activation du compte restent deux opérations indépendantes. Une
acceptation ne déclenche jamais automatiquement la conversion.

## Contrat API réel

`POST /api/recruitment/applications/{id}/convert-to-user` reçoit :

- `password`, obligatoire et contrôlé à 8 caractères minimum après trim ;
- `profile_type`, facultatif ;
- `core_pole_id`, UUID facultatif ;
- `support_pole_ids`, liste d’UUID, vide par défaut ;
- `project_id`, UUID facultatif.

La candidature doit exister et son statut doit être exactement `accepted`.
L’API ne fournit aucun endpoint de prévisualisation du compte associé à
l’e-mail. Elle ne fournit pas non plus de catalogue de rôles assignables dans
ce contrat : le rôle de base `enacteur` est systématiquement créé ou associé.
`profile_type` pilote le profil Enacteur/Enactrice mais n’est pas validé contre
une liste serveur.

## Permissions

La dépendance `require_sg_or_admin` protège la mutation. Les rôles réellement
autorisés sont :

- Administrateur (`administrateur`) ;
- Team Leader (`team_leader`) ;
- Secrétaire générale (`secretaire_generale`).

Le payload de lecture d’une candidature expose `can_convert`, calculé par le
backend avec la même liste. L’interface se fonde exclusivement sur ce booléen
serveur : elle ne reconstitue pas localement une permission. L’action apparaît
seulement pour une candidature `accepted`, non anonymisée, non déjà liée et
avec `can_convert=true`.

## Séparation acceptation et intégration

Le dialogue « Retenir cette candidature ? » continue à ne modifier que le
statut. Une section distincte « Intégration dans EnactSpace » apparaît ensuite
dans la fiche. Elle affiche l’état de la candidature, l’état détectable du
compte et l’action « Préparer l’intégration ». Aucun appel de conversion n’est
fait à l’ouverture ni pendant la navigation.

## Parcours en trois étapes

1. Le résumé présente identité, e-mail, téléphone, campagne, statut retenu,
   pôle préféré, projet d’intérêt et parcours.
2. Les affectations utilisent les services existants `PolesService` et
   `ProjectsService`. Le rôle membre de base est expliqué ; le profil, le pôle
   cœur, les pôles support, le projet et le mot de passe sont les seuls champs
   proposés.
3. La vérification humanise toutes les valeurs, rappelle que l’opération est
   distincte de la décision et exige la confirmation « Je confirme les
   affectations et l’ouverture de l’accès EnactSpace. »

Le bouton final utilise le libellé neutre « Finaliser l’intégration », car le
backend ne garantit pas avant l’envoi s’il créera un compte ou reliera un compte
existant. Il est désactivé avant confirmation et pendant l’envoi. Un garde
supplémentaire empêche le double appel.

## Compte inexistant ou existant

### Aucun utilisateur correspondant

Le backend crée un utilisateur actif et vérifié avec l’identité du candidat,
le hash du mot de passe initial, le profil demandé ou dérivé du genre, les
informations de parcours, puis le rôle de base `enacteur`. Il crée ensuite les
adhésions demandées et lie `converted_user_id`.

### Utilisateur existant

Le backend relie la candidature à l’utilisateur trouvé par e-mail, complète
les informations manquantes, applique le profil demandé, force `status=active`
et `is_active=true`, garantit le rôle de base et crée ou réactive les adhésions
de pôle et de projet. Il ne remplace pas le mot de passe existant, bien que le
champ `password` de 8 caractères reste exigé avant cette branche.

Le serveur ne distingue pas dans sa réponse un compte précédemment inactif
d’un compte déjà actif. Les deux passent par la même activation et retournent
« Un compte existait déjà avec cet email ». Aucun conflit 409 « utilisateur
actif » n’est implémenté par cet endpoint. L’interface ne prétend donc pas
connaître ce scénario avant l’envoi.

### Candidature déjà liée

Si `converted_user_id` est déjà renseigné, l’API retourne un succès idempotent
sans appliquer de nouvelles affectations. Dans l’interface, la section affiche
« Déjà membre » et masque l’action de conversion.

## Affectations

Le pôle cœur et chaque pôle support sont vérifiés côté serveur. Une adhésion
existante est réactivée avec la position `membre`, `left_at=null` et
`is_active=true`; sinon elle est créée. Le projet suit le même comportement.
Un pôle ou projet absent produit une erreur 404 humaine. Le contrat ne permet
pas d’attribuer un rôle de responsabilité pendant la conversion.

## Mot de passe initial

Le mot de passe est saisi dans un champ dédié, masqué par défaut et affichable
sur demande. La validation locale reprend la limite serveur de 8 caractères.
La valeur reste uniquement dans le contrôleur en mémoire pendant le dialogue ;
elle n’est jamais journalisée, documentée, stockée dans les traces runtime ni
présentée dans l’écran de résultat.

## Résultat et erreurs

Le résultat affiche uniquement le membre, le profil, les affectations et un
libellé humain de création, d’activation d’un compte existant ou de liaison déjà
effectuée. Il ne contient aucune donnée sensible.

Les erreurs 400 réelles couvrent la candidature non acceptée et le mot de passe
trop court. La permission insuffisante produit 403 ; une candidature, un pôle
ou un projet absent produit 404. Le schéma peut produire 422 pour un UUID
invalide. Aucun 409 métier n’est levé explicitement. Les erreurs réseau et
serveur sont conservées dans le dialogue avec les saisies et affectations ;
l’utilisateur peut réessayer sans réinitialisation.

## Academy et notifications

La conversion ne crée aucun onboarding Academy. Le service Flutter historique
contient un appel non bloquant vers `/academy/onboarding/assign`, mais aucun
endpoint correspondant n’existe dans le backend inspecté ; le nouveau parcours
ne l’appelle pas et ne promet aucun onboarding.

Le backend crée une notification interne `recruitment_update` après création
ou liaison. Le contrat ne garantit ni e-mail ni push, donc l’interface n’en fait
aucune promesse.

## Testabilité

`InternalRecruitmentGateway` expose le chargement du catalogue et la conversion
sous forme de modèles typés. Les tests widgets injectent un gateway simulé et
n’envoient aucune requête réelle. Ils couvrent permissions, éligibilité,
résumé, catalogues, validation, masquage du mot de passe, vérification,
confirmation, double clic, création et activation simulées, erreurs,
conservation, absence d’automatisme, résultat sans secret, responsive 390 px et
absence d’enum brut.

## Runtime non mutatif

Le contrôle `ui_audit` utilise `AUDIT-REC-ACCEPTED-001`. Les lectures avec
`audit.admin` indiquent `accepted`, `converted_user_id=null` et
`can_convert=true`. Les lectures avec `audit.finance` conservent le même état et
indiquent `can_convert=false`. Le parcours est ouvert et parcouru sans cocher ni
déclencher l’action finale. La trace détaillée est conservée dans
`docs/design/screenshots/ui_recruitment_conversion_v1/runtime_check.json`.

## Limites backend

- aucune prévisualisation de l’existence ou de l’activité du compte par e-mail ;
- aucune distinction de réponse entre compte inactif et déjà actif ;
- aucun conflit 409 métier pour un membre actif ;
- `profile_type` non borné par un enum serveur ;
- mot de passe exigé même lorsqu’un compte existant ne le réutilise pas ;
- aucune transaction de prévalidation des affectations ;
- aucun onboarding Academy disponible sur le contrat inspecté ;
- notification interne seulement, sans garantie d’e-mail ou de push.
