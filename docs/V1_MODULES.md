# EnactSpace V1 - Modules

Date: 2026-07-03

## Modules principaux

| Module | Role |
| --- | --- |
| Dashboard | Vue adaptee au role et aux priorites |
| Chat | Discussions privees, groupes, medias, lecture et badges |
| Posts | Fil d'actualite, reactions, commentaires, mentions, posts officiels |
| Notifications | Centre personnel, compteur, lecture/non lecture |
| Documents | Stockage, validation, partage et documents officiels |
| Membres | Annuaire, roles, validations, statut alumni |
| Poles | Structure interne, chefs, adjoints, membres et objectifs |
| Projets | Equipes, statut, budget, impact, documents et journal |
| Presences | Sessions, retards, absences, justifications, sanctions |
| Finance | Cotisations, paiements, comptes, exports |
| Recrutement | Campagnes, candidatures, anonymisation, conversion |
| Alumni | Profils, mentorat, reseau |
| Impact | Donnees impact, preuves, validations, exports |
| Academy | Formations, lecons, quiz, progression, parcours role |
| Archives | Projets historiques, prix, medias, documents historiques |
| Hall of Fame | Realisations majeures et memoire du club |
| Gamification | Points, badges, classements |

## Roles V1

- Administrateur
- Team Leader
- Secretaire generale
- Financier
- Chef de pole / adjoint
- Chef de projet / adjoint
- Enacteur / Enactrice
- Alumni
- Candidat
- Faculty Advisor

## Principe d'acces

Le frontend masque les modules selon `UserExperience.visibleRoutesFor`, mais le backend reste la source de verite via les gardes FastAPI.
