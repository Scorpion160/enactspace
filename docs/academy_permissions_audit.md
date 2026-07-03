# Audit permissions Academy

Date: 2026-07-03

## Perimetre verifie

- Catalogue de formations Academy.
- Lecons et progression personnelle.
- Quiz, questions et tentatives.
- Parcours recommandes selon les roles.
- Administration des formations, publication, archivage et restauration.
- Statistiques Academy et export CSV de progression.

## Roles et acces attendus

| Role | Acces attendu | Etat |
| --- | --- | --- |
| Administrateur | Gestion globale, exports, creation et publication | OK |
| Team Leader | Gestion globale via acces Enacchef/Admin | OK |
| SG | Gestion Academy utile a l'onboarding et au suivi | OK |
| Financier | Parcours role, consultation et progression personnelle | OK |
| Chef pole/projet | Parcours role, consultation et progression personnelle | OK |
| Adjoint pole/projet | Parcours role, consultation et progression personnelle | OK |
| Enacteur | Formations publiees, quiz publies et progression personnelle | OK |
| Alumni | Formations publiees et parcours alumni limite | OK |
| Candidat | Aucun acces interne avant validation | OK |

## Regles backend verifiees

- Les routes publiques internes `/academy/courses`, `/academy/quizzes/{quiz_id}`, `/academy/me/progress` et `/academy/me/paths` exigent un utilisateur actif et valide.
- Les routes de progression `/academy/lessons/{lesson_id}/start` et `/academy/lessons/{lesson_id}/complete` ecrivent uniquement pour l'utilisateur connecte.
- Les routes admin `/academy/admin/*` exigent `require_enacchef_or_admin`.
- Les formations publiees excluent les contenus archives.
- Les quiz DB publies sont corriges cote serveur; les bonnes reponses ne sont pas exposees aux utilisateurs avant soumission.
- Les tentatives de quiz sont journalisees avec score, statut et reponses soumises.
- Les lecons terminees et quiz reussis alimentent la progression personnelle.
- Les formations obligatoires terminees declenchent une notification dedoublonnee.
- Les exports CSV de progression sont reserves aux roles Enacchef/Admin.

## Regles frontend verifiees

- L'ecran Academy reste filtre par formations, quiz, cas pratiques et badges.
- Les parcours recommandes proviennent des roles reels de l'utilisateur quand le backend est disponible.
- Les cartes de formation affichent progression, statut obligatoire et action suivante sans tableau horizontal.
- Les titres longs de quiz, informations et chips de cas pratiques sont limites par `maxLines`/ellipsis.
- Les filtres et cartes utilisent des `Wrap`, `LayoutBuilder` et grilles responsives deja en place.

## Points ouverts

- Ajouter une interface Flutter dediee pour creer/modifier les formations, lecons, quiz et questions.
- Ajouter le telechargement CSV natif cote Flutter apres choix web/mobile.
- Relier les certificats Academy aux badges de gamification.
- Ajouter des parcours obligatoires automatiques lors d'une promotion de role.
