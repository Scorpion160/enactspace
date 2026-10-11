# EnactSpace 1.0.4+5 — Pôle Veille

Livraison du 4 octobre 2026, approuvée dans la conversation après le cadrage du Pôle Veille. Version précédente : `1.0.3+4`, commit `24d87d0`.

## Fonctionnement livré

Un espace Veille réunit les engagements, les tâches, les livrables, les blocages, les indisponibilités et les bilans. Chaque membre actif retrouve son suivi ; les responsables de pôle et de projet restent dans leur périmètre. Veille, la direction et le secrétariat disposent du suivi transversal selon leurs attributions.

Les engagements précisent le résultat attendu, la disponibilité, l’échéance et les formations utiles. Les actions sont de véritables tâches, accessibles aussi dans le centre de tâches. La remise d’un travail et son acceptation restent distinctes : une personne ne peut pas accepter son propre livrable. Les retours, les étapes, les justificatifs, les échanges et les modifications d’échéance sont utilisables depuis les fiches.

Un blocage précise l’aide attendue, la prochaine action et la date du point de suivi. Les indisponibilités sont examinées par une autre personne habilitée. Elles interviennent dans les indicateurs et les rappels, sans masquer le travail des autres personnes disponibles sur une tâche partagée.

Les bilans hebdomadaires, mensuels et de passation conservent leur photographie des résultats et sont exportables en CSV. Les indicateurs distinguent les échéances, les remises, les acceptations, la qualité renseignée et la présence. Aucun classement global de membres n’est produit.

Les dossiers confidentiels suivent les faits datés, l’information et la réponse du membre, la proposition, l’avis du bureau, une décision distincte de la direction, le réexamen et la clôture. Une mesure financière est rapprochée avec Finance seulement à la clôture, sans créer une seconde dette pour les mêmes faits. Aucune sanction n’est automatique. Aucune règle disciplinaire ni aucun montant n’est préchargé ; les règles adoptées ont une date d’effet et ne s’appliquent pas rétroactivement.

Les rappels J−3, J−1, le jour de l’échéance et après dépassement disposent d’un registre durable contre les doublons, d’heures de tranquillité et d’une escalade configurable. Le travailleur prépare également les bilans périodiques et reprend le dernier bilan dû après une interruption.

Le rôle « Pôle Veille » peut être attribué et retiré par le Team Leader ou l’administration depuis la gestion des membres. L’appartenance active au pôle nommé « Veille », « Pôle Veille » ou « Pôle de Veille » est également reconnue. Un responsable limité à son pôle ne peut pas obtenir cet accès transversal en changeant le nom du pôle ; un nom évoquant une veille commerciale ne donne pas cet accès.

## Vérifications

- Flutter : 741 tests réussis, suite complète ; analyse sans anomalie après les derniers changements.
- Backend, suite complète SQLite : 357 tests recensés, 304 réussis et 53 ignorés. Parmi ces derniers, les 45 scénarios Veille PostgreSQL sont exécutés séparément et réussissent.
- PostgreSQL Veille : tous les parcours HTTP du module, attribution et retrait réels du rôle, permissions, relecture, Finance, réponse, réexamen, rappels et indisponibilités. Les écritures simultanées n’acceptent qu’une relecture, un blocage ou une version de réglages ; le verrou transactionnel empêche deux travailleurs de produire le même cycle.
- Vérification PostgreSQL complémentaire des modules existants : résultat consigné après son exécution.
- Affichage Veille vérifié à 360, 768 et 1 440 px, avec mode sombre et caractères agrandis ; formulaires, erreurs conservant la saisie, liens, retour, discussions et notifications couverts.
- Migration SQLite complète ; PostgreSQL neuf jusqu’à `20261004_0022`, retour à `20261004_0021` puis remontée réussis.
- Migration sur une copie isolée de la base réelle : empreintes des données des 100 tables existantes identiques avant et après. Le cycle initial du travailleur ne produit aucun rappel ni bilan pendant la plage de tranquillité.
- Migration réelle contrôlée de la même manière, sans compte de test ajouté ni règle ou sanction préchargée. Une trace initiale est conservée pour la tâche existante.
- Compilations web et Android release réussies. Le build final est produit avec les ressources et paramètres réels du dépôt. Le contrôle Wasm du premier build réussissait ; la livraison web utilise JavaScript.
- Lectures authentifiées de l’API vérifiées avec le compte décisionnaire disponible : contexte, bilan, dossiers et tâches visibles. Les autres profils sont couverts dans la base isolée PostgreSQL.
- Web et API : HTTP 200 attendu ; API Veille sans authentification : HTTP 401. Version web, empreinte du JavaScript, routes SPA, police Poppins et photo embarquée vérifiées depuis les URL publiques. Le JavaScript est servi sans cache.
- Backend, web et PostgreSQL en bonne santé ; travailleurs email, push et Veille en service, sans redémarrage observé. Le cycle Veille respecte la plage de tranquillité.

