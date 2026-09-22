# Phase 0A - Inventory before capture

## Reconciliation with the initial inventory

The initial count of six only described direct `showDialog` matches. The widened
source inventory finds 44 dialog call sites, 21 sheet mechanisms, 13 native
date/time/file selection mechanisms, eight popup menus, 303 select controls,
one explicit tab bar, 23 route declarations and 25 screen files. These are
source mechanisms, not yet verified runtime views.

## Route control (22 user-facing routes; 23 declared routes)

The route table is in `routes_inventory.csv`. It contains the three root/public
routes and 20 routes under `AppShell`, for 23 declared `GoRoute` entries. The
requested 22-route control set excludes `/splash`, which is a transient
bootstrap route rather than a user destination. `ShellRoute` itself is
structural and is not counted as an application route. The app router also
declares a route-not-found error builder; it is catalogued as a global error
state, not a route.

| Route | Fichier / widget | Roles | Sous-vues principales | Etats pertinents | Forecast avant dedup |
| --- | --- | --- | --- | --- | ---: |
| `/login` | `login_screen.dart` / `LoginScreen` | public | connexion, OTP, inscription, guide, biometrie | default, validation, loading, erreur | 96 |
| `/application-tracking` | `application_tracking_screen.dart` / `ApplicationTrackingScreen` | candidat | formulaire, suivi, resultat | default, validation, vide, succes | 30 |
| `/dashboard` | `dashboard_screen.dart` / `DashboardScreen` | connecte | hero, metriques, alertes, actions | loading, partial, erreur, role | 132 |
| `/members` | `members_screen.dart` / `MembersScreen` | gouvernance | liste, profil, roles, cycle de vie, import | empty, filtre, permission, confirmation | 130 |
| `/attendance` | `attendance_screen.dart` / `AttendanceScreen` | presence | sessions, creation, filtres, export | empty, erreur, permission | 100 |
| `/attendance/scan` | `attendance_qr_scanner_screen.dart` / `AttendanceQrScannerScreen` | presence | camera, saisie manuelle, resultat QR | permission, expire, erreur | 80 |
| `/attendance/nfc` | `attendance_nfc_enrollment_screen.dart` / `AttendanceNfcEnrollmentScreen` | presence | enrollement, badge, historique NFC | indisponible, deja utilise, vide | 120 |
| `/tasks` | `tasks_screen.dart` / `TasksScreen` | non-alumni | liste, detail, formulaire, commentaire | empty, filtre, validation | 78 |
| `/finance` | `finance_screen.dart` / `FinanceScreen` | admin, TL, finance | comptes, frais, paiements, preuve | permission, validation, confirmation | 120 |
| `/recruitment` | `recruitment_screen.dart` / `RecruitmentScreen` | recrutement | campagnes, candidat, evaluation, decision | empty, anonymise, validation | 130 |
| `/documents` | `documents_screen.dart` / `DocumentsScreen` | non-alumni | bibliotheque, depot, apercu, partage | empty, erreur fichier, permission | 80 |
| `/notifications` | `notifications_screen.dart` / `NotificationsScreen` | connecte | centre, filtres, recherche, cible | empty, erreur, action repetee | 56 |
| `/posts` | `posts_screen.dart` / `PostsScreen` | connecte | fil, composer, commentaire, reactions | empty, media, permission, erreur | 96 |
| `/chat` | `chat_screen.dart` / `ChatScreen` | connecte | liste, conversation, groupe, media, epingles | empty, offline, long contenu, permission | 120 |
| `/poles` | `poles_screen.dart` / `PolesScreen` | enacchef | liste, fiche, equipe, objectifs, archive | empty, permission, confirmation | 130 |
| `/projects` | `projects_screen.dart` / `ProjectsScreen` | enacchef | liste, fiche, equipe, budget, livrables | empty, partial, permission, confirmation | 140 |
| `/events` | `events_screen.dart` / `EventsScreen` | connecte | liste, detail, participants, rapport | empty, validation, annulation | 100 |
| `/alumni` | `alumni_screen.dart` / `AlumniScreen` | alumni et gouvernance | annuaire, profil, mentorat, opportunites | tab, empty, filtre, permission | 88 |
| `/gamification` | `gamification_screen.dart` / `GamificationScreen` | non-alumni | classement, badges, attribution | empty, permission, confirmation | 76 |
| `/academy` | `academy_home_screen.dart` / `AcademyHomeScreen` | connecte | catalogue, cours, cas, ressources | filtre, progression, indisponible | 75 |
| `/archives` | `archives_screen.dart` / `ArchivesScreen` | connecte | annees, bureaux, projets, prix, recits | empty, erreur, recherche | 60 |
| `/impact` | `impact_dashboard_screen.dart` / `ImpactDashboardScreen` | enacchef | indicateurs, periode, preuves, classement | empty, partial, filtre | 99 |

