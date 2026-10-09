# Préproduction — lot 20 : gestion des comptes et cycle de vie

Date : 7 octobre 2026. Correctifs dans le dépôt de travail, sans build ni déploiement.

## Résultat

La création administrative d'un compte, sa modification administrative, l'approbation, le rejet, la suspension, la réactivation et le passage en Alumni relisent désormais le compte de l'auteur sous verrou puis recalculent ses droits. La prévisualisation du passage en Alumni suit le même contrôle. Les comptes concernés et les titulaires des responsabilités exclusives sont verrouillés dans l'ordre de leurs UUID.

Un compte Alumni conservant un ancien rôle de direction, un compte suspendu, non vérifié ou présentant un profil incohérent ne peut pas exécuter ces actions. Un membre ordinaire ne les obtient pas non plus. Une responsabilité retirée pendant qu'une action attend ses verrous ne suffit plus à l'autoriser.

La modification administrative ne peut plus retirer la vérification du courriel du dernier administrateur utilisable. Le décompte des administrateurs utilisables exige un statut actif, un compte actif, un courriel vérifié et un profil Enacteur ou Enactrice. Un profil incohérent conservant un rôle administrateur ne compte pas comme relais disponible.

L'autorisation de validation des demandes d'adhésion reconnaît le véritable Pôle Veille à travers ses désignations canoniques. La présence du mot « veille » dans le nom d'un autre pôle, par exemple « Veille commerciale », ne donne plus ce pouvoir. Le chef et l'adjoint actifs et vérifiés du Pôle Veille conservent leurs droits.

## Fonctionnement par personne

| Personne | Actions couvertes |
|---|---|
| Administrateur ou Team Leader opérationnel | Création et modification administrative, approbation ou rejet, suspension, réactivation, prévisualisation et passage en Alumni, avec les protections existantes sur les comptes administrateurs et les actions sur soi-même. |
| SG opérationnel | Création, modification administrative, approbation et rejet ; aucune suspension, réactivation ou conversion Alumni par le seul rôle SG. |
| Chef ou adjoint opérationnel du véritable Pôle Veille | Consultation des demandes en attente, approbation et rejet ; aucune gestion administrative générale. |
| Membre ordinaire ou responsable d'un autre pôle | Aucun accès à ces actions par sa seule appartenance. |
| Alumni ou compte non opérationnel conservant un ancien rôle | Actions de gestion couvertes refusées. Les droits de consultation d'autres modules ne sont pas redéfinis par ce lot. |

Une suspension ferme les appartenances actives et retire les responsabilités. La réactivation ne rétablit pas automatiquement les anciennes affectations. Un Alumni suspendu retrouve son identité Alumni après réactivation. Les tâches ouvertes, leurs états et l'historique restent conservés ; aucun doublon de profil Alumni n'est créé.

## Vérification finale

- SQLite : **68 tests réussis en 29.177 secondes**.
- PostgreSQL : **39 tests réussis en 108.73 secondes**.
- Neuf scénarios portables ajoutés et quatre scénarios de concurrence PostgreSQL ajoutés.
- Concurrences nouvelles : deux administrateurs tentant de se suspendre mutuellement ; deux retraits de vérification de courriel ; perte de rôle pendant une suspension en attente ; passage de l'auteur en Alumni pendant une suspension en attente.
- Les courses de suspension et de retrait de vérification conservent un administrateur utilisable. La perte d'autorité fait refuser l'action en attente.
- Tests des droits du chef et de l'adjoint Veille, d'un nom de pôle sans légitimité Veille, des anciens rôles Alumni, des profils incohérents, de la création et de l'approbation SG, du parcours Alumni et de la conservation des tâches.
- Suites existantes des rôles, règles opérationnelles, années et catalogues également exécutées. Les suites se recoupent et leurs nombres ne sont pas cumulables comme scénarios indépendants. Aucun test ignoré.
- Le premier passage a signalé un ancien test direct dont le compte nommé administrateur ne possédait aucun rôle administratif. Ce test prépare maintenant un administrateur autorisé avant de vérifier le refus du changement de statut par le formulaire générique. Un cas distinct vérifie le refus du membre sans autorisation.
- Syntaxe et git diff --check réussis ; conteneurs et réseaux des premiers essais et des essais finaux absents après exécution.
- Données synthétiques et environnements isolés, courriels et push désactivés. Aucun courriel ou paiement réel.

## Limites et suite

Ce lot couvre les actions citées des routes utilisateurs et l'habilitation aux demandes d'adhésion. Il ne clôture pas l'audit des autres routes privilégiées ni de toutes les interactions concurrentes entre modules. La revue manuelle intégrale du dépôt reste inachevée. Le grand fichier de tests opérationnels n'a reçu ici qu'une revue ciblée de la préparation corrigée.

La répétition complète des migrations depuis 20261006_0025 vers le head source 20261007_0028 reste à effectuer. La recette sur téléphone et web, le nettoyage ciblé des candidatures de test et la documentation finale restent ouverts.

Aucune nouvelle migration, aucun build, déploiement, changement de production ou push Git. La redirection des courriels de test reste conservée.
