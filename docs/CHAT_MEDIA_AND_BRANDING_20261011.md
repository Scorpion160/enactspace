# Chat et identité visuelle — correctif du 11 octobre 2026

Base : checkpoint 43c3c0747805dddea4eb02b3cd161c5bfacb6b66, version déployée 1.0.15.

## Pièces jointes
Les photos et vidéos sont présentées dans une carte avec type, nom, taille et bouton Télécharger. Le chargement utilise le client authentifié du chat. Une photo téléchargée devient une vignette ouvrable avec zoom. Les PDF sont consultables dans l'application. Les vidéos téléchargées disposent d'un lecteur avec lecture, pause et progression. Les autres documents peuvent être enregistrés pour ouverture dans leur application habituelle.
Les fichiers ne sont pas téléchargés automatiquement. Une erreur permet de réessayer. Les messages vocaux et sondages conservent leur lecteur et leurs contrôles actuels.
Le lecteur vidéo dépend des formats supportés par le navigateur ou Android ; l'enregistrement reste disponible lorsque la lecture échoue. Les données vidéo du navigateur utilisent une URL Blob locale et les fichiers temporaires Android sont supprimés à la fermeture du lecteur.

## Confidentialité des emails
Les notifications chat_message, chat_poll et chat_reaction utilisent un objet et un corps génériques, avec un lien vers /chat. Aucun aperçu du contenu, question de sondage ou réaction ne passe dans l'email. La notification interne conserve son contenu. Les emails déjà envoyés ne sont pas modifiés.

## Marques
Les logos EnactSpace et Enactus ESP sont réunis dans un composant responsive commun. Le décor photographique et l'accroche de connexion sont conservés. Le composant est utilisé dans la connexion web/mobile et le chargement Flutter. Le chargement HTML initial affiche également les deux logos jusqu'à la première image Flutter.

## Validation
Deux tests Python de la politique de confidentialité passent sans base de données ni envoi de mail.
Les tests Flutter ajoutés couvrent le téléchargement à la demande, l'erreur et sa reprise, et les logos à 320 pixels. Flutter n'est pas disponible dans l'environnement de préparation ; le script Windows exécute l'analyse et les tests avant tout nouveau build.
Vérifier ensuite dans Edge et Android : photo avec zoom, PDF, vidéo compatible, enregistrement d'un document, nouveau message avec email générique, connexion et démarrage aux petites dimensions.
Ce correctif ne réalise aucun build ni déploiement.

