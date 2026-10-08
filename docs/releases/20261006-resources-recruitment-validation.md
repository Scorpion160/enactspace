# EnactSpace 1.0.10+12 — ressources historiques et recrutement

Suivi des corrections Alumni et du raccordement du jury : [20261006-alumni-review-followup.md](20261006-alumni-review-followup.md).

## Livré

- 14 Minutes datées de 2023, sans citations ou portraits inventés ; les six Minutes initiales restent en 2020.
- Présentation Dimbali, chapitres historiques SHERY et quatre récits sur le terrain et les formations. Les réalisations, essais et propositions gardent leurs périodes et leurs statuts.
- 14 images réelles optimisées, galeries accessibles dans les projets et archives, lecture des récits avec retour explicite.
- Questionnaire par défaut de 12 questions, avec coopération, apprentissage et disponibilité réaliste. Les questionnaires personnalisés des campagnes ne sont pas remplacés.
- Grille humaine versionnée, cinq critères de même poids, appréciation 0–4 et observation obligatoire. Calcul serveur, avis de plusieurs personnes, restauration de son propre avis et maintien des anciennes notes hors du nouvel indice. Aucun classement inféré depuis les réponses ni décision automatique.
- Guide commun du jury dans docs/recruitment-jury-guide.md.

## Sources et limites de lecture

695 fichiers inventoriés avec empreintes SHA-256, dont 21 doublons exacts. Le relevé individuel se trouve dans 20261006-resource-audit.json. Les textes extraits de 63 documents ont été consultés ; douze références longues ont été consultées par sections (introduction, sommaire et conclusion). Les pages sans texte extrait ne sont pas présentées comme intégralement lues.

575 images uniques examinées sur planches-contact, dont 14 examinées sur une sélection agrandie et intégrées. Deux vidéos ont été examinées à partir de huit images réparties dans chacune ; aucune transcription intégrale de leur audio n’est attestée. Les rendus techniques et la miniature embarquée du modèle Fusion ont été examinés ; la géométrie native des fichiers CAO n’a pas été ouverte. Un fichier Fusion vide est signalé comme inexploitable.

Les deux fichiers de recrutement comprennent 205 et 102 réponses. Seule leur structure et des statistiques agrégées ont servi à la révision. Le premier comporte 22 anciennes notes renseignées, sans formule ou grille retrouvée ; le second n’a pas de colonne Score. Aucun nom, réponse individuelle ou classement n’a été importé dans l’application.

## Navigation Android

Le premier essai natif de la galerie a détecté une sortie de l’application après fermeture de la photo, alors que la fiche de projet était encore ouverte. La structure réelle comporte deux ShellRoute imbriquées. Une notification du navigateur racine pouvait annoncer qu’aucun retour n’était possible après fermeture d’une fenêtre, en ignorant la pile de détails.

Un test reproduit cette structure et échoue avant correction. Le gestionnaire de notification à la racine tient maintenant compte de la pile GoRouter ainsi que des blocages PopScope. Le même test passe, annonce un retour disponible sur la fiche, puis rétablit la sortie normale sur la collection. La suite complète a été rejouée après correction. Aucun changement des composants natifs de biométrie ou visioconférence.

## Vérification

- 863 tests Flutter : réussite ; analyse statique sans problème.
- 117 tests serveur ciblés : réussite, y compris pièces jointes, candidature, confidentialité et contenus historiques.
- 19 tests PostgreSQL dans une base dédiée : réussite, dont la nouvelle grille et le journal des transitions.
- Affichage de la grille vérifié à 360 et 1440 pixels, en modes clair et sombre, texte agrandi à 1,8.
- Migration additive 20261006_0023 après sauvegarde PostgreSQL : deux colonnes nullables ajoutées. Empreintes et effectifs de toutes les lignes historiques des 110 tables métier identiques avant/après ; la seule autre modification est la révision Alembic.
- Contrôles de production en lecture seule avec le rôle décideur existant : accès privés, recrutement public, rubriques de candidature et présentations de projets. Aucun compte de test ou avis réel créé.
- Huit routes web répondent ; les quatre PDF et 14 images diffusés correspondent exactement aux fichiers vérifiés.
- APK signé avec le certificat existant, installé par mise à jour sur Samsung SM-A065F sans réinitialisation. Build final 12 installé, sans réinitialisation. La session a été déverrouillée pour poursuivre les essais physiques décrits plus bas.

Web et API : 1.0.10 ; build web et Android : 12. Empreinte du JavaScript web : ee66cc8612e8e26af967d95927e0f6231d07c786bf9159d7c035b3cb435a0589.

APK : C:\Users\DIOP\Downloads\EnactSpace-1.0.10-release-20261006-ressources-recrutement.apk ; 246 483 987 octets ; SHA-256 : c546a28185bd6500420a7668d947bfb8ea21accb6425c5df401b9957c650c264.

Sauvegarde avant mise à jour : /opt/enactspace/backups/resources-release-20261006. Retour aux anciens exécutables prévu sans suppression des données et des colonnes ajoutées. Pas de git push effectué.

Les contrôles automatisés et natifs portent sur les parcours décrits, pas sur une certification exhaustive de tout écran, toute charge ou tout appareil. Aucun test iOS réalisé.

## Essais natifs et suivi

Sur le build 11, neuf parcours ont passé : aperçu de photo de profil, liste de candidatures, ouverture de fiche, historique, fermeture, Academy, Continuer, lecture de leçon et accueil. La galerie Dimbali a affiché puis fermé la photo ; son essai a ensuite révélé le défaut de Retour Android décrit plus haut.

Sur le build 12, neuf parcours initiaux passent à nouveau. Les essais physiques de galerie Dimbali et Retour Android, puis de lecture et téléchargement SHERY avec retour à la collection, passent. L’empreinte du téléchargement QA correspond à l’original et seul ce fichier QA est supprimé. La biométrie reste activée et les paramètres temporaires de maintien d’écran sont restaurés.

L’essai de jury sur le build 12 a révélé que la grille n’était pas raccordée à la fiche candidat active. Ce point est corrigé dans le build 13 ; son suivi et les contrôles de la réparation Alumni sont documentés dans le rapport lié ci-dessus.

Les anciens essais physiques de SHERY (lecture, pages suivantes, sélection de téléchargement) de la version 1.0.9 restent documentés séparément ; ils ne remplacent pas la vérification du Retour Android sur le build final.