## Livraison

- Web : https://enactspace.kerunjombor.net/
- API : https://api-enactspace.kerunjombor.net/
- Version application et API : `1.0.4`, build Android/web `5`.
- Migration : `20261004_0022`.
- Image : `enactspace-backend:veille-20261004`, également marquée `enactspace-backend:local`.
- Image SHA-256 : `4735bf346603f422aefdd512beb9903dc56ed3f61fdbc99eb3ac502570033b90`.
- JavaScript public SHA-256 : `ea51893ad5e802c53262e7f1409fdd06640cfa29f68ed5cdb5000a736378fbbf`.
- Archive du web final SHA-256 : `9556db867775813c58324b901f96ab4158616a014dc9dc07876be68d3bdf1e21`.
- APK : `C:\Users\DIOP\Downloads\EnactSpace-1.0.4-release-20261004-veille.apk`.
- APK SHA-256 : `5b4e8ae28109a92444f244cd7e58d2eb141c2ccffefc11ff553ec16e2a4b3882`.
- APK : `sn.enactusesp.enactspace`, versionName `1.0.4`, versionCode `5`, architectures `arm64-v8a`, `armeabi-v7a`, `x86_64` ; taille 240 504 322 octets.
- Signature vérifiée ; certificat SHA-256 identique à la livraison précédente : `38e8274a7b63174cbf06f5d5b15e68b623fdb9fae92538ad9b7f470611e484d5`.

## Sauvegardes et reprise

La sauvegarde avant passage de `0021` à `0022` est conservée dans `/opt/enactspace/backups/veille-20261004`. La sauvegarde avant la publication finale est conservée séparément dans `/opt/enactspace/backups/veille-20261004-final`. Les répertoires sont privés. Les archives PostgreSQL possèdent l’en-tête PGDMP et ont été contrôlées avec `pg_restore --list` ; la copie de préproduction a été restaurée dans un PostgreSQL isolé.

Avant migration :

- Base : `4a8d14440bbce6b0110c20e4abb896f243d741c35186ba9086ce9849b8ebf267`.
- Sources : `260e92a520d897f6cfdaa1c8f077f4befc17c67da8960fbbdb950b6868475017`.
- Ancien web : `d6e5eb6900f50a1885b02b78a88e19f2d50612656d56e1a4bf976bcf1e699215`.

Avant publication finale :

- Base : `1e33b7eca5fe08cd63341ca31669ea65568141361ce6f8c3dfc3c477182a195c`.
- Sources : `b6d4eb5c000bcfbfe73b30fe7d6f5d838021f7476402674eb59fcb82cee31206`.
- Ancien web : `d6e5eb6900f50a1885b02b78a88e19f2d50612656d56e1a4bf976bcf1e699215`.

L’image précédente `enactspace-backend:progression-impact-20261004` est conservée. Pour revenir aux anciens exécutables, arrêter Veille, rétablir cette image et l’ancien web, en conservant les tables et colonnes additives. Un downgrade supprime les données Veille : il exige une sauvegarde et une maintenance adaptées. Ne pas restaurer une base complète sans examiner les nouvelles données produites depuis la sauvegarde.

Les tentatives interrompues ont rétabli les anciens exécutables. Le chargement de configuration utilise désormais Compose, comme le service réel. Le contrôle web public utilise curl ; le refus reçu par le client Python n’a pas été assimilé à un succès. La publication finale et ses empreintes ont été vérifiées après ces corrections.

## Mise en service et limites

Les réglages initiaux sont modifiables par le Team Leader ou l’administration : tranquillité de 21 h à 7 h UTC, escalade après deux jours, réponse en sept jours, réexamen en quatorze jours, point hebdomadaire le lundi à 8 h UTC et bilan mensuel en début de mois. Ces changements sont tracés. Les rappels prennent effet à l’activation, sans relancer rétroactivement les anciennes échéances.

Aucun appareil Android physique n’était connecté à ADB. L’installation sur téléphone et la biométrie physique ne sont pas vérifiées par les compilations ni les tests d’interface. Les contrôles authentifiés de production restent des lectures ; les parcours d’écriture et de décision sont exercés dans les bases isolées. Aucun push Git n’est effectué. La sauvegarde préexistante `email_worker.py.before-model-registration-fix` est conservée hors du commit.
