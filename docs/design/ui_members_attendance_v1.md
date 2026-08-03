# EnactSpace V1 - Membres et presences

## Perimetre

Cette tranche met a niveau les ecrans Membres et Presences sans modifier les
routes, permissions, modeles ou API du backend.

Membres apporte une recherche, les filtres statut/role/pole, des cartes
responsives sous les grands ecrans, un profil organise par sections et un
formulaire d'edition pre-rempli. L'enregistrement utilise le service existant
`updateMemberAdmin` et le `PATCH /users/{id}/admin` deja disponible.

Presences clarifie les vues de gestion et de suivi, les sessions, le QR
dynamique, l'etat NFC et les actions disponibles. Le QR affiche sa rotation,
les compteurs et le journal de session. Le scanner propose une saisie manuelle
lorsque la camera n'est pas disponible.

## Captures de validation

Build web : `97FECEA63D969B81D17E758F33E3C2A01C1DF8E8B8CC1DFD1148666557AA4BE5`.

| Capture | Vue | Role de test |
| --- | --- | --- |
| 01 | Membres, desktop 1440x900 | audit.admin |
| 02 | Membres, mobile 390x844 | audit.admin |
| 03 | Profil membre, tablette 768x1024 | audit.admin |
| 04 | Edition membre, desktop 1440x900 | audit.admin |
| 05 | Gestion des presences, desktop 1440x900 | audit.secretary |
| 06 | Suivi personnel, mobile 390x844 | audit.secretary, vue personnelle |
| 07 | Detail session, tablette 1024x768 | audit.secretary |
| 08 | QR dynamique, mobile 390x844 | audit.secretary |
| 09 | Enrolement NFC, tablette 768x1024 | audit.secretary |
| 10 | Gestion des presences, grand ecran 1920x1080 | audit.secretary |

Les PNG sont dans `docs/design/screenshots/ui_members_attendance_v1/`.

## Limites constatees

- Le routeur actuel ne donne pas `/attendance` a `audit.member`. La capture 06
  prouve donc la vraie vue personnelle avec le compte secretaire, qui y a
  acces via le controle SegmentedButton. L'ouverture aux membres simples reste
  une decision de permissions a cadrer dans une tranche dediee.
- Le QR a ete genere dans la session synthetique ouverte. Le scan camera doit
  etre valide sur un telephone avec autorisation camera; dans le navigateur
  d'audit isole, le repli de saisie manuelle reste accessible.
- L'enrolement et le pointage NFC necessitent un appareil Android NFC. Le
  navigateur Windows de validation ne possede pas ce materiel, ce que l'ecran
  explique maintenant sans afficher une erreur technique brute.
