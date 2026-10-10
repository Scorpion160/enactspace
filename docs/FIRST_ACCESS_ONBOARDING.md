# Premières connexions et préparation des accès

Statut : parcours implémenté dans le code source le 7 octobre 2026, non encore déployé. Le déploiement final et la sortie de la redirection des courriels restent des étapes distinctes.

## Stratégie

Chaque membre choisit son propre mot de passe. Aucun mot de passe collectif, temporaire communiqué par un responsable ou envoyé par email n'est nécessaire. L'adresse email et le nom d'utilisateur sont deux identifiants possibles pour le même compte.

| Situation | Parcours |
|---|---|
| Profil précréé, sans connexion enregistrée, contact utilisable | Activation individuelle, choix du mot de passe, connexion habituelle, accueil et profil obligatoire. |
| Compte avec une connexion enregistrée | Mot de passe conservé ; accueil et complétion du profil si cette étape n'a pas encore été réalisée. |
| Profil précréé avec adresse absente ou provisoire | La SG, le Team Leader ou l'administrateur confirme l'identité et renseigne l'adresse personnelle avant l'invitation. |
| Compte déjà utilisé avec accès perdu à son adresse | Vérification individuelle, puis récupération réservée à l'administrateur. Anciennes sessions révoquées, nouveau code personnel, nouveau mot de passe choisi par le membre. |
| Mot de passe oublié, adresse toujours accessible | Parcours « Mot de passe oublié » existant. |
| Compte en attente, refusé, suspendu ou incohérent | Aucun accès ouvert par l'activation. Le statut doit être traité dans le parcours de validation approprié. |
| Administrateur de déploiement | Accès existant conservé. Le parcours de récupération du compte administrateur reste distinct de la préparation des membres. |

La distinction des anciens comptes repose sur l'historique de sessions conservé et, après mise à jour, sur les dates d'activation et d'accueil. L'absence d'historique ne prouve pas qu'une personne n'a jamais utilisé une ancienne version. Confirmer le cas avec le membre avant de préparer son accès. Ne jamais créer un deuxième compte pour contourner un contact manquant.

## Préparation par EnacChef

1. L'administrateur vérifie son propre accès après le déploiement, puis accompagne la SG et le Team Leader pour leur première connexion. Ils doivent pouvoir terminer leur accueil avant d'administrer les autres profils.
2. La SG confirme l'année courante et les statuts Enacteur, Enactrice et Alumni. Les années historiques restent conservées.
3. Depuis **Membres → Préparer les premières connexions**, consulter les catégories « Contact à compléter », « Accès à activer », « Profil à compléter » et « Accueil terminé ».
4. Vérifier chaque identité et chaque adresse personnelle avec le membre. L'adresse provisoire n'est pas présentée comme une adresse utilisable.
5. Préparer les invitations une personne à la fois lorsque l'application et le web actualisés sont disponibles. Le code expire après 30 minutes : ne pas lancer les invitations plusieurs jours avant l'ouverture.
6. Un compte déjà utilisé ne peut pas être réattribué à une autre adresse par la préparation ordinaire. L'administrateur utilise « Récupérer l'accès » après vérification, note la démarche réalisée et confirme explicitement la révocation des anciennes sessions.
7. En cas de modification concurrente du contact, actualiser la fiche avant de recommencer. Une adresse déjà utilisée par un autre compte est refusée ; la transaction conserve les anciens accès si la récupération échoue.

La récupération conserve l'identifiant interne, les rôles, les affectations et l'historique du membre. Elle remplace son ancien mot de passe par un secret aléatoire inutilisable pour lui ; seul le nouveau code envoyé à son adresse confirmée lui permet de définir son mot de passe. Une notification de sécurité est également préparée pour l'ancienne adresse lorsqu'elle est utilisable. Elle ne contient ni nouveau code ni nouvelle adresse.

## Ce que voit le membre

