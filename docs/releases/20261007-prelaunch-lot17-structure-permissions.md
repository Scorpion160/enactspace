# Préproduction — lot 17 : droits des pôles et projets
Date : 7 octobre 2026. Correctifs dans le dépôt de travail, sans build ni déploiement.

## Résultat
Les actions de gestion exigent un compte opérationnel actif, vérifié et cohérent avec un profil Enacteur ou Enactrice. Un Alumni conservant un ancien rôle d'administration, Team Leader, SG ou une ancienne responsabilité ne peut plus modifier une structure ni ses affectations.

Un responsable local ne peut plus retirer une responsabilité en réaffectant son titulaire comme simple membre. La nomination, le retrait et la modification d'une responsabilité restent réservés à la direction. Un changement effectif d'année d'un projet est également réservé à cette direction ; un formulaire retransmettant la même année reste accepté.

Le remplacement d'un chef libère d'abord son ancienne position avant d'attribuer la nouvelle. Les affectations, retraits et modifications utilisent le verrou de leur structure. La synchronisation des rôles consulte les changements effectivement enregistrés dans la transaction, y compris avec des sessions sans autoflush.

Les identifiants de routes doivent être des UUID. Les noms et types obligatoires vides, trop longs ou explicitement nuls sont refusés avant SQL. Les budgets négatifs, non finis, trop grands ou dépassant deux décimales sont refusés. Une appartenance de projet avec une date de départ n'apparaît plus dans l'équipe actuelle.

## Fonctionnement par personne
| Personne | Consultation | Gestion |
|---|---|---|
| Enacteur ou Enactrice sans responsabilité | Structures et équipes selon l'accès authentifié existant | Aucune modification de structure ou d'affectation. |
| Chef ou adjoint actif d'un pôle/projet | Structures et équipes | Informations et membres ordinaires de son périmètre ; aucune nomination ou rétrogradation de responsable. |
| SG, Team Leader ou administrateur actif et vérifié | Structures et équipes | Création, modification, affectation, remplacement et retrait des responsables selon les droits existants ; changement d'année d'un projet. |
| Financier seul | Consultation existante | Son rôle financier ne donne pas de gestion générale des pôles/projets. |
| Alumni | Consultation existante conservée | Aucun ancien rôle ne suffit à autoriser les actions opérationnelles couvertes ici. |
| Compte inactif, non vérifié ou profil incohérent | Selon les contrôles d'authentification existants | Gestion refusée. |

EnacChef reste le collectif des responsabilités actives ; son appartenance ne donne pas automatiquement le pouvoir de modifier tous les autres pôles et projets.

## Vérification
- SQLite : 55 tests réussis en 18,296 secondes.
- PostgreSQL : 11 tests réussis en 29,530 secondes.
- Dix scénarios HTTP nouveaux, plus une course entre deux remplacements de chefs sur PostgreSQL, exercée pour pôles et projets.
- Tests des anciens rôles Alumni, comptes incohérents, périmètres, rétrogradation détournée, gestion légitime, nomination, année, identifiants, valeurs invalides et départs.
- La course laisse un seul chef actif ; les tests existants des tâches, rôles et règles opérationnelles restent réussis.
- Aucun test ignoré. Les suites se recoupent ; leurs nombres ne constituent pas un total de scénarios indépendants.
- Syntaxe et git diff --check réussis ; conteneurs et réseau propres au lot absents après exécution.
- Données synthétiques, environnements isolés, courriels et push désactivés dans les tests.

## Travaux restant à examiner
Les changements simultanés du cycle de vie de l'acteur et les responsabilités dans plusieurs structures nécessitent encore des scénarios spécifiques. L'existence d'une année fournie et la cohérence des dates restent à approfondir. Ce lot ne clôture pas l'audit des autres modules ni la revue intégrale du dépôt.

La répétition complète des migrations, la recette sur téléphone et web, le nettoyage ciblé des candidatures de test et la documentation finale restent ouverts. Le head source demeure 20261007_0028 et n'a pas été appliqué en production. La redirection des courriels de test est conservée.

Aucun build, déploiement, paiement ou courriel réel, push Git ou changement de production.
