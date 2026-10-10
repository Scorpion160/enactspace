# Préproduction — lot 11 : justificatifs et déclarations financières
Date : 7 octobre 2026. Modifications locales non déployées.

## Résultat
La vérification finale compte 61 tests SQLite réussis en 28.521 secondes et 26 tests PostgreSQL réussis en 61.483 secondes, sans test ignoré. Les 21 scénarios Finance portables sont rejoués sur PostgreSQL, avec cinq scénarios de concurrence supplémentaires. Les comptes des suites se recoupent.

Avant l'ajout de la protection contre l'expiration des preuves, la suite groupée avait également réussi : 97 tests SQLite et 24 tests PostgreSQL. Les journaux de cette étape sont conservés séparément ; ils ne constituent pas une vérification supplémentaire de la modification finale.

## Justificatifs
L'accès à une preuve ou à un reçu lié à un paiement est contrôlé avant les droits génériques des fichiers. Le membre concerné et les responsables financiers actifs autorisés peuvent le consulter. Un rôle de Secrétaire Générale seul ne donne pas accès au justificatif financier d'un autre membre. Les Alumni conservent l'accès à leurs propres justificatifs.

La suppression générique d'un justificatif lié est refusée, y compris au déposant et aux responsables. Le lien réel dans le paiement est utilisé pour protéger aussi les anciennes preuves dont les métadonnées ne précisent pas l'entité. Une simple étiquette payment sur un fichier ne donne aucun accès à un paiement. Le téléversement générique refuse de fabriquer ce lien : la déclaration du paiement rattache le fichier.

Lors du rattachement, la preuve devient permanente et ses paramètres temporaires, éphémères et sa date d'expiration sont retirés. Pour les preuves déjà liées, une ancienne date temporaire ne bloque plus la consultation et le nettoyage automatique ignore le fichier. Aucun ancien enregistrement réel n'a été modifié pendant ce lot.

## Déclarations et comptes
Sur PostgreSQL, des verrous limités à la transaction sérialisent les vérifications portant sur une même référence normalisée pour un moyen de paiement ou sur le même checksum de preuve. Les clés sont acquises dans un ordre stable ; la ligne du fichier est ensuite verrouillée et relue avant son rattachement.

Les tests simultanés couvrent deux déclarations avec la même référence pour des membres différents, ainsi que deux fichiers distincts ayant le même checksum. Dans chaque cas, une déclaration réussit et l'autre reçoit un conflit 409 ; un seul paiement est créé. Les déclarations en espèces sans référence ni justificatif ne sont pas dédupliquées par ce mécanisme.

La création du compte financier verrouille d'abord le membre existant. Deux premières consultations simultanées retournent le même compte, sans doublon. Le même helper est utilisé par Finance et par la comptabilisation Mobile Money. Un membre cible inexistant produit une réponse 404 avant création d'un paiement ou d'un compte.

## Exports et montants
Les cellules textuelles des deux exports Finance susceptibles d'être interprétées comme une formule sont préfixées d'une apostrophe. Les valeurs numériques restent numériques. Les tests contrôlent le libellé des frais, la référence et le motif de rejet.

Les formulaires serveur de création de frais, frais groupés, paiements et mouvements de caisse refusent les montants non finis, nuls, négatifs, inférieurs à 0,01, au-delà de la capacité du champ comptable ou ayant plus de deux décimales. Ces limites portent sur les quatre schémas Finance concernés ; les autres modules doivent encore être revus.

## Isolation et limites
Données synthétiques uniquement, PostgreSQL 16 jetable, réseau de test interne et notifications simulées. Aucun mail, push, build, déploiement, push Git ou nettoyage des données du club. Les ressources temporaires nommées des deux essais PostgreSQL ont été contrôlées absentes. Le contrôle d'espacement Git et la compilation Python des fichiers revus réussissent.

Ces résultats ne remplacent pas les essais sur téléphone et navigateur. La revue manuelle complète du dépôt reste inachevée. Restent notamment l'initiation Mobile Money et les échanges avec le prestataire, les autres contrôles d'accès et données financières, le nettoyage ciblé du recrutement de test, puis la documentation et la préparation finales du déploiement.
