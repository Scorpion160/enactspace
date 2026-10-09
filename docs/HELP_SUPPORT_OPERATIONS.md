# Centre d’aide, guide et traitement des retours

Statut : lot 25 implémenté et testé dans le dépôt de référence, sans livraison en production.

## Parcours des personnes

| Personne | Accès et actions |
|---|---|
| Avant connexion | « Guide et FAQ » sur la page de connexion. Lecture sans compte, sans requête privée, y compris lorsque la maintenance bloque les activités. |
| Membre pendant l’accueil | « Besoin d’aide ? » ouvre ses demandes et avis. Ce chemin ne donne pas accès aux autres activités avant la fin du profil obligatoire. |
| Enacteur, Enactrice ou Alumni habilité | Guide, FAQ, nouvelles demandes, conversation personnelle, avis, états et réponse publique. Aucun accès aux échanges d’un autre membre. |
| Administration, Team Leader ou SG actifs et habilités | Depuis le centre d’aide, « Traiter les demandes et avis » : recherche, filtres, prise en charge, priorité, réponse, suivi et notes internes des avis. |
| Ancien responsable devenu Alumni, compte suspendu ou incohérent | Aucun accès de traitement hérité. Les droits et l’état du compte sont revérifiés côté serveur. |

Le guide présente sept rubriques : accès, équipe et Alumni, tâches, Academy, projets et impact, année et profil, puis aide et suggestions. Les quinze réponses de FAQ disposent d’une recherche qui prend en compte les accents français. Les textes sont embarqués ; les demandes et leur enregistrement nécessitent une connexion au serveur.

## Demande d’aide

Le membre renseigne un sujet, une catégorie, une priorité et un message. Décrire l’écran, les étapes réalisées, le résultat attendu et le problème observé permet une réponse utile. Ne jamais demander ni transmettre de mot de passe ou de code personnel.

Le formulaire ne ferme qu’après confirmation du serveur. Un échec garde le texte pendant que la fenêtre reste ouverte. Une fermeture volontaire ne crée pas de brouillon permanent. Les boutons sont désactivés pendant l’envoi ; une nouvelle tentative du même contenu conserve son identifiant d’envoi pour éviter les doublons. Un contenu modifié utilise un nouvel identifiant.

Le membre retrouve sa conversation dans « Mes demandes d’aide ». Les responsables peuvent prendre la demande en charge eux-mêmes, libérer leur prise en charge, modifier la priorité, répondre et faire évoluer l’état. La réponse affichée dans la conversation est le message destiné au membre. L’API accepte également l’affectation à un autre responsable actif et habilité ; l’écran de ce lot propose la prise en charge personnelle et sa libération.

| État actuel | Changements autorisés |
|---|---|
| Ouverte | En cours, résolue, clôturée |
| En cours | Ouverte, résolue, clôturée |
| Résolue | En cours, clôturée |
| Clôturée | Ouverte |

Une réponse du membre à une demande résolue la remet en cours. Une demande clôturée ne reçoit plus de réponse du membre ; un responsable peut la rouvrir et peut encore y ajouter une dernière réponse. Une modification faite sur une ancienne version de la fiche est refusée : actualiser avant de poursuivre, afin de ne pas écraser l’intervention d’une autre personne.

## Bugs, suggestions et avis

« Donner mon avis » propose problème, idée, facilité d’utilisation et autre. La note de 1 à 5 reste facultative. La plateforme et la version peuvent accompagner l’avis lorsque ces informations sont disponibles ; leur indisponibilité ne bloque pas l’envoi. Ce lot n’ajoute pas de pièces jointes aux avis.

« Mes avis » affiche les états reçu, étudié, prévu et clôturé. En ouvrant un avis, son auteur retrouve le texte complet et la réponse publique de l’équipe. Dans le traitement, deux champs distincts sont disponibles : réponse visible par le membre et note interne. La note interne est réservée aux responsables habilités ; elle ne figure ni dans les API personnelles, ni dans l’export de données du membre, ni dans le contenu des notifications. Une modification de la seule note interne ne notifie pas le membre.

| État actuel | Changements autorisés |
|---|---|
| Reçu | Étudié, prévu, clôturé |
| Étudié | Reçu, prévu, clôturé |
| Prévu | Étudié, clôturé |
| Clôturé | Étudié |

## Alertes et protections

Une nouvelle demande ou un avis prépare une notification pour les responsables. La réponse d’un membre alerte le responsable affecté ou l’équipe habilitée ; une réponse ou un changement de suivi informe l’auteur. Une affectation informe le responsable concerné. Les liens de notification conduisent au centre d’aide ou à son traitement selon le destinataire. Les messages d’alerte ne recopient pas le contenu des bugs ou les notes privées.

Les préférences et les canaux existants s’appliquent aux notifications. Pendant les essais, SMTP et push restent désactivés et la redirection de test vers dioppylsci@gmail.com est conservée. La mise en file et le routage ont été testés ; la réception réelle sur téléphone et par email appartient à la recette finale.

Le serveur sérialise les écritures, relit les comptes et les droits, protège les conversations personnelles et contrôle les transitions. Par période de quinze minutes, un compte peut créer dix demandes, vingt avis et soixante messages de conversation ; les messages initiaux sont compris dans cette dernière limite. Une nouvelle tentative idempotente ne crée pas un second enregistrement ni une seconde alerte. Les anciens clients sans identifiant d’envoi restent acceptés, sans bénéficier de cette déduplication par clé. Ces plafonds ne constituent pas une protection générale contre toutes les formes de déni de service.

## Schéma et mise en service

La migration 0031 ajoute les identifiants d’envoi, leurs empreintes et la réponse publique des avis. Elle conserve les demandes existantes. Son retour arrière conserve aussi ces champs afin de ne pas perdre les échanges ; garder la maintenance lors d’un retour à un ancien code qui ne connaît pas les nouveaux contrôles.

Avant ouverture, livrer ensemble les versions backend, app et web compatibles. Réaliser la recette finale avec des identités synthétiques, sur téléphone et navigateur, puis vérifier les notifications en redirection avant la bascule approuvée. Les essais de migration et les tests automatisés de ce lot ne remplacent pas cette recette ni la revue complète du dépôt.

Preuves : [bilan du lot 25](releases/20261007-prelaunch-lot25-help.md).
