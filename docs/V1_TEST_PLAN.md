# EnactSpace V1 - Plan de test

Date: 2026-07-03

## Pre-requis

- Backend lance.
- Frontend lance sur desktop, Firefox ou Edge si Chrome indisponible.
- Comptes de test V1 crees via `POST /api/seed/v1-demo`.

## Tests roles

1. Login Admin.
2. Login Team Leader.
3. Login SG.
4. Login Financier.
5. Login Chef de pole.
6. Login Chef de projet.
7. Login membre simple.
8. Login Alumni valide.
9. Verifier alumni en attente bloque.
10. Verifier candidat bloque de l'app interne.

## Tests modules

1. Dashboard selon role.
2. Chat: creer discussion, envoyer message/media, verifier badge lu/non lu.
3. Posts: creer, commenter, reagir, epingler si autorise.
4. Notifications: compteur, lecture, tout lire.
5. Documents: upload, validation, refus, telechargement.
6. Membres/Poles/Projets: listes, details, affectations.
7. Presences: session, retard, absence, justification, export.
8. Finance: declaration, validation/refus, export.
9. Recrutement: campagne, candidature, review, conversion.
10. Alumni: profil, mentorat.
11. Impact: fiche, preuve, validation, export.
12. Academy: formation, lecon, quiz, progression.
13. Archives: projet historique, distinction, Hall of Fame, export.
14. Gamification: badges, points, classement.

## Tests responsive

- Fenetre desktop large.
- Fenetre reduite type mobile.
- Android si disponible.
- Verifier absence de RenderFlex overflow.
- Verifier boutons, chips, badges, pieces jointes et formulaires.

## Commandes

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter analyze --no-pub

cd C:\Users\DIOP\Documents\Enactus\enactspace
python -m compileall backend/app
git diff --check
```
