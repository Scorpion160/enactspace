# Audit permissions Dashboard

Date: 2026-07-01

## Perimetre audite

- Backend: `backend/app/api/routes/dashboard.py`
- Backend: `backend/app/api/deps.py`
- Frontend: `frontend/lib/features/dashboard/screens/dashboard_screen.dart`
- Frontend: `frontend/lib/features/dashboard/models/dashboard_summary_model.dart`
- Frontend: `frontend/lib/core/auth/user_experience.dart`

## Synthese

Le Dashboard principal utilise maintenant une route dediee `GET /api/dashboard/summary`. Cette route est protegee par `get_current_active_validated_user`, donc un compte non connecte, inactif ou non valide ne doit pas recevoir de synthese applicative.

Les compteurs sensibles sont calcules cote backend selon les roles reels de l'utilisateur. Le frontend adapte ensuite les cartes, actions rapides et panneaux d'attention, mais le backend reste la source de verite.

## Acces de base

- Tous les utilisateurs actifs et valides voient leurs propres notifications non lues.
- Tous les utilisateurs actifs et valides voient leurs taches assignees, taches en retard et taches terminees.
- Tous les utilisateurs actifs et valides voient leurs messages non lus, calcules via leurs conversations.
- Tous les utilisateurs actifs et valides voient leurs points et badges personnels.
- Tous les utilisateurs actifs et valides voient une activite recente limitee a leurs notifications, posts visibles, taches et documents accessibles.

## Membre simple

- Ne voit pas les dettes, paiements ou totaux financiers globaux.
- Ne voit pas les absences ou retards des autres membres.
- Ne voit pas les statistiques globales membres, poles ou projets.
- Voit les documents internes/publics, ses propres documents et les documents rattaches a ses poles/projets.
- Voit les evenements globaux ou rattaches a son perimetre.
- Voit les posts internes/publics, ses propres posts et les posts rattaches a ses poles/projets.

## Alumni

- Voit un Dashboard plus leger, centre sur l'information utile et le lien communautaire.
- Voit les posts publics ou alumni.
- Voit les documents publics ou alumni.
- Ne voit pas les finances internes.
- Ne voit pas les absences, retards ou statistiques administratives.
- Ne voit pas les compteurs de recrutement ou validation documentaire.

## Enacchef et responsables de perimetre

- Les responsables de pole/projet et membres Enacchef disposent d'une vue enrichie.
- Ils peuvent voir les compteurs poles/projets et les actions rapides liees a leur pilotage.
- Leur acces aux evenements, posts et documents reste filtre par appartenance pole/projet quand ils n'ont pas de role global.
- Les absences visibles restent limitees a leur propre perimetre sauf role secretariat/global.

## Secretariat, Team Leader et Admin

- Les roles de secretariat et gestion globale peuvent voir les membres actifs/inactifs.
- Ils peuvent voir les absences et retards globaux.
- Ils peuvent voir les documents en attente de validation.
- Ils peuvent voir dans l'activite recente les affectations pole/projet issues des journaux d'audit.
- La vue globale Dashboard est reservee aux roles inclus dans les constantes backend de gestion globale et secretariat.

## Financier

- Le financier voit les paiements en attente.
- Le financier voit les montants dus et payes.
- Ces donnees ne sont pas exposees aux membres simples ni aux alumni.
- Le Dashboard ne valide pas les paiements directement; il sert de point d'entree vers le module Finance.

## Recrutement

- Les compteurs de candidatures en attente sont limites aux roles autorises par `RECRUITMENT_ACCESS_ROLES`.
- L'activite recente de recrutement est ajoutee seulement pour ces roles.
- Les autres profils ne recoivent pas de donnees de candidature depuis le Dashboard.

## Frontend

- Les cartes principales restent communes pour garder une experience simple.
- Les cartes de role changent selon `DashboardProfileModel` et `UserExperience`.
- Les actions rapides sont filtrees par routes visibles et permissions.
- Les panneaux sont responsive: grille large sur desktop, colonnes empilees sur mobile, textes tronques proprement.
- Les badges et metriques compactes ont des contraintes de largeur pour eviter les overflows sur telephone.

## Limites connues

- Le Dashboard s'appuie sur les scopes poles/projets existants. Si l'organisation veut masquer plus finement certains posts, documents ou evenements, il faudra renforcer les filtres metier des modules sources.
- Les conversations privees sont comptees via les participants et les dates de lecture, mais l'affichage detaille reste dans le module Chat.
- Les actions rapides masquent l'acces cote frontend, mais chaque module cible doit conserver ses propres protections backend.

## Validation

- `flutter analyze --no-pub`: OK
- `python -m compileall backend/app`: OK avec le Python embarque Codex
- `git diff --check`: OK
