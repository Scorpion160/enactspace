# PR-2A — Account, Privacy & Legal Backend

## Périmètre et architecture

PR-2A ajoute exclusivement les contrats backend nécessaires aux préférences, documents juridiques versionnés, acceptations, export personnel, demandes de suppression et sessions refresh. Aucun écran Flutter, provider push, device registration, déploiement ou effacement physique n'est inclus.

Les capacités sont séparées du modèle `User` afin de préserver les conventions et clés étrangères historiques :

| Table | Rôle | Contraintes principales |
|---|---|---|
| `user_preferences` | préférences extensibles par utilisateur | PK/FK `user_id`, locale `fr/en`, thème `system/light/dark` |
| `legal_documents` | versions historiques des politiques | UUID, unicité type/version, une seule version active par type |
| `legal_acceptances` | preuve immuable d'acceptation | UUID, unicité utilisateur/document, snapshot de version |
| `account_deletion_requests` | workflow non destructif | UUID, statuts contrôlés, une seule demande `pending` par utilisateur |
| `auth_sessions` | refresh rotatif et révocation | UUID, refresh haché unique, expiration et révocation indexées |

La préférence timezone n'est pas ajoutée en V1 : le backend ne possède pas encore de contrat temporel utilisateur cohérent. `acceptable_use` n'est pas ajouté sans décision institutionnelle ; les deux types stricts sont `privacy_policy` et `terms_of_use`.

## Migration

La révision `20260902_0002` part de `20260713_0001`, crée les cinq tables, contraintes, FK et index, et possède un downgrade ciblé. Toutes les colonnes UUID utilisent le type projet `GUID()` : UUID natif sous PostgreSQL et `CHAR(36)` sous SQLite. La baseline historique construit malheureusement son schéma depuis les métadonnées vivantes. La nouvelle révision gère donc deux états sûrs : aucune table PR-2A (installation existante) ou les cinq tables déjà présentes ensemble (base propre venant de la baseline dynamique). Un état partiel échoue explicitement et exige une revue opérateur.

Le cycle SQLite propre `upgrade head → downgrade 20260713_0001 → upgrade head` est validé. Aucune donnée existante n'est supprimée par l'upgrade.

## Endpoints

### Préférences et droits utilisateur

- `GET /api/users/me/preferences`
- `PATCH /api/users/me/preferences`
- `POST /api/users/me/data-export`
- `POST /api/users/me/deletion-request`
- `GET /api/users/me/deletion-request`
- `POST /api/users/me/deletion-request/cancel`

### Légal

- `GET /api/legal/documents` : versions publiées historiques, filtre type optionnel ;
- `GET /api/legal/documents/{type}` : version active publiée ;
- `GET /api/legal/status/me` : état d'acceptation de l'utilisateur ;
- `POST /api/legal/acceptances` : acceptation exacte et immuable ;
- `POST /api/legal/documents` : création admin d'un draft ;
- `POST /api/legal/documents/{id}/publish` : publication admin et désactivation atomique de l'ancienne version.

### Suppression administrée

- `GET /api/admin/account-deletion-requests`
- `PATCH /api/admin/account-deletion-requests/{id}`

### Sessions

- `POST /api/auth/refresh`
- `GET /api/auth/sessions`
- `DELETE /api/auth/sessions/{id}`
- `POST /api/auth/logout-all`

`POST /api/auth/login` et `POST /api/auth/token` retournent désormais aussi `refresh_token`, `expires_in` et `refresh_expires_in` en conservant `access_token` et `token_type`.

## RBAC

Un membre actif validé gère uniquement ses préférences, acceptations, export, demande de suppression et sessions. La création/publication juridique et le traitement des demandes utilisent le contrôle backend `administrateur` ou `team_leader`. Les routes publiques ne servent que les documents publiés. `admin_note` utilise un schéma de réponse réservé aux routes administratives et n'est jamais sérialisé par les endpoints utilisateur. Les tests couvrent 401 sans jeton et 403 sans rôle ; aucune autorité frontend n'est utilisée.

## Cycle de vie juridique

Une version est créée en draft (`published_at = null`, `is_active = false`). La publication fixe les dates nécessaires, désactive d'abord l'ancienne version du même type, puis active la nouvelle. L'index unique partiel empêche deux versions actives concurrentes. Les versions publiées inactives restent servies par la liste historique.

Le bootstrap `python -m app.scripts.bootstrap_legal_documents` lit les fichiers `docs/legal/*_draft.md`, crée seulement `v1-draft` si absent et ne publie jamais. Les contenus portent explicitement la mention :

`LEGAL_TEXT_INSTITUTIONAL_APPROVAL_REQUIRED`

## Acceptations

Le client envoie l'UUID et la version exacte. Le serveur vérifie l'existence, l'égalité de version, la publication et `requires_acceptance`. Une acceptation stocke un snapshot de version et une source limitée à `web/android/ios/api`. La contrainte utilisateur/document et l'absence d'endpoint de modification rendent la preuve immuable. Aucune IP complète ni empreinte d'appareil n'est conservée.

