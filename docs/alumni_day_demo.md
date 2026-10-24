# Démonstration Alumni Day

Depuis la connexion, **Découvrir la démo** ouvre deux parcours publics :

- `/demo/enacteur` : la vie d’un membre, ses projets, son apprentissage et ses outils.
- `/demo/alumni` : la communauté, la transmission et les souvenirs.
- `/demo/alumni?section=archives` : accès direct à la capsule souvenirs pour la présentation.

Le menu permet de changer de rubrique et de profil. Sur téléphone, le bouton de menu donne accès à toutes les rubriques ; sur grand écran, la navigation reste visible à gauche. Le soleil et la lune changent l’apparence de la visite.

## Ce qui peut être essayé

Les archives proposent 40 photos publiques déjà embarquées, avec recherche, filtres par année, favoris et consultation en grand format avec attribution. Les quatre dossiers de référence des projets restent consultables avec le lecteur existant.

Les échanges, inscriptions, favoris, tâches, propositions de mentorat, brouillons et paiements sont des essais locaux. La leçon et le quiz mettent à jour la progression de visite. Le brouillon conserve son texte entre édition et aperçu. Les autres outils présentent leurs usages à travers des exemples ; les réunions et jeux multijoueurs ne lancent pas de session réelle.

Le recrutement réutilise le vrai formulaire public en six étapes et le vrai écran de suivi, avec un fournisseur de données exclusivement en mémoire. La campagne, les dossiers et les statuts sont fictifs ; aucun fichier n’est téléversé, aucun e-mail n’est envoyé et aucune conversion en compte n’est autorisée. La navigation de ce parcours est isolée pour préserver l’URL publique de la démo, même après un lien vers le suivi ou la connexion.

Les sept pôles possèdent une fiche de missions et une équipe fictive. Les demandes de participation sont simulées. Les discussions proposent trois conversations distinctes, des essais de photo et de PDF publics, les éléments partagés et le catalogue de 40 GIF animés déjà embarqués. Les historiques et médias d’essai restent propres à chaque conversation.

Les personnes et activités de démonstration sont fictives et signalées comme telles. Les photos et dossiers proviennent de ressources publiques du club. Aucun compte de démonstration n’est créé en base. La visite ne se connecte pas aux services métier, ne possède pas de jeton et n’envoie pas de message ou de paiement. Les essais disparaissent en quittant ou rechargeant le parcours. Les préférences et droits du compte réel ne sont pas modifiés.

L’annuaire Alumni authentifié utilise le nouveau visuel partagé. Les données, filtres, fiches, règles de visibilité, actions de création et actualisation conservent leur fonctionnement. Le nouveau bouton souvenirs ouvre les archives authentifiées.

## Validation avant présentation

Le script Windows sauvegarde les fichiers, refuse d’écraser une variante locale inconnue, puis lance l’analyse et les tests ciblés. Il ne construit et ne publie aucun binaire.

Le complément `sync_alumni_day_complete_windows.ps1 -PublishWeb` applique les corrections du journal du 24 octobre, ajoute les parcours manquants, puis lance l’analyse, les tests de démonstration et ceux du recrutement réel. Avec ce paramètre explicite, il enchaîne seulement après succès avec la compilation et la publication web 1.0.18+21 via le programme déjà utilisé pour les versions précédentes. Il vérifie ensuite le catalogue d’archives public et ouvre `https://enactspace.kerunjombor.net/#/demo`, également encodé dans l’affiche. Sans ce paramètre, il s’arrête après les tests.

Les tests couvrent les routes publiques strictement bornées, les deux profils, les ressources locales, l’absence d’appels réseau dans les rubriques, les petites largeurs à 200 % de texte, la discussion, les leçons, le quiz, le brouillon, les photos et la simulation de paiement. L’exécution Flutter doit être confirmée sur le poste de développement. Le formatage Dart et les chemins des ressources ont été vérifiés dans l’environnement de préparation.

Après succès, relancer complètement Flutter (touche **R**, redémarrage à chaud) et vérifier la connexion, les deux profils, une photo, une recherche, une leçon et un brouillon dans Edge. Une nouvelle compilation et la procédure de publication web habituelle sont ensuite nécessaires pour rendre la visite accessible sur le site public.

PayDunya reste en attente. Aucun paramètre de paiement, serveur ou notification n’est changé par cette livraison.
