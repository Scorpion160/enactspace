# Audit protections backend

Date: 2026-06-30

## Synthese

Les routes internes EnactSpace utilisent majoritairement `get_current_active_validated_user` ou un garde specialise (`require_sg_or_admin`, `require_finance_or_admin`, `require_recruitment_access`, `require_enacchef_or_admin`, `require_join_request_reviewer`). Les candidats et comptes alumni non valides restent bloques par le login et par `get_current_active_validated_user`.

## Routes publiques attendues

- `auth/login`, `auth/token`: connexion.
- `auth/join-requests`: creation de compte Enacteur/Alumni en attente.
- `auth/password-reset/*`: recuperation de mot de passe.
- `recruitment/campaigns/public`: campagnes ouvertes.
- `recruitment/applications`: depot public de candidature.
- `recruitment/applications/track`: suivi public par reference + email.

## Protections confirmees

- `users`: validation, refus, suspension, roles et passage alumni proteges par SG, Team Leader, admin ou responsables autorises.
- `finance`: vues globales, validations et transactions protegees par financier, Team Leader ou admin; vues personnelles se limitent au compte courant.
- `attendance`: creation, listes globales et fermeture reservees SG/admin/Team Leader; check-in et historique personnel restent authentifies.
- `recruitment`: gestion campagnes, candidatures, reviews et conversion protegee par `require_recruitment_access` ou SG/admin selon l'action.
- `documents`, `posts`, `chat`, `files`: routes authentifiees et protections metier par visibilite, participation, proprietaire ou role.
- `alumni`: profil personnel, visibilite et mentorat proteges; creation de mentorat reservee Enacchefs/admin.
- `impact`: reserve Enacchefs/admin.
- `gamification`: attribution et badges admin/SG/Team Leader; classements visibles aux comptes valides.
- `seasons`: creation reservee SG/admin/Team Leader; lecture reservee aux comptes valides.

## Risques residuels / TODO

- `notifications` utilise `get_current_user` pour lecture personnelle; TODO: confirmer si les comptes pending doivent recevoir uniquement des notifications de validation/refus, pas les notifications internes.
- `events`, `poles`, `projects` exposent certaines lectures aux comptes valides; TODO: ajouter une couche perimetre quand les droits pole/projet seront modelises plus finement.
- `tasks` autorise plusieurs lectures aux comptes valides; TODO: poursuivre l'audit fonctionnel par perimetre assigne/pole/projet sur les vues detaillees.
- Python local non executable dans cette session: le `.venv` pointe vers un interpreteur absent. TODO: reparer l'environnement Python pour ajouter un smoke test automatise des gardes backend.
