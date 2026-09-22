# UI Communication v1

## Architecture

Le bloc Communication conserve les transports et protocoles existants, mais les écrans dépendent désormais de trois contrats injectables : `PostsGateway`, `ChatGateway` et `NotificationsGateway`. Les implémentations API délèguent aux services existants; les tests utilisent exclusivement des gateways mémoire.

Cette séparation évite les instanciations directes de `PostsService`, `MembersService`, `AuthService`, `PolesService`, `ProjectsService`, `ChatService`, `NotificationsService` et `RealtimeService` dans les états d’écran. Aucun contrat backend n’a été modifié.

## Posts

`ApiPostsGateway` compose le feed, l’utilisateur courant, l’annuaire des membres, les pôles, les projets et les statistiques disponibles. Une erreur sur les statistiques d’une publication est isolée : la carte reste visible et affiche des actions sans inventer un compteur à zéro.

Le feed préserve la recherche, les filtres, le composer, l’upload média, les audiences pôle/projet, les annonces officielles, les réactions, les commentaires, l’épinglage et la suppression confirmée. Les commentaires ne sont chargés qu’à l’ouverture de la discussion. Le garde `_creating` empêche deux créations simultanées, y compris si deux activations surviennent avant le frame Flutter suivant.

L’édition utilise `PATCH /posts/{postId}` via `PostsGateway`. Le formulaire est prérempli et construit un payload différentiel limité à `title`, `content`, `post_type`, `visibility`, `media_file_id` et `is_official`. Les identifiants de pôle et projet ne sont jamais envoyés : le scope existant reste affiché et conservé par le backend. Le média courant est préservé lorsque l’utilisateur ne choisit aucun remplacement. L’épinglage reste géré par son contrôle dédié. Une édition réussie remplace localement la publication sans recharger le feed ni perdre la position de défilement; une erreur conserve le dialogue et toutes ses valeurs.

Les types, audiences et réactions sont humanisés dans les modèles et contrôles. Le rendu reste une colonne sur mobile et une colonne de lecture principale accompagnée du composer et des filtres sur grand écran.

## Chat

`ApiChatGateway` est une façade autour de `ChatService`, `RealtimeService`, `AuthService`, `PolesService` et `ProjectsService`. Le protocole WebSocket, la présence, le typing, les accusés de lecture, le polling de secours et les messages optimistes n’ont pas été réécrits.

Le screen conserve un rôle d’orchestration. Les régions de layout responsive, liste de conversations, en-tête, liste de messages, bulle de message, composer, nouvelle conversation, informations/participants, média et états ont été séparées dans `features/chat/widgets/` et portent leurs libellés sémantiques.

À partir de 900 px, le Chat affiche deux panneaux. En dessous, `/chat` affiche la liste puis ouvre la conversation en plein écran avec retour. `initialThreadId` reste pris en charge. Les six types réels sont proposés et humanisés : direct, group, club, pole, project et enacchef. Le choix du périmètre reste obligatoire pour les conversations pôle et projet.

## Realtime et synchronisation

Realtime reste la source rapide et le polling de douze secondes le fallback. Le verrou `_backgroundSyncing` empêche deux synchronisations complètes concurrentes. Le garde `_sending` empêche les doubles envois texte ou média. Une saisie ne recharge pas les conversations : elle n’émet que les événements typing prévus.

Les événements de présence, typing, read receipt et chat continuent d’être traités par l’orchestrateur existant. Les timers sont annulés à la fermeture de l’écran.

## Cache local et préférences

Le cache de conversations, messages et paramètres média reste géré par `ChatService` dans SharedPreferences. En cas d’indisponibilité réseau, les conversations et messages mis en cache peuvent être affichés avec l’indication « Disponible localement ».

Les conversations épinglées ou masquées et les messages épinglés sont des préférences strictement locales. L’interface ne les présente pas comme synchronisées côté serveur. Les rôles owner/admin/member et les opérations participants restent des opérations serveur lorsqu’elles sont autorisées.

## Notifications