- Sur le téléphone : ouvrir **Première connexion** depuis la page de connexion. Sur le web : le même bouton ou le lien /activate dans l'invitation.
- Saisir son email ou son nom d'utilisateur. La réponse reste générale, même lorsqu'aucun compte ne correspond.
- Saisir le code personnel de huit chiffres reçu par email. Il est à usage unique, valable 30 minutes, avec cinq tentatives incorrectes au maximum. Un renouvellement demande d'attendre au moins une minute ; les limites de requêtes s'appliquent aussi.
- Choisir et confirmer une phrase de passe d'au moins 15 caractères. La limite est de 72 octets UTF-8 pour le mécanisme de hachage actuel. Aucun responsable ne doit demander cette phrase.
- Se connecter normalement avec le nouveau mot de passe.
- Lire l'accueil, vérifier les informations préremplies et compléter les champs obligatoires.
- Découvrir les trois repères de navigation : Academy, histoire de Enactus ESP et contribution avec l'équipe.
- Passer le contrôle des documents légaux existant, puis accéder à l'espace correspondant à son profil et à ses droits.

Les données enregistrées et la fin de l'accueil sont conservées côté serveur. Un formulaire non enregistré doit être complété de nouveau après une fermeture. Une connexion est nécessaire pour terminer la première préparation ; un accueil déjà terminé ne bloque pas ensuite la consultation hors ligne à cause de cette seule étape.

## Informations et année

Prénom, nom, téléphone, genre, année d'entrée dans Enactus ESP et département ESP sont obligatoires. Un Enacteur ou une Enactrice confirme aussi un cursus et un niveau compatibles avec le catalogue ESP. Spécialité, promotion et présentation personnelle restent facultatives.

Pour les membres actifs, l'année courante est envoyée avec le formulaire. Si elle change pendant la saisie, l'enregistrement est refusé proprement et les informations doivent être actualisées. Une confirmation scolaire déjà enregistrée pour cette année est réutilisée, avec sa date initiale ; l'accueil ne la réécrit pas.

Pour les Alumni, l'année de fin d'études est obligatoire. Le cursus et le niveau historiques restent conservés et aucune confirmation de niveau actif n'est créée par cet accueil. Le passage Alumni ne donne pas de pouvoirs administratifs hérités d'un ancien rôle.

## Courriels et ouverture officielle

Pendant les tests, conserver la redirection vers **dioppylsci@gmail.com**. L'invitation, la confirmation d'activation et les notifications de récupération utilisent la file de courriels existante et ses protections de test. Aucun de ces tests n'a envoyé un courriel réel.

Avant l'ouverture : valider la recette sur appareil et web, vérifier les courriels en redirection, traiter les travaux de mise en service restants, puis seulement effectuer la bascule approuvée vers les destinataires réels. Examiner la file de test avant cette bascule : les messages de test déjà en attente ne doivent pas devenir des invitations officielles.

## Migration et retour arrière

Le head source est désormais **20261007_0031** ; les états d’accueil et défis d’activation proviennent de la migration **20261007_0030**. La production vérifiée pendant ce lot reste **20261006_0025**. La migration ajoute les états de première connexion et les défis d'activation ; elle ne supprime pas les profils.

Le retour arrière de schéma conserve ces nouvelles colonnes et l'historique d'accueil. Une ancienne version de l'application ignore les nouveaux contrôles : conserver la maintenance pendant un retour de code et faire vérifier les conditions d'accès avant toute réouverture. La répétition de migration du lot 24 vérifie le schéma et ses données synthétiques, sans constituer à elle seule une recette de sécurité de l'ancien code.

Preuves : [bilan du lot 24](releases/20261007-prelaunch-lot24-first-access.md).

## Guide et aide pendant l’accueil

« Guide et FAQ » reste accessible avant connexion et lorsque les activités sont en maintenance. Après connexion, « Besoin d’aide ? » permet d’envoyer et de retrouver ses demandes sans terminer immédiatement le profil ; les activités restent bloquées jusqu’à la fin de l’accueil. Le centre d’aide accepte également les avis et suggestions. Voir [le fonctionnement et les personnes habilitées](HELP_SUPPORT_OPERATIONS.md).