## Export personnel JSON

L'export contient des métadonnées (`generated_at`, `user_id`, versions application/schéma) et, selon les données disponibles : profil, préférences, rôles, memberships pôle/projet, présences, posts/commentaires/réactions personnels, appartenances chat et messages écrits par l'utilisateur, notifications, tâches assignées et commentaires écrits, événements, finance personnelle, recrutement correspondant à l'email, Academy, gamification, impact créé et acceptations.

Pour les conversations, seuls les messages dont l'utilisateur est l'auteur sont exportés ; les messages privés écrits par d'autres membres ne sont pas recopiés. Toutes les collections sont filtrées par l'utilisateur ou par une relation personnelle explicite.

Sont explicitement exclus : `password_hash`, OTP, access/refresh tokens, hash de refresh token, JWT, secrets, credentials internes, payloads bruts de prestataire, clés d'idempotence et données privées d'autres utilisateurs. Les actions `data_export_requested` et `data_export_generated` n'enregistrent aucun contenu exporté.

## Workflow de suppression

Cycle utilisateur : `pending → cancelled`. Cycle administrateur : `pending → approved/rejected`, puis `approved → completed/rejected`. `completed` atteste uniquement la fin du traitement administratif dans PR-2A ; aucun compte, contenu ou FK n'est supprimé automatiquement. Le motif utilisateur et la note interne ne sont pas placés dans l'audit.

`DATA_ERASURE_PROCESS_REQUIRES_POLICY_VALIDATION`

## Stratégie future d'effacement/anonymisation

Après validation de la politique :

- supprimer les secrets, sessions, préférences et données techniques devenues inutiles ;
- anonymiser l'identité et, selon le contexte, les contributions de communication tout en conservant la cohérence des fils ;
- détacher ou pseudonymiser les participations opérationnelles lorsque cela ne détruit pas l'historique ;
- conserver seulement ce que la politique approuvée exige pour l'intégrité financière, les preuves, audits, projets, impact et archives ;
- ne pas casser les FK historiques : privilégier un utilisateur anonymisé plutôt qu'un `DELETE users` global ;
- traiter séparément médias, documents et sauvegardes selon une procédure vérifiable.

`DATA_RETENTION_POLICY_APPROVAL_REQUIRED`

Aucune durée légale n'est inventée dans cette phase.

## Sessions et propriétés de sécurité

Le login crée un refresh token opaque de 64 octets aléatoires. Seul un HMAC-SHA-256 est stocké. En production, `REFRESH_TOKEN_HMAC_KEY` est obligatoire et doit différer du secret JWT ; le fallback vers le secret de signature est limité aux environnements non production. Le refresh est verrouillé en transaction, remplacé à chaque usage et l'ancien token devient immédiatement inutilisable. Les sessions expirent par défaut après 30 jours ; les access tokens passent de 24 heures à 30 minutes.

Les nouveaux access tokens portent un `sid`. La dépendance d'authentification vérifie que cette session existe, n'est ni expirée ni révoquée. La révocation d'une session et `logout-all` invalident donc aussi les access tokens liés. Une réinitialisation de mot de passe révoque toutes les sessions. Les JWT historiques sans `sid` restent acceptés jusqu'à leur expiration naturelle afin d'éviter une déconnexion immédiate lors du déploiement.

Aucun refresh token n'est journalisé ou exporté. L'user-agent est tronqué à 255 caractères et la plateforme est un enum minimal ; aucune empreinte d'appareil n'est créée.

## Audit

Les actions suivantes sont enregistrées sans contenu sensible : `legal_document_created`, `legal_document_published`, `legal_acceptance`, `data_export_requested`, `data_export_generated`, `account_deletion_requested`, `account_deletion_cancelled`, `account_deletion_processed`, `session_revoked`, `logout_all`.

## Compatibilité et décisions restantes

Les champs historiques de la réponse auth restent présents. Les clients qui ignorent les nouveaux champs continuent à se connecter, mais l'application Flutter ne réalise pas encore le refresh automatique : elle devra intégrer le refresh sécurisé avant la recette mobile complète afin d'éviter une reconnexion après 30 minutes. Aucun changement d'UI n'est inclus ici.

Décisions externes restantes : validation institutionnelle des textes, identité juridique et canal de contact, politique de conservation par catégorie, critères d'anonymisation/suppression, délais opérationnels, personnes habilitées à traiter les demandes, règles de propriété intellectuelle/archives et processus d'incident.

## P0/P1/P2 après PR-2A

- P0 backend légal/export/suppression : contrats et persistance traités ; publication de textes réels reste bloquée par l'approbation institutionnelle.
- P1 : refresh automatique Flutter, écrans compte/légal, procédure réelle d'anonymisation, politique de rétention, tests PostgreSQL concurrents et correction de la baseline Alembic dynamique dans une future stratégie de migrations figées.
- P2 : support éventuel d'`acceptable_use`, timezone utilisateur après définition d'un contrat temporel, téléchargement asynchrone d'exports volumineux et portail opérateur de traitement.
