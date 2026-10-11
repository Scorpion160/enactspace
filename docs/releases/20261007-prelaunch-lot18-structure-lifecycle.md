# Préproduction — lot 18 : affectations, cycle de vie et années

Date : 7 octobre 2026. Correctifs dans le dépôt de travail ; aucun build ni déploiement.

## Résultat

Les créations, modifications, affectations et retraits dans les pôles et projets relisent et verrouillent le compte de la personne qui agit. Les affectations et retraits verrouillent également le membre concerné et les responsables actuels avant la structure et ses appartenances. Les utilisateurs sont verrouillés dans l'ordre de leurs UUID.

Cette organisation fait respecter les transitions de cycle de vie pendant les écritures : une suspension engagée avant la modification fait refuser celle-ci ; un passage en Alumni engagé avant une affectation empêche la réactivation de l'appartenance. Les autorisations sont recalculées après la relecture du compte.

Si une responsabilité a changé pendant la préparation des verrous et qu'un nouveau responsable n'est pas dans l'ensemble verrouillé, l'opération est refusée avec une invitation à actualiser et réessayer. Les tests de remplacements simultanés acceptent ce conflit contrôlé ; ils vérifient qu'un seul chef actuel demeure.

La conservation du rôle de chef est vérifiée lorsque la personne dirige deux structures : retirer la première responsabilité conserve son rôle ; retirer la dernière le supprime. Les noms de rôles techniques existants sont inchangés.

Une année fournie à la création d'un pôle ou projet, ou à la modification d'un projet, doit exister. Une date de fin de projet antérieure à sa date de début est refusée. Les modifications partielles sont contrôlées avec les dates déjà présentes ; les dates facultatives peuvent être effacées. Le contrôle de dates intervient lorsque celles-ci sont fournies, sans bloquer une modification sans rapport sur une ancienne fiche incohérente.

## Vérification

- SQLite : **59 tests réussis en 20,303 secondes**, incluant les règles opérationnelles, tâches et rôles.
- PostgreSQL : **17 tests réussis en 43,495 secondes**.
- Quatre scénarios portables ajoutés : année absente, année valide et dates partielles, dates inversées à la création, responsabilités dans plusieurs structures.
- Deux scénarios PostgreSQL ajoutés : suspension de l'acteur pendant une modification et transition Alumni du membre pendant une affectation, exercés pour pôles et projets.
- Le test des remplacements simultanés est conservé et tient compte du refus explicite lorsque les responsabilités viennent de changer.
- Aucun test ignoré. Les suites se recoupent ; ces nombres ne représentent pas des scénarios indépendants cumulables.
- Syntaxe et contrôle Git des espaces vérifiés ; absence des conteneurs et du réseau propres au lot vérifiée après les tests.
- Données synthétiques et environnements isolés ; courriels et push désactivés pendant les tests.

## Limites et suite

Ces contrôles couvrent les écritures des routes pôles et projets. Ils ne concluent pas l'audit de toutes les routes ni la revue manuelle intégrale du dépôt. La concurrence lors de la création initiale d'un rôle absent, les mutations de rôles provenant d'autres modules et des croisements supplémentaires de transactions restent à examiner.

La modification d'année d'un pôle n'est pas exposée par son schéma actuel. Ce lot ne vérifie pas encore le parcours complet de bascule d'année ni son interface. La répétition complète des migrations, la recette Android et web, le nettoyage ciblé des données de recrutement de test et la documentation finale restent ouverts.

Le head source reste **20261007_0028**, sans nouvelle migration dans ce lot. La production n'a pas reçu les correctifs des lots de préproduction. La redirection des courriels de test reste en place. Aucun build, déploiement, paiement réel, envoi réel de courriel ou push Git.
