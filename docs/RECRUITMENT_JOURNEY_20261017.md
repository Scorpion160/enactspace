# Parcours de candidature — 17 octobre 2026

## Intention
Présentation inspirée des parcours guidés Typeform et de la sobriété Tally : bandeau chaleureux, progression, cartes de questions, aides avant saisie. Les six étapes, les questions de campagne, leurs obligations et leurs identifiants restent identiques. Aucun service externe, dépendance, photo ou logo supplémentaire.

## Intégration
Les contrôleurs et pièces jointes restent détenus par le même écran. Retour et Modifier conservent les réponses. Les changements d’étape ferment le clavier et remontent en haut. Toute modification depuis le récapitulatif demande à nouveau la confirmation avant envoi. Les zones longues ont trois lignes au repos et peuvent grandir jusqu’à sept ; la limite de 1200 caractères est conservée. Les textes sont multilignes ; les longues valeurs sélectionnées restent défilables manuellement.

## Vérification
Le correctif précédent de lisibilité a été validé sur Windows : analyse propre, 32 tests réussis (journal transmis par le propriétaire). La présente refonte reste à valider via tools/sync_recruitment_journey_windows.ps1. Ce script vérifie les fichiers complets par SHA256, compare la source locale au commit 2693e6109c4b669e5cf0bb583120678c8a723f39 après formatage, sauvegarde les sources, puis lance analyse et tests Flutter. Il conserve les autres modifications locales.

Les tests couvrent le parcours existant (échecs réseau, doublon, CV conservé, envoi simulé), les textes mobile et les nouveaux bandeaux/cartes aux largeurs 320, 390 et 1024, clair/sombre, taille de texte 200 %, six étapes. Un test de récapitulatif vérifie la modification d’une motivation, la conservation des disponibilités et la nouvelle confirmation obligatoire. Les animations de progression respectent la réduction des animations.

## Validation manuelle avant publication
Dans Edge et sur téléphone : navigation au clavier et tactile ; questions longues ; focus/saisie après erreur ; choix département/niveau ; fichier joint puis retour ; modifier depuis le récapitulatif ; vérifier que rien ne part avant confirmation. Exécuter un envoi réel uniquement dans une campagne de test prévue pour cela. La saisie est conservée pendant la navigation dans l’écran, pas après fermeture ou actualisation du navigateur ; aucune promesse de sauvegarde persistante n’est affichée.

## État
Aucun build ni déploiement réalisé par ce changement. Pas de modification du backend ni de la campagne active. L’analyse, les tests et la revue visuelle Windows sont nécessaires avant de déclarer la refonte opérationnelle.