`ApiNotificationsGateway` compose `NotificationsService` et `RealtimeService`. L’écran propose Toutes, Non lues, recherche, filtre par famille, compteur, ouverture de cible, marquage lu, marquage non lu, tout marquer lu et suppression confirmée.

Les mutations unitaires sont optimistes avec restauration de la liste et du compteur en cas d’erreur. Un verrou de refresh évite la concurrence entre polling, reprise d’application et événement realtime. L’ouverture attend le marquage lu avant la navigation. Une cible absente affiche un message explicite sans provoquer d’exception.

La présentation des notifications est centralisée dans `notification_presentation.dart`. Elle fournit un libellé, une famille et une icône pour Tâches, Publications, Chat, Événements, Présences, Finance, Recrutement, Documents, Impact, Academy, Compte/Rôle et Autres. Une valeur backend inconnue n’est jamais affichée brute.

## Permissions

Le backend reste l’autorité sur les permissions. Posts utilise l’expérience utilisateur uniquement pour éviter d’afficher manifestement à tort l’édition, l’annonce officielle, l’épinglage et la suppression ; une décision finale est toujours validée par le PATCH backend. Chat utilise `current_user_role` et `canManageMembers` pour les participants et la suppression globale. Les notifications sont limitées à l’utilisateur authentifié par le backend.

## Responsive et accessibilité

Les layouts ciblent 390×844, 768×1024, 1366×768 et 1440×900. Posts reste en colonne sur mobile, Chat ne comprime jamais ses deux panneaux à 390 px, et Notifications remplace les actions latérales par un menu compact.

Les actions nouvelle conversation, retour, options, envoi, pièce jointe, réaction, lecture/non-lecture et suppression disposent de tooltips ou de régions sémantiques. Les contrôles mobiles s’appuient sur les tailles tactiles Material standard d’au moins 44 px.

## Tests

`communication_test.dart` ajoute 27 tests sans réseau réel. Les scénarios couvrent :

- Posts : humanisation, succès, erreur, vide, officiel/épinglé, statistiques disponibles, commentaires lazy, réaction, double-submit, édition auteur/modérateur, préremplissage, payload différentiel sans scope, conservation/remplacement média, erreur d’édition et mobile 390 px;
- Chat : types/rôles, liste et non-lus, route directe, desktop deux panneaux, mobile liste puis conversation, envoi optimiste unique, typing, présence, fallback cache et création avec les six types;
- Notifications : familles, chargement, recherche, non-lues, mark read, mark unread, read all, suppression confirmée, refresh realtime, route absente et mobile 390 px.

Les tests injectent uniquement des gateways mémoire et ne déclenchent aucune mutation réseau.

## Limites backend et fonctions non traitées

Le temps réel n’est pas transformé en nouveau protocole WebSocket et le polling reste un fallback. Les préférences locales Chat ne sont pas synchronisées au serveur. Les notifications de type inconnu sont classées « Autres » tant qu’un contrat de type plus précis n’est pas disponible.

## Validation visuelle

Les huit captures finales sont disponibles dans `docs/design/screenshots/ui_communication_v1/` : Posts desktop et mobile, édition préremplie, Chat desktop et mobile, gestion de conversation, Notifications desktop et mobile.

La capture a utilisé un harness Flutter widget temporaire avec gateways mémoire déterministes, le vrai `ThemeData` EnactSpace et le vrai `AppShell`. Poppins a été déclaré temporairement pour le rendu et Material Icons a été chargée avec `FontLoader` depuis le SDK Flutter. Le navigateur intégré n’a pas été utilisé.

Le contrôle visuel 8/8 confirme le thème EnactSpace, Poppins, les glyphes Material Icons, les libellés humanisés, l’absence d’overflow, de loader bloqué et de palette Material par défaut dominante. Les préférences Chat épingler/masquer restent présentées comme locales ou limitées à l’utilisateur. Tous les compteurs de mutations Posts, Chat et Notifications sont restés à zéro ; aucune mutation applicative et aucun appel réseau réel n’ont été effectués.

Le harness, sa déclaration de fontes, les fontes temporaires et les artefacts golden intermédiaires ont été supprimés après génération. Les marqueurs atteints et les SHA-256 sont consignés dans `capture_state_results.json`.
