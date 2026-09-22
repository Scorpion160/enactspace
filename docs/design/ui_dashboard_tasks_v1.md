# UI Dashboard + Tâches v1

## Architecture

Le Dashboard et le centre de tâches dépendent d’interfaces injectables. Les écrans de production utilisent `ApiDashboardGateway` et `ApiTasksGateway`; les tests fournissent des gateways mémoire. Les widgets ne construisent aucun service HTTP.

Le module Tâches est séparé en `models/`, `services/`, `screens/` et `widgets/`. `TasksService` reste le transport des endpoints existants. Le gateway compose le transport avec les annuaires membres, pôles et projets.

## Dashboard

`DashboardScreen` charge uniquement `GET /api/dashboard/summary`. Le profil, les rôles et les permissions de `summary.profile` remplacent l’ancien appel supplémentaire à `AuthService`.

Les priorités sont les tâches en retard, les tâches assignées, les notifications non lues, les messages non lus, les événements à venir et l’activité récente. « À suivre aujourd’hui » ne contient que les tâches en retard, notifications, messages et événements réellement signalés par le résumé.

Les compteurs `null` restent indisponibles : l’interface affiche `—` ou masque la carte spécialisée. Ils ne sont pas transformés en zéro. Les cartes métier sont conditionnées à la permission et à la présence de leur compteur.

Les états chargement, erreur, succès et données partielles sont distincts. Les raccourcis Tâches, Chat, Notifications et Événements sont conservés.

## Centre de tâches

`/tasks` propose les vues Toutes visibles, Mes tâches et En retard. La recherche et les filtres statut, priorité, pôle, projet et assigné sont appliqués côté client, avec une action Réinitialiser. Les six statuts canoniques et les quatre priorités sont toujours humanisés.

Le rendu desktop est une liste structurée dense. Sous 720 px, chaque ligne devient une carte verticale. Aucun conteneur n’impose de défilement horizontal à 390 px.

Le retard est calculé uniquement si `due_date` est antérieure à l’instant courant et si le statut n’est ni `termine`, ni `valide`, ni `annule`.

## Permissions et mutations

Les actions utilisent exclusivement `can_manage` et `current_user_assigned` fournis par le backend. Un assigné ou gestionnaire peut proposer un changement de statut et une preuve; seul `can_manage` expose l’édition et la validation. Le backend reste l’autorité finale et aucune matrice de transitions n’est répliquée dans Flutter.

La création conserve le payload existant. Pour un responsable non global, le formulaire exige un périmètre dirigé et recharge les assignés éligibles de ce périmètre. L’édition envoie seulement les champs acceptés par `PATCH /api/tasks/{task_id}`. Les boutons de mutation sont désactivés pendant l’envoi afin d’empêcher les doubles soumissions.

## Performance

Les assignés sont chargés en parallèle après la liste, avec un cache de `Future` par `taskId`. Une erreur d’assignés est capturée par tâche, affichée localement et ne fait pas échouer la liste. Les caches d’annuaire sont réutilisés. `loadCenter(..., includeDirectory: false)` permet aux consommateurs sans filtres d’éviter les appels membres/pôles/projets.

## Fiche tâche et routes

- `/tasks` : centre de tâches, avec `?view=my` ou `?view=late` depuis le Dashboard.
- `/tasks/:taskId` : fiche directement adressable.

La fiche affiche résumé, assignés, échéance, statut, priorité, périmètre, preuve et seulement les horodatages techniques réellement présents. Aucun historique métier n’est inventé et aucune suppression n’est proposée.

## Responsive et tests

Les layouts sont conçus pour 390×844, 768×1024, 1366×768 et 1440×900. Les tests utilisent des gateways mémoire, couvrent les états Dashboard, les données nulles et conditionnelles, les vues/filtres Tâches, les droits, les payloads, les mutations, le retard réel et les formats mobiles sans mutation runtime.

## Validation visuelle finale

Les huit captures de référence sont disponibles dans `docs/design/screenshots/ui_dashboard_tasks_v1/`. Elles couvrent le Dashboard desktop et mobile, le centre de tâches, la vue En retard avec filtres, les cartes mobiles, la fiche détaillée, la création non soumise et les actions autorisées.

La capture a utilisé un harness Flutter widget temporaire avec gateways mémoire déterministes, le vrai `ThemeData` EnactSpace, le vrai `AppShell`, Poppins et Material Icons chargée par `FontLoader` depuis le SDK Flutter. Le navigateur intégré n’a pas été utilisé. Le harness, les déclarations de polices et les fichiers de polices temporaires ont été retirés après génération.

Le contrôle visuel 8/8 confirme le thème EnactSpace, les glyphes d’icônes, les libellés humanisés, l’absence d’overflow, de loader bloqué, de grille desktop comprimée sur mobile et de donnée d’historique inventée. Les cinq compteurs de requêtes de mutation du gateway sont restés à zéro et aucune mutation applicative n’a été effectuée. La trace détaillée, les marqueurs atteints et les SHA-256 sont consignés dans `capture_state_results.json`.

## Limites backend

L’interface n’invente ni historique, ni matrice de transitions, ni données d’assignés lorsque l’enrichissement échoue. Les libellés de pôle/projet et les filtres assignés dépendent des annuaires accessibles au compte. Un compteur `null` signifie non disponible ou non applicable au rôle.
