# Academy — validation du rendu du 30 octobre 2026

Code vérifié : `1c504874dec6f6a906f7196ae77c1c08cff97d7a`.

## Résultat

Le contrôle des 24 nouvelles captures ne relève plus d’anomalie visuelle bloquante dans les vues examinées. Les corrections de typographie, de contraste et de composition sont visibles. La refonte est prête pour la préparation du build ; aucun build ni déploiement n’a été effectué dans cette validation.

## Vérifications automatisées sous Windows

Le journal transmis confirme :

- analyse Flutter sans erreur ;
- 62 tests Academy, parcours pédagogique, Alumni, gamification et Impact réussis ;
- 29 tests de la démo native réussis ;
- génération des 24 captures et de leur archive après les tests.

Ces 91 tests couvrent notamment la navigation vers les pages réelles, la progression explicite des leçons, les prérequis de quiz, la conservation de la lecture après un échec de validation, les petits écrans et le texte agrandi à 200 %. Les assertions ajoutées contrôlent aussi la police des boutons et le contraste du titre lors du changement clair/sombre.

## Contrôle visuel

| Vues | Largeurs examinées | Apparences |
| --- | --- | --- |
| Accueil | 390, 1440 px | Clair et sombre |
| Formation | 320, 390, 1024, 1440 px | Clair et sombre |
| Lecture | 320, 390, 1024, 1440 px | Clair et sombre |
| Parcours | 390, 1440 px | Clair et sombre |

Les images montrent la zone visible des écrans avec des données de test. Le contrôle a porté sur les points suivants :

- libellés des boutons lisibles, sans les blocs de police de test du premier lot ;
- titre du lecteur lisible sur fond clair et sombre ;
- illustrations locales présentes et bannière de formation mieux proportionnée sur ordinateur ;
- titres longs complets, avec retour à la ligne sur les petits écrans ;
- objectif et photo disposés côte à côte sur grand écran et empilés sur téléphone ;
- photo originale et crédit conservés ;
- actions du lecteur visibles dans la barre basse ;
- cohérence des cartes, couleurs et états désactivés entre les thèmes ;
- libellé « 1 formation » corrigé dans l’accueil et le parcours.

Aucun changement supplémentaire de code n’est demandé à l’issue de ce lot. La publication reste une étape distincte du présent contrôle.

## Traçabilité

- Archive examinée : `academy-captures(1).zip`, 24 fichiers PNG.
- SHA-256 de l’archive : `90d9a45b6fb48cbf7dcef4052f17c52ae42f59e7870486a2b18fac8eae50fa92`.
- Journal des tests : `Texte collé(20261030-171216).txt`.
- SHA-256 du journal : `b706ba9eb89fb36c90749192dea5b6e33c77a56361d082b630613d98824a93d0`.
