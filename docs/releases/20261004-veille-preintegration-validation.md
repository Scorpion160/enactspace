# Pôle Veille — état de préparation au 4 octobre 2026

La proposition a été approuvée le 4 octobre 2026. Cette implémentation est préparée sur la base du commit `24d87d0`, version publiée `1.0.3+4`. **Elle n’est pas encore transférée au dépôt Windows ni déployée.** La machine DESKTOP-6CS4OQ4 est hors ligne et les commandes distantes ont échoué par expiration du délai.

## Fonctionnement préparé

- Un espace « Pôle Veille » accessible aux membres actifs, avec leur suivi personnel et une vision transversale pour Veille, le Team Leader, l’administration et le secrétariat. Les responsables de pôle ou de projet restent limités à leur périmètre.
- Des engagements précisant le résultat, la disponibilité, l’échéance et les formations utiles. Les actions créées depuis Veille sont les mêmes tâches que dans le centre de tâches, avec un responsable et un justificatif attendu.
- Un livrable peut être repris après retour ou accepté par une autre personne. La remise et la validation restent distinctes. Les membres ne peuvent pas retirer leurs formations assignées ou déplacer l’échéance d’un engagement sans approbation d’un responsable.
- Des blocages avec une aide attendue, une prochaine action et un point de revue. Un seul blocage peut être ouvert par tâche, avec protection en base en cas de concurrence.
- Des indisponibilités examinées par un autre responsable, prises en compte dans les indicateurs et les rappels. Une tâche partagée reste à suivre pour ses autres personnes disponibles.
- Des bilans hebdomadaires, mensuels et de passation conservant leur photographie de la situation et exportables en CSV avec encodage adapté aux accents. Aucun classement global de personnes n’est calculé.
- Des dossiers confidentiels : faits datés, information et réponse du membre, proposition, avis du bureau, décision distincte du Team Leader ou de l’administration, réexamen, acceptation ou expiration du délai, puis clôture.
- Aucune sanction automatique. Une règle disciplinaire doit être renseignée par une autorité habilitée ; elle ne s’applique pas rétroactivement. Aucune règle ni aucun montant disciplinaire n’est inventé ou préchargé.
- Une mesure financière n’est rapprochée avec Finance qu’à la clôture. Une dette déjà associée à une présence ou aux mêmes faits sur une tâche est réutilisée lorsque son montant correspond ; un écart ou une annulation exige un rapprochement.
- Une trace des changements de tâche, des affectations, des échéances et des décisions, avec auteur et dates. Les dates de remise évitent de pénaliser un membre pour un retard de relecture.
- Des rappels J−3, J−1, le jour prévu et après dépassement, avec escalade configurée, heures de tranquillité et registre durable contre les doublons. Les tâches remises, acceptées ou annulées ne sont plus relancées. Le travailleur reprend le dernier bilan dû après une interruption.
- Des boutons de retour, des notifications vers le bon dossier, des échanges autour des tâches, et la possibilité pour une personne assignée de cocher les étapes en cours. Les étapes d’un livrable remis ne peuvent plus être modifiées.

## Vérifications réalisées ici

- 41 tests Python dédiés réussis : parcours HTTP, authentification réelle par jeton, permissions, refus des conflits de rôle, reprise et acceptation, indisponibilités, rappels, décisions et réexamen, rapprochement Finance et migration.
- 49 tests Flutter réussis : 28 tests d’interface Veille, 7 tests du contrat API, 14 tests existants du dashboard et du centre de tâches.
- Analyse Flutter : aucune anomalie.
- Compilation web de contrôle réussie, y compris le contrôle de compatibilité Wasm. Elle utilise un squelette technique et les polices nécessaires aux tests ; ce paquet web ne contient pas les ressources complètes de l’application et ne doit pas être publié. Les builds de livraison restent à produire depuis le dépôt réel.
- Affichage testé à 360 px avec texte agrandi à 160 % et mode sombre, à 768 px en mode clair, à 1 440 px en mode sombre. Captures inspectées après correction des titres et filtres.
- Migration SQLite de toute la chaîne jusqu’à `20261004_0022`, retour à `20261004_0021` puis remontée, réussis. La migration dédiée conserve les tâches et crée une trace initiale sans notification ni règle disciplinaire.

## À terminer sur l’installation réelle

1. Rétablir Desktop Commander et vérifier que le dépôt Windows est toujours sur la base attendue. Transférer uniquement les fichiers modifiés et nouveaux, en préservant les sauvegardes et changements indépendants.
2. Repasser les suites complètes existantes dans l’environnement du dépôt et celui du serveur, puis vérifier la migration et les parcours concurrents sous PostgreSQL.
3. Utiliser les ressources, réglages et fichiers de signature de l’installation réelle pour les builds web et Android. Le contrôle de compilation réalisé ailleurs ne remplace pas ces builds.
4. Sauvegarder et vérifier la base, les sources et le web avant toute migration de production. Conserver l’image précédente pour la reprise.
5. Appliquer `20261004_0022`, déployer le serveur et le travailleur `veille-worker`, puis publier le web et préparer l’APK signé avec le certificat existant.
6. Contrôler la santé des services, les parcours authentifiés avec les rôles réels, les notifications configurées et la conservation des données. Un essai sur téléphone reste nécessaire pour les fonctions natives, dont la biométrie.
7. Enregistrer le compte rendu final et le commit de livraison. Aucun push Git n’a été effectué.

## Paramètres initiaux à ajuster par le Team Leader

Les rappels débutent à l’activation de la migration, sans rattrapage de vieilles échéances. Les plages de tranquillité sont initialement 21 h à 7 h UTC, la réponse à un dossier 7 jours, le réexamen 14 jours, le point hebdomadaire le lundi à 8 h UTC et le bilan mensuel en début de mois. Ces valeurs sont configurables et leurs changements sont tracés. Elles ne constituent pas un règlement disciplinaire.
