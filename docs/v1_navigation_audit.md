# Audit V1 navigation et routes

Date: 2026-07-03

## Perimetre verifie

- Routes Flutter dans `frontend/lib/app/app_router.dart`.
- Menus desktop, drawer compact et navigation mobile dans `frontend/lib/shared/layout/app_shell.dart`.
- Filtrage par role dans `frontend/lib/core/auth/user_experience.dart`.
- Redirections login, splash, suivi candidature et pages internes.

## Routes disponibles

| Route | Ecran | Etat |
| --- | --- | --- |
| `/splash` | Splash | OK |
| `/login` | Connexion / inscription / suivi acces | OK |
| `/application-tracking` | Suivi candidature public | OK |
| `/dashboard` | Dashboard role-based | OK |
| `/chat` | Chat | OK |
| `/posts` | Communication | OK |
| `/notifications` | Notifications | OK |
| `/documents` | Documents | OK |
| `/members` | Membres | OK, reserve selon role |
| `/poles` | Poles | OK, Enacchef/Admin |
| `/projects` | Projets | OK, Enacchef/Admin |
| `/attendance` | Presences | OK, SG/Admin/Team Leader/chefs |
| `/tasks` | Taches | OK |
| `/finance` | Finance | OK, financier/Admin/Team Leader |
| `/impact` | Impact | OK, Enacchef/Admin |
| `/academy` | Academy | OK |
| `/archives` | Archives / Hall of Fame | OK |
| `/alumni` | Alumni | OK, role autorise |
| `/recruitment` | Recrutement | OK, roles autorises |
| `/events` | Evenements | OK |
| `/gamification` | Gamification | OK |

## Menus et navigation

- Le menu desktop regroupe les sections principales et filtre les entrees avec `UserExperience.visibleRoutesFor`.
- Le drawer compact utilise la meme source de routes autorisees.
- La navigation mobile choisit jusqu'a cinq destinations pertinentes et remplace la derniere par la route courante si necessaire.
- Les badges chat, notifications et taches sont limites visuellement a `99+`.

## Redirections et acces

- Un utilisateur non connecte est renvoye vers `/login` sauf pour `/splash`, `/login` et `/application-tracking`.
- Un utilisateur connecte qui retourne sur `/login` est renvoye vers `/dashboard`.
- Les routes internes sont filtrees cote Flutter selon le profil cache.
- Les candidats et alumni non valides restent bloques cote backend par `get_current_active_validated_user`; ils ne doivent pas acceder aux donnees internes meme en appel direct API.
- En mode cache indisponible, seules les routes offline minimales sont tolerees.

## Correction appliquee

- Ajout d'une page d'erreur propre via `GoRouter.errorBuilder`.
- Une route inexistante affiche maintenant un message clair et un bouton retour accueil, au lieu du rendu brut GoRouter.

## Points ouverts

- Les routes dediees `/profile` et `/settings` ne sont pas encore implementees; le profil et les reglages restent integres aux ecrans existants/login/session.
- Une future V1.1 peut ajouter un ecran profil complet et un ecran parametres centralise.
