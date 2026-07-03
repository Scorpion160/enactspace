# Audit V1 permissions backend

Date: 2026-07-03

## Synthese

Les routes internes EnactSpace reposent majoritairement sur `get_current_active_validated_user` ou sur un garde metier specialise. Ce garde bloque les comptes non valides, les candidats, les alumni en attente, les comptes suspendus/inactifs et les emails non verifies avant l'acces aux donnees internes.

Les routes publiques attendues restent limitees a l'authentification, la demande d'inscription, la recuperation de mot de passe, les campagnes publiques de recrutement, le depot de candidature et le suivi public par reference.

## Gardes principaux verifies

| Garde | Usage | Etat |
| --- | --- | --- |
| `get_current_user` | Token valide + compte actif | OK |
| `get_current_active_validated_user` | Compte actif, valide, email verifie | OK |
| `require_sg_or_admin` | SG, Team Leader, Admin | OK |
| `require_admin_or_team_leader` | Team Leader, Admin | OK |
| `require_finance_or_admin` | Financier, Team Leader, Admin | OK |
| `require_enacchef_or_admin` | Enacchefs, Faculty Advisor, Admin | OK |
| `require_join_request_reviewer` | SG, Team Leader, Admin, responsables pole Veille | OK |
| `require_recruitment_access` | Roles recrutement et pole Veille | OK |

## Modules audites

| Module | Protection constatee | Etat |
| --- | --- | --- |
| `auth` | Login bloque pending/rejected/suspended/email non verifie; join public cree uniquement pending | OK |
| `users/members` | Liste complete, creation, admin update et validation proteges; roles controles par autorite | OK |
| `poles` | Creation globale protegee; membres et affectations controles par roles/perimetre | OK |
| `projects` | Creation SG/Admin; membres/projet controles par roles et appartenance | OK |
| `tasks` | Lecture/action limitee acteur/assigne/responsable; creation scopee | OK |
| `chat` | Conversations et messages limites aux participants/scope | OK |
| `posts` | Feed filtre par visibilite; moderation/pin controles | OK |
| `notifications` | Notifications personnelles authentifiees; compteur non lu personnel | OK |
| `documents` | Visibilite, validation, rejet, archivage et scopes controles | OK |
| `files` | Telechargement/preview via `/api/files` controle proprietaire, role ou contexte | OK |
| `attendance` | Sessions, exports et sanctions controles SG/Admin/Team Leader ou perimetre | OK |
| `finance` | Vues globales, validations et transactions reservees roles finance | OK |
| `impact` | Gestion, validation et exports reserves Enacchefs/Admin selon action | OK |
| `academy` | Consultation compte valide; admin, exports et creation reserves Enacchefs/Admin | OK |
| `archives` | Consultation filtree; creation Enacchef; validation/export SG/Team Leader/Admin | OK |
| `alumni` | Profil personnel ou visibilite; mentorat gere par Enacchefs/Admin | OK |
| `recruitment` | Candidatures publiques separees; gestion/reviews/conversion protegees | OK |
| `dashboard` | Resume filtre selon role et statut utilisateur | OK |
| `seed` | Desactive par defaut via `ENABLE_SEED`; bloque si utilisateurs existants | OK |

## Exports et validations

- Les exports finance, presences, impact, academy et archives sont derriere des gardes de role.
- Les validations sensibles exigent Admin/Team Leader/SG ou role specialise selon module.
- Les refus critiques imposent un motif dans les modules audites.
- Les notifications auteur existent pour validations/refus majeurs.

## Risques residuels V1

- Le montage statique `/uploads` existe pour compatibilite. L'application doit continuer a utiliser `/api/files/{id}/download` et `/preview`, car ces routes appliquent les permissions.
- Les perimetres fins pole/projet sont presents sur plusieurs modules, mais certains ecrans globaux restent volontairement accessibles aux Enacchefs; a renforcer en V1.1 si besoin.
- Les routes `root` et `/health` sont publiques par design.
- Le seed initial doit rester desactive hors environnement local.

## Conclusion

La base backend V1 protege correctement les donnees internes. Les candidats et alumni non valides sont bloques avant les routes internes; les exports et validations sont reserves aux roles attendus; les fichiers doivent rester consommes par les routes API protegees.
