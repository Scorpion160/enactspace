# Page publique Postuler — 17 octobre 2026

## Direction
Benchmark : Enactus UK & Ireland (https://www.enactusuki.org/join/), AIESEC (https://virtual-program.aiesec.org/membership), Handshake (https://joinhandshake.com/students/). Inspiration structurelle : invitation et action dès l’accueil, bénéfices courts, explication du parcours. Aucun chiffre, promesse, témoignage ou visuel de ces organismes n’est repris.

## Comportement
Un bandeau aux couleurs Enactus présente une accroche, une invitation et une photo existante de la photothèque. Le bouton Découvrir les candidatures ouvertes défile vers les campagnes sans sélectionner arbitrairement une campagne. Les campagnes précèdent les récits et la FAQ. Chaque campagne conserve son identifiant, son titre, sa description et son bouton relié à /recruitment/apply/:id. Les dates sont présentées en français, avec un repli Dates à confirmer si elles manquent.

Le suivi /application-tracking est accessible dès l’accueil. La flèche AppBar conserve le retour existant vers /login ; le deuxième bouton Retour à la connexion est supprimé. Chargement, échec avec réessai et liste vide restent distincts. En absence de campagne, aucun bouton de candidature n’est proposé. La progression annoncée ne garantit ni entretien ni admission : les étapes dépendent de la campagne.

Les photographies et leurs sources sont conservées, avec l’agrandissement existant au toucher. Trois cartes courtes présentent l’action, les idées et l’apprentissage. La FAQ déplie les documents, l’expérience préalable, l’évaluation et le suivi. Les animations de défilement respectent la réduction des animations. Pas de dépendance supplémentaire ni de nouvel appel API.

## Vérification
Validation Flutter à exécuter sur Windows via tools/sync_recruitment_landing_windows.ps1 : analyse des cinq fichiers Dart, parcours public, accueil aux largeurs 320/390/1200, texte 100/200 %, clair/sombre, FAQ, absence de campagne, navigation candidature et suivi, régressions campagnes. Le script sauvegarde les fichiers avant remplacement et refuse les sources locales inconnues. Aucun test Flutter n’a été exécuté dans l’environnement de préparation, où le SDK est absent. Vérifier ensuite dans Edge et sur téléphone : action visible, photo, accès aux campagnes, lisibilité et navigation clavier. Aucun build ou déploiement réalisé.
