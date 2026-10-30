# Academy : accueil, formations, parcours et lecture

Base : version web 1.0.19+22, commit `d0208c8d594478b39357eb5b261c721850c92839`.

## Présentation

Les maquettes du 17 octobre servent de référence. Les écrans utilisent des widgets Flutter et les illustrations locales existantes : aucun écran n’est remplacé par une capture. La palette ivoire/bleu nuit, le turquoise, les actions jaunes et la forme des cartes sont partagés dans `AcademyStyle`, limité à Academy.

- Accueil : progression plus compacte sur téléphone, illustrations panoramiques du catalogue sur ordinateur, catégories lisibles, et conservation du gateway dans les liens de navigation.
- Formation : bannière illustrée, durée/niveau/points réels, action de reprise, programme numéroté, progression et quiz. Les grands écrans disposent d’une colonne secondaire ; les petits écrans et les grands textes sont empilés.
- Parcours : progression, étapes, états terminés/en cours/à débloquer et liens vers les prérequis. Les formations non publiées ne sont pas présentées comme accessibles.
- Lecture : vue dédiée, titres complets, photo originale avec sa source, objectifs et exercices distingués, programme latéral ou volet mobile, sommaire sur grand écran, texte agrandissable et apparence locale. La barre d’actions reste accessible en bas.
- Quiz : progression des réponses choisies et résultats mis en forme dans le même style ; les scores et explications proviennent toujours du gateway.

## Fonctionnement

Lire et passer d’une leçon à l’autre ne la termine pas. Le démarrage utilise `startLesson`; seule l’action explicite de validation appelle `completeLesson`. Une validation en cours bloque les autres actions pour éviter un second envoi ; un échec conserve la lecture et permet de réessayer. La fiche est rechargée après fermeture du lecteur, et le quiz conserve les prérequis du modèle serveur.

Les services, le cache, la file hors connexion, les règles de points et les API ne sont pas modifiés. Les erreurs réseau restent traitées par le gateway existant. Les dépendances de démonstration continuent d’être transmises aux pages réelles. Aucune opération de paiement, notification ou migration n’est ajoutée.

Les leçons ne sont ni résumées ni réécrites. Le découpage des paragraphes sert uniquement à la présentation ; les repères illustrés existants restent accessibles dans « Les idées en image ». Les photos réelles ne sont pas remplacées par les personnes dessinées dans les maquettes.

## Vérifications

- Analyse Dart des sources Academy et du nouveau fichier de tests, avec les sources Flutter officielles 3.47.5 et les dépendances verrouillées.
- Contrôle local du parseur sur les 107 297 caractères du fichier pédagogique : texte conservé sur 289 sections, après normalisation des espaces et des marqueurs de titre.
- Tests Flutter à exécuter sous Windows : accueil existant, fonctionnement pédagogique et hors connexion, matrice formation/lecteur à 320/390/1024/1440 pixels, clair/sombre et texte 100/200 %, navigation, échec de validation et démo native.
- Les tests de refonte peuvent produire 24 captures dans le dossier de sauvegarde avec `--dart-define=ACADEMY_CAPTURE_DIR=...`. La galerie locale permet leur contrôle visuel avant tout build ou publication.

Le script d’intégration vérifie les empreintes, refuse les modifications locales inconnues et sauvegarde tous les fichiers remplacés. Il exécute l’analyse et les tests puis ouvre la galerie. Il ne lance aucun build ou déploiement. Le rendu final et les tests Flutter restent à confirmer sur Windows avant publication.

### Retour des tests Windows du 29 octobre

L’analyse Flutter est passée. La première exécution compte 56 tests réussis et six échecs : quatre interactions avant le rendu du défilement à 200 % sur petit écran, une interaction de quiz avant ce même rendu, et un titre de leçon recherché sans distinguer le lecteur du programme de la fiche restée derrière la boîte de dialogue. Les tests attendent maintenant la nouvelle disposition et vérifient que les boutons reçoivent réellement les appuis ; le titre est recherché dans le contenu du lecteur. Aucun scénario, aucune assertion de progression et aucun prérequis de quiz ne sont retirés. Les tests corrigés et la galerie restent à confirmer sous Windows.

### Retour des tests Windows du 30 octobre

L’analyse Flutter et les 62 tests Academy, fonctionnement pédagogique, Alumni, gamification et Impact sont passés. Dans la série de démo native, 28 tests passent et le seul échec concerne les dates françaises du chat : le test monte les écrans sans exécuter `main()`, qui appelle déjà `initializeDateFormatting('fr_FR')` dans l’application. Le test initialise maintenant les mêmes données locales avant ses scénarios, comme les tests Communication existants. Aucun comportement de production ni contrôle d’isolation de la démo n’est modifié. La relance de la démo et le contrôle visuel des 24 captures restent à confirmer avant le build.

### Contrôle visuel des 24 captures du 30 octobre

Les 24 images transmises (accueil, formation, parcours et lecteur, en clair/sombre, de 320 à 1440 pixels) ont été comparées aux maquettes du pack original. Le lot correspond au code `afb07d64e9fd11d82dabde707bd3373f4dd2ff5d` et à la série de 91 tests réussis (62 + 29), avec analyse Flutter sans erreur.

Le contrôle a relevé des libellés de boutons rendus avec la police de test en blocs, un titre de lecteur blanc sur fond clair, une illustration trop petite dans la bannière de formation web et des titres mobiles inutilement comprimés par l’image. Les corrections conservent explicitement la police du thème et la couleur du titre, utilisent mieux la surface de l’illustration originale sans changer les fichiers d’images, et réservent toute la largeur aux titres longs. L’objectif et la photo sont côte à côte sur grand écran, comme dans la référence ; les paragraphes et leur ordre restent conservés. Le singulier « 1 formation » est corrigé dans les parcours.

Les tests vérifient également la police du bouton et un contraste du titre du lecteur d’au moins 4,5:1, y compris lors du changement local clair/sombre. Les captures du lecteur sont prises à son ouverture, avant le défilement de contrôle, et sans le bandeau de débogage du harnais.

L’analyse Dart des sources Academy et des tests concernés passe pour cette itération visuelle, avec Flutter 3.47.5 et les dépendances verrouillées. La relance des tests Flutter et la vérification des nouvelles captures restent à effectuer sous Windows. Aucun build ni déploiement de cette itération n’est effectué.

Empreinte SHA-256 du lot reçu : `667b38d96a996c32514b42f4fe76590302fc3cbf7002ded250d2464c351b9150`.
