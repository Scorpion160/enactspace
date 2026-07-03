# Comptes de test V1

Date: 2026-07-03

## Activation

Le seed de demonstration V1 est volontairement protege.

- `ENABLE_SEED` doit etre active cote backend.
- Un Admin ou Team Leader connecte doit appeler `POST /api/seed/v1-demo`.
- Le seed est idempotent: il cree seulement les comptes/roles manquants et ne supprime rien.
- Mot de passe par defaut: `EnactSpaceV1!`

## Comptes

| Role a tester | Email | Mot de passe | Attendu |
| --- | --- | --- | --- |
| Admin | `admin.v1@enactspace.local` | `EnactSpaceV1!` | Vue globale |
| Team Leader | `teamleader.v1@enactspace.local` | `EnactSpaceV1!` | Vue globale |
| SG | `sg.v1@enactspace.local` | `EnactSpaceV1!` | Membres, presences, validations |
| Financier | `finance.v1@enactspace.local` | `EnactSpaceV1!` | Finance globale |
| Chef de pole | `chefpole.v1@enactspace.local` | `EnactSpaceV1!` | Perimetre pole/projets |
| Chef de projet | `chefprojet.v1@enactspace.local` | `EnactSpaceV1!` | Perimetre projet |
| Membre simple | `membre.v1@enactspace.local` | `EnactSpaceV1!` | Espace enacteur |
| Alumni valide | `alumni.v1@enactspace.local` | `EnactSpaceV1!` | Espace alumni |
| Alumni en attente | `alumni.pending.v1@enactspace.local` | `EnactSpaceV1!` | Connexion bloquee |
| Candidat | `candidat.v1@enactspace.local` | `EnactSpaceV1!` | Connexion interne bloquee |

## Donnees creees ou verifiees

- Roles principaux EnactSpace.
- Saison courante.
- Poles Tech, Chimie, Gestion, IT, Communication, Organisation et Veille.
- Projets Aquatus, Men Nan, Terrasen, Cherry et Dimbali.
- Badges de gamification de base.
- Comptes de test non sensibles.

## Notes

- Changer le mot de passe dans la requete si un autre secret local est souhaite.
- Ne pas activer `ENABLE_SEED` en production.
- Les comptes pending servent a verifier les blocages d'acces et ne doivent pas entrer dans l'app interne.
