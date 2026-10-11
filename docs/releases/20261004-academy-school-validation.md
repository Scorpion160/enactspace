# EnactSpace 1.0.2+3 — Academy et archives
Livraison du 4 octobre 2026.

## Comportement livré
- Le quiz du cours et les quiz rapides utilisent un lecteur commun : ouverture sans boucle infinie, conservation des réponses en cas d’échec d’envoi, correction fournie par le serveur après validation.
- L’enregistrement des leçons accepte les UUID issus de la base ; le calcul de progression tient compte de l’écriture courante. Les erreurs serveur ne sont plus présentées comme une absence de connexion Internet.
- Continuer reprend une leçon inachevée ou conduit au quiz ; une formation terminée reste accessible en relecture. Le bouton Commencer conserve sa largeur naturelle.
- Nouveau Enacteur propose sept formations ordonnées, dont Premiers pas dans EnactSpace et ses trois leçons d’accueil.
- Les choix des quiz, les repères et les icônes des cartes respectent le thème sombre. Les textes restent lisibles avec un agrandissement à 200 %.
- 24 formations, 74 leçons, 24 quiz et 72 questions ; 24 421 mots dans les leçons, minimum 286 mots. Les durées comprennent la lecture et la pratique, affichées séparément dans le lecteur.
- Les leçons comportent explications, exemples, exercices et repères illustrés. Les photographies du club sont embarquées et créditées Photothèque Enactus ESP.
- Les six premières Minutes sont datées de 2020 : Aïta Ndir DIA, Seydina TOURE, Ibrahima CISSE, Betty KANE, Mouhamadou Moustapha MBAYE et Papa Idrissa WADE.
- Les récits des projets, des compétitions et les légendes sont reformulés pour présenter directement l’histoire. Les données d’impact et leur contexte restent conservés.
- Le lecteur utilise des sections, des espacements et un interligne de 1,7 ; justification sur les écrans larges, alignement à gauche sur mobile ou avec un texte agrandi.

## Mise à jour des contenus
Les 71 leçons précédentes sont enrichies seulement si leur contenu correspond au texte initial. Les UUID et progressions restent conservés. Les questionnaires personnalisés ne sont pas écrasés. Les positions des réponses correctes des quiz initiaux restent compatibles avec les soumissions conservées hors connexion.

La migration 20261004_0020 vérifie la présence des colonnes avant leur ajout. Cela corrige l’installation sur une base neuve dont la migration initiale crée déjà les modèles actuels ; aucune nouvelle migration n’est requise sur la production déjà à cette révision.

## Validation
- Analyse Flutter finale : aucune anomalie.
- Suite Flutter complète : 683 tests réussis ; huit tests Academy ciblés réussis après les derniers ajustements de contraste.
- Suite serveur complète : 257 tests, huit ignorés, aucun échec ; 19 tests ciblés supplémentaires réussis après la dernière révision des légendes.
- Simulation sur la base de production, puis annulation de la transaction : 71 leçons enrichies, un cours et trois leçons ajoutés, progressions et UUID existants préservés.
- Publication : premier ajout de quatre cours/leçons ; seconde exécution sans ajout.
- Après publication : 24 cours, 74 leçons, 24 quiz, 72 questions et 24 421 mots confirmés dans la base.
- Serveur sain ; backend et workers actifs sans redémarrage. Les photographies vérifiées sont servies en HTTP 200.
- Page de connexion publiée chargée et contrôlée visuellement. Le fichier JavaScript public correspond au build local.
- Builds Android et web réussis. La cible web JavaScript est opérationnelle ; le précontrôle Wasm émet des avertissements sans empêcher cette compilation.
- Les parcours Academy sont couverts par des tests avec une API simulée et des tests serveur. Aucun parcours authentifié dans le navigateur de production n’est présenté comme vérifié.
- Aucun téléphone détecté par ADB : installation Android et biométrie sur appareil physique non vérifiées dans cette livraison.

## Déploiement et artefacts
Site : https://enactspace.kerunjombor.net/#/login
APK : C:\Users\DIOP\Downloads\EnactSpace-1.0.2-release-20261004-academy-school.apk
Paquet Android : sn.enactusesp.enactspace ; versionName 1.0.2 ; versionCode 3.
SHA-256 APK : 7bc31a267cd54326d5b0f91c4a96dd40d7effc2142e6f137068c800b9c9d457c
Certificat de signature identique à la version 1.0.1 ; SHA-256 : 38e8274a7b63174cbf06f5d5b15e68b623fdb9fae92538ad9b7f470611e484d5
SHA-256 main.dart.js : 36bf3307e4905c6ef5ef8a7c75a50c47d73a58c1b99f17fb82fae42b5f742372
Image serveur : sha256:7e7749a70e1541da4bd7e823400344b77899d805e8593020cecc3dc2a428d8d5
Tag : enactspace-backend:academy-school-20261004
Sauvegardes antérieures à la publication : /opt/enactspace/backups/academy-school-20261004
Contrôles et journaux : /opt/enactspace/staging/academy-school-20261004

Les comptes, documents privés et fichiers de configuration secrets ne font pas partie des artefacts publics. La sauvegarde et le fichier email_worker.py.before-model-registration-fix préexistant restent hors du commit.
