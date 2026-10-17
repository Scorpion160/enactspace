# Validation sur téléphone — 5 octobre 2026

Version visée : EnactSpace 1.0.7+8. Appareil : Samsung SM-A065F, Android API 36, écran 720 × 1600, densité 300 et taille de texte système 1,0. Les essais utilisent l’APK de production signé et les services de production.

## Défauts trouvés et corrigés

- Sur la largeur réelle du Samsung, « Recrutement » revenait à la ligne au milieu du mot dans la navigation inférieure. Les libellés restent désormais sur une seule ligne, avec une ellipse lorsque nécessaire et leur texte complet conservé pour l’accessibilité.
- Le bouton accessible de la photo fusionnait avec le contenu du profil. Sa zone englobait donc des informations qui ne déclenchaient pas l’aperçu lorsqu’on les touchait. Une frontière sémantique limite désormais le bouton à l’avatar.

## Essais physiques sur la version 1.0.6+7

L’installation a conservé la session et les données locales. Les manipulations ont utilisé les contrôles accessibles de l’interface avec UI Automator ; aucun effacement des données de l’application n’a été effectué.

| Parcours | Résultat constaté |
| --- | --- |
| Démarrage et menu | Application ouverte, session conservée, navigation disponible. |
| Recrutement | Liste chargée ; statuts « Reçue » et « En cours d’étude » lisibles en mode sombre. |
| Fiche de candidature | Ouverture, défilement jusqu’à l’historique daté et fermeture vers la liste. |
| Historique | Événement de réception affiché ; aucun message technique concernant le backend. |
| Academy — Continuer | Ouverture de « Cinq modes, des allers-retours », dans la formation Design thinking. |
| Academy — lecture | Illustration chargée, contenu parcouru jusqu’au bouton de fin de leçon, fermeture vers la formation. |
| Academy — quiz rapides | Cartes lisibles ; accès désactivé pour les leçons ou formations prérequises non terminées. |
| Veille | Écran de suivi et filtres chargés et lisibles. |
| Tâches | Centre et détail chargés ; formulaire de statut ouvert puis annulé. |
| Preuve de tâche | Sélecteur de fichiers Android réellement ouvert ; annulation et retour à la tâche. |
| Pôles et Projets | Portefeuilles, détails et boutons de retour opérationnels. |
| Archives et Impact | Pages ouvertes, contenu et actions visibles. |
| Profil | Photo existante chargée ; défaut de zone accessible reproduit avant correction. |
| Apparence | Passage au thème clair, contrôle du recrutement puis restauration du thème sombre initial. |
| Orientation | Recrutement contrôlé en paysage, puis retour au portrait. |

Aucune candidature n’a été évaluée, acceptée, rejetée ou convertie pendant les essais. Aucun statut de tâche n’a été enregistré et aucun justificatif n’a été envoyé. Aucune leçon n’a été marquée comme terminée et aucun quiz n’a été soumis sur le compte réel.

## Vérification du code final

- Suite Flutter : **796 tests réussis**.
- Contrôle ciblé de l’aperçu et des retours : **6 tests réussis**, y compris l’activation par une action d’accessibilité.
- Navigation : **16 cas** couvrant deux routes, les largeurs 360 et 384, les tailles de texte 1 et 2, ainsi que les thèmes clair et sombre.
- Analyse Flutter : **aucun problème signalé**.
- Les contrôles historiques de navigation ont été adaptés pour rechercher la destination rendue, sans dépendre du type de son widget parent.

Le compte réel possède des leçons encore incomplètes : les essais physiques des quiz portent donc sur leur présentation et leur verrouillage. L’ouverture du dialogue, les réponses, les résultats et la synchronisation sont couverts par les tests automatisés existants.

Au redémarrage, l’écran système de biométrie affiche « Déverrouiller votre session EnactSpace ». La demande est également visible dans le journal biométrique du système, puis l’accueil et la session sont accessibles. Le test constate ce parcours réel sans simuler ou contourner l’authentification ; il ne distingue pas l’empreinte de la reconnaissance du visage.

## Installation finale et publication

- APK signé et installé avec succès : **1.0.7, code Android 8**, package `sn.enactusesp.enactspace`.
- Même certificat de signature que la version précédente ; session conservée après la mise à jour.
- Neuf contrôles réussis sur cet APK : aperçu et fermeture de la photo, recrutement, ouverture de fiche, historique, retour à la liste, Academy, Continuer, lecture et fermeture de leçon, retour à l’accueil.
- Inspection visuelle de l’aperçu en plein écran et du libellé de recrutement sur une seule ligne.
- Web et API publiés en **1.0.7**, version web de build **8** ; sept routes web répondent en HTTP 200.
- Contrôles privés de lecture du profil d’administration présent en production, du recrutement et de la protection des routes sans authentification.
- Base sauvegardée ; comparaison de l’intégralité des **111 tables** avant/après l’installation des exécutables : données identiques. Révision de schéma `20261004_0022`, sans nouvelle migration.
- Services email, push et Veille redémarrés ; aucune nouvelle identité de test créée en production.

APK conservé dans `C:\Users\DIOP\Downloads\EnactSpace-1.0.7-release-20261005-recrutement.apk`.

Empreintes SHA-256 :
- APK : `2f889f2b6c07d4a6589788c859813ab3db6082d416e1461eb76961a867caf999`
- Certificat : `38e8274a7b63174cbf06f5d5b15e68b623fdb9fae92538ad9b7f470611e484d5`
- JavaScript servi publiquement : `473b45f5698e54d9b2577e4d980d1ec7e837beb177c367a7f529f1bf5cec7b18`

Les captures contenant des coordonnées privées et la photo du profil restent hors du dépôt.