The 22 user-facing routes total 2,136 planned captures before deduplication.
The transient `/splash` route adds 28 bootstrap captures, bringing the full
technical forecast to 2,164 before the 612 provisional deduplication candidates.

Those 612 are candidates only. Phase 0A approves zero deduplications because
no layout, role, permission or responsive behavior has been observed at
runtime. The conditional 1,552-screen total is valid only after every accepted
deduplication receives a reference in `capture_plan.csv`; otherwise the
conservative capture target remains 2,164.

## Screen-file control

| File | Route | Local classes | Dialogs | Sheets | Forms | Pickers | Menus/selects | Breakpoint signals | Forecast before dedup | Static subviews / states to capture |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| academy_home_screen.dart | academy | 32 | 1 | 2 | 0 | 0 | 1 | 6 | 75 | catalogue, cours, cas, ressources, recherche, filtres, progression, detail, indisponible |
| alumni_screen.dart | alumni | 22 | 0 | 3 | 2 | 0 | 19 | 12 | 88 | annuaire, profil, mentorat, opportunite, demande, filtres, etat vide |
| archives_screen.dart | archives | 28 | 0 | 2 | 0 | 0 | 0 | 15 | 60 | annees, bureaux, projets, prix, recits, chronologie, recherche, vide, erreur |
| attendance_nfc_checkin_screen.dart | embedded | 5 | 0 | 0 | 0 | 0 | 0 | 3 | 30 | checkin, nfc indisponible, log, erreur |
| attendance_nfc_enrollment_screen.dart | attendance/nfc | 7 | 0 | 0 | 0 | 0 | 0 | 3 | 60 | enrollement, badge actif, deja utilise, filtre, vide, indisponible |
| attendance_qr_scanner_screen.dart | attendance/scan | 3 | 0 | 1 | 0 | 0 | 0 | 1 | 80 | camera, token manuel, QR valide, expire, permission, erreur |
| attendance_screen.dart | attendance | 21 | 2 | 0 | 1 | 2 | 15 | 12 | 100 | sessions, creation, filtres, detail, QR, NFC, export, vide, erreur |
| attendance_session_detail_screen.dart | local push | 16 | 4 | 0 | 0 | 0 | 0 | 17 | 30 | entetes, attendus, pointage, justifications, journal QR, cloture, conflits |
| login_screen.dart | login | 22 | 6 | 2 | 0 | 0 | 3 | 5 | 96 | connexion, oublie, OTP, nouveau mot de passe, rejoindre, recrutement, guide, biometrie |
| chat_screen.dart | chat | 42 | 5 | 1 | 0 | 1 | 18 | 16 | 120 | liste, conversation, info, groupe, participant, media, galerie, epingles, actions message, hors ligne |
| dashboard_screen.dart | dashboard | 28 | 0 | 0 | 0 | 0 | 0 | 17 | 132 | hero, metriques, focus role, alertes, activite, quick actions, loading, erreur |
| documents_screen.dart | documents | 14 | 3 | 0 | 1 | 1 | 31 | 8 | 80 | bibliotheque, recherche, filtres, depot, apercu, rattachement, partage, suppression |
| events_screen.dart | events | 24 | 2 | 3 | 1 | 4 | 20 | 10 | 100 | liste, detail, participants, budget, documents, rapport, formulaire, annulation |
| finance_screen.dart | finance | 24 | 4 | 1 | 2 | 1 | 17 | 13 | 120 | dashboard, comptes, frais, paiements, mobile money, preuves, creation, confirmation |
| gamification_screen.dart | gamification | 21 | 1 | 0 | 1 | 0 | 7 | 16 | 76 | classement, points, badges, attribution, retrait, filtres, vide |
| impact_dashboard_screen.dart | impact | 28 | 0 | 1 | 0 | 0 | 0 | 17 | 99 | indicateurs, classements, periode, comparaison, preuves, vide |
| members_screen.dart | members | 26 | 6 | 3 | 1 | 0 | 34 | 7 | 130 | liste, profil, roles, lifecycle, finance, presence, import, suppression |
| notifications_screen.dart | notifications | 12 | 0 | 0 | 0 | 0 | 20 | 3 | 56 | centre, filtre, recherche, cible, marquer lu, vide, erreur |
| poles_screen.dart | poles | 30 | 0 | 4 | 2 | 0 | 16 | 9 | 130 | liste, fiche, equipe, objectifs, stats, documents, taches, creation, archive |
| posts_screen.dart | posts | 23 | 1 | 0 | 0 | 1 | 34 | 14 | 96 | fil, composer, medias, commentaire, reactions, detail, filtres, vide, erreur |
| projects_screen.dart | projects | 31 | 0 | 4 | 2 | 2 | 19 | 16 | 140 | liste, fiche, equipe, jalons, budget, livrables, documents, creation, archive |
| application_tracking_screen.dart | application-tracking | 8 | 0 | 0 | 1 | 0 | 0 | 3 | 30 | formulaire, invalide, en attente, acceptee, rejetee, inexistante |
| recruitment_screen.dart | recruitment | 36 | 6 | 0 | 2 | 3 | 40 | 15 | 130 | campagnes, besoins, candidats, detail, evaluation, entretien, decision, stats |
| splash_screen.dart | splash | 2 | 0 | 0 | 0 | 0 | 0 | 1 | 28 | initialisation, session, redirection |
| tasks_screen.dart | tasks | 16 | 2 | 0 | 1 | 1 | 17 | 7 | 78 | liste, detail, form, assignation, commentaire, piece jointe, filtres, vide |

