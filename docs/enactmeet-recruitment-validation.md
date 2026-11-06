# EnactMeet et entretiens de recrutement

Le formulaire de création reste disponible lorsqu’une liste de membres, de pôles ou de projets échoue. Un avertissement indique alors que les invitations pourront être complétées plus tard. Le chargement de la visioconférence peut être retenté après une erreur réseau et possède un délai de réponse borné.

## Salle d’entretien

Dans Organiser l’entretien, choisir En ligne ou Mixte puis Utiliser EnactMeet. Un serveur Jitsi privé avec authentification par jeton doit être configuré. Une salle distincte est créée pour ce candidat et les jurés de son entretien ; les autres membres de la campagne ne peuvent pas la rejoindre par leur seul rôle de juré.

Le candidat utilise son code personnel et son adresse e-mail depuis son suivi. Aucun compte membre n’est créé pour la visioconférence. L’accès exige une présélection publiée, la levée d’anonymat, un dossier retenu, une salle ouverte par le jury et un créneau allant de quinze minutes avant l’entretien à quinze minutes après sa fin prévue. Le jeton est limité à cette salle et à cette échéance. Son rôle est participant, avec `moderator=false` et `affiliation=member`.

Le remplacement du créneau ou de la composition de la salle crée une nouvelle salle et annule l’ancienne. Le passage à un lien externe ou à un entretien sur place retire l’accès EnactMeet. Un juré retiré de la campagne ne peut plus obtenir d’accès à la salle.

## Contrôle de l’installation avant la mise en ligne

Le contrôle en lecture seule du 6 novembre a confirmé les conteneurs Jitsi en service, le script de visioconférence en HTTPS, l’ouverture du port vidéo UDP, la configuration d’annonce réseau et la correspondance des paramètres d’authentification entre l’API et Prosody. La base déployée est à la révision 0033 ; cette version nécessite une migration jusqu’à 0037.

L’installation contrôlée active la vérification des jetons, mais pas le module d’affiliation. Lors du déploiement, activer le module Prosody `token_affiliation` correspondant à la version installée et vérifier les rôles dans une salle d’essai. Le jury doit pouvoir modérer ; un candidat ne doit pas obtenir les commandes d’un hôte. Conserver les secrets actuels et interdire les jetons vides. Préparer la modification dans la configuration persistante du service, pas uniquement dans le fichier généré du conteneur.

Effectuer ensuite un essai avec deux appareils : ouverture par un juré, arrivée du candidat depuis son suivi, vérification du micro et de la caméra, retour au suivi, refus d’un autre code candidat et refus après fermeture. La vérification de la configuration ne remplace pas cet essai audio et vidéo.

Documentation de référence : [authentification Jitsi](https://jitsi.github.io/handbook/docs/devops-guide/token-authentication/) et [API de visioconférence](https://jitsi.github.io/handbook/docs/dev-guide/dev-guide-iframe/).
