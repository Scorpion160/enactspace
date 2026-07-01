# Audit permissions Membres / Poles / Projets

Date: 2026-07-01

## Perimetre audite

- Backend: `backend/app/api/routes/users.py`
- Backend: `backend/app/api/routes/poles.py`
- Backend: `backend/app/api/routes/projects.py`
- Frontend: `frontend/lib/core/auth/user_experience.dart`

## Synthese

Les routes sensibles Membres, Poles et Projets sont protegees par des dependances backend. Le frontend masque aussi les entrees de navigation selon l'experience utilisateur, mais les permissions importantes restent bien controlees cote API.

## Membres

- Creation de membre: reservee SG/Admin via `require_sg_or_admin`.
- Liste complete des utilisateurs: reservee SG/Admin via `require_sg_or_admin`.
- Mise a jour admin d'un membre: reservee SG/Admin via `require_sg_or_admin`.
- Suspension, reactivation et passage alumni: reserves Admin/Team Leader via `require_admin_or_team_leader`.
- Assignation de roles: controlee dans `users.py` avec roles gerables par Admin, Team Leader et SG selon listes autorisees.
- Validation/rejet de comptes: reserve aux validateurs de demandes via `require_join_request_reviewer`.
- Historique: les changements admin generent `modification_admin_utilisateur`; les changements de pole coeur generent aussi `changement_pole_coeur`.

## Poles

- Creation de pole: reservee SG/Admin via `require_sg_or_admin`.
- Lecture des poles: reservee aux utilisateurs actifs valides.
- Modification de pole: reservee aux gestionnaires globaux ou responsables du pole via `require_pole_manager`.
- Affectation/retrait de membres: reserve aux gestionnaires globaux ou chef/adjoint du pole concerne.
- Nomination chef/adjoint de pole: reservee aux gestionnaires globaux Admin, Team Leader, SG.
- Un responsable nomme est rattache au pole par la meme operation.
- Historique: affectations et retraits generent `affectation_pole` et `retrait_pole` avec ancien/nouvel etat.

## Projets

- Creation de projet: reservee SG/Admin via `require_sg_or_admin`.
- Lecture des projets: reservee aux utilisateurs actifs valides.
- Modification de projet: reservee aux gestionnaires globaux ou responsables du projet via `require_project_manager`.
- Affectation/retrait de membres: reserve aux gestionnaires globaux ou chef/adjoint du projet concerne.
- Nomination chef/adjoint de projet: reservee aux gestionnaires globaux Admin, Team Leader, SG.
- Un responsable nomme est rattache au projet par la meme operation.
- Historique: affectations et retraits generent `affectation_projet` et `retrait_projet` avec ancien/nouvel etat.

## Frontend

- Les alumni ont une navigation limitee.
- Les membres simples ne voient pas les modules de gestion globale.
- Les Enacchefs voient Membres, Poles, Projets, Evenements selon `UserExperience.visibleRoutesFor`.
- Les actions de gestion restent masquees aux profils non autorises, mais le backend reste la source de verite.

## Limites connues

- La regle "un seul pole coeur principal" est appliquee cote fiche membre via `department`; les rattachements operationnels aux poles restent une liste d'appartenances.
- Les routes de lecture de poles/projets sont globales pour les utilisateurs valides. Une visibilite plus fine par appartenance peut etre ajoutee si l'organisation veut masquer certains poles/projets.
- L'audit est stocke dans `audit_logs`; il n'existe pas encore d'ecran dedie pour consulter l'historique depuis une fiche membre.
- Python n'etait pas disponible localement pendant l'audit, donc la compilation backend n'a pas pu etre relancee dans cette session.

## Validation

- `flutter analyze --no-pub`: OK
- `git diff --check`: OK