## State model used for later capture

The following state vocabulary is used in `views_inventory.csv`: `default`,
`loading`, `loaded`, `empty`, `filtered_empty`, `partial_data`,
`validation_error`, `network_error`, `server_error`, `permission_denied`,
`session_expired`, `offline`, `success`, `destructive_confirmation`,
`long_content`, `missing_image`, `broken_image`, `slow_loading`, and
`repeated_action`. A state marked `runtime_required` is not asserted to exist
until a test account and data fixture trigger it.

## Entry-map rules

`context.go` is used for normal route replacement/navigation. QR and NFC are
direct sub-routes; attendance session detail uses a local `Navigator.push`.
Most CRUD detail/form flows use dialogs or sheets, so they cannot be linked or
reloaded directly by URL. `AppShell` is the only shared navigation surface and
computes visible destinations from `UserExperience.visibleRoutesFor`.

## Pre-capture blocking conditions

1. An isolated backend/database fixture environment is required before any
   authenticated capture.
2. Test roles must be seeded with distinct permissions plus one synthetic
   multi-role account; no production account may be used.
3. Camera/NFC/browser permission tests require a compatible device or simulator.
4. File/media, Mobile Money and realtime error paths require controllable test
   endpoints or test doubles.
5. The deployment/source revision must be identified before comparing a local
   capture with the production UI.
