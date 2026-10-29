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
