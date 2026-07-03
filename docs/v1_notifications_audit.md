# Audit V1 notifications

Date: 2026-07-03

## Perimetre verifie

- Service backend `notification_service.py`.
- Routes `/notifications`.
- WebSocket `/realtime/ws`.
- Fallback polling dans `AppShell`, `NotificationsScreen` et `ChatScreen`.
- Appels `notify_user` et `notify_users` dans les modules principaux.

## Flux couverts

| Scenario | Source | Etat |
| --- | --- | --- |
| Tache assignee | `tasks.py` | OK |
| Tache modifiee/validee | `tasks.py` | OK |
| Message chat | `chat.py` | OK |
| Conversation chat creee / participant ajoute | `chat.py` | OK |
| Reaction chat | `chat.py` | OK |
| Mention post | `posts.py` | OK |
| Post officiel / epingle | `posts.py` | OK |
| Commentaire / reaction post | `posts.py` | OK |
| Absence / retard | `attendance.py` | OK |
| Justification en attente / validee / refusee | `attendance.py` | OK |
| Sanction finance liee presence | `attendance.py` / `finance.py` | OK |
| Paiement soumis / valide / refuse / annule | `finance.py` | OK |
| Document soumis / partage / valide / refuse | `documents.py` | OK |
| Candidature recue / statut / conversion | `recruitment.py` | OK |
| Compte valide / refuse / role assigne | `users.py` | OK |
| Donnee Impact soumise / validee / refusee | `impact.py` | OK |
| Quiz reussi / formation obligatoire terminee | `academy.py` | OK |
| Badge attribue | `gamification.py` | OK |
| Archive validee / refusee | `archives.py` | OK |

## Synchronisation

- Le backend deduplique par utilisateur, type, entite et notification non lue.
- Le compteur non lu est personnel via `/notifications/unread-count`.
- La page Notifications permet lecture, non lecture, lecture globale et suppression personnelle.
- Le WebSocket envoie les variations de compteur.
- Le frontend garde un fallback polling toutes les 12 secondes pour notifications/chat.

## Correction appliquee

- La whitelist `VALID_NOTIFICATION_TYPES` inclut maintenant les types reels emis par Finance, Presences, Impact, Academy et Archives.

## Points ouverts

- Les notifications natives push FCM ne sont pas incluses en V1.
- Les notifications email/SMS externes restent hors scope V1.
- Les comptes pending peuvent lire uniquement leurs notifications personnelles si un token existe; l'acces aux modules internes reste bloque.
