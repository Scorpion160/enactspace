# EnactSpace — convergence des corrections de novembre 2026

**État : candidate d'intégration ; production inchangée.**

## Point de départ

La branche `integration/consolidated-20261113` est créée depuis `fix/chat-scroll-and-payment-hardening-20261111` (PR 30, commit `649a12a`). Cette branche contient elle-même la convergence `integration/recruitment-production-parity-20261110` : recrutement, correctifs de documents Web +34/+35 et générateur de PV, chat avec défilement ancré et suppression des e-mails chat, sécurisation du paiement et interface de suivi Wave/Orange Money.

Le répertoire de reprise historique `recovery/final-20260927` comportait 479 fichiers modifiés/non suivis. Aucun de ces fichiers n'a été écrasé ou inclus en bloc.

## Correctif complémentaire intégré dans cette branche

La page « La campagne en chiffres » présente un tableau de bord détaillé pour les gestionnaires du jury : couverture des évaluations, moyennes et classement des notes, répartition des scores, avis, écarts, statistiques par département/niveau, activité par jour et état administratif. La route conserve `selection_progress` (travaux PR 28/29) et les répartitions anonymisées accessibles aux membres. Le nouvel agrégat `evaluation` n'est fourni qu'aux utilisateurs autorisés à gérer le jury, via `can_manage_jury`. Les données sont recalculées par campagne, avec `screening_min_reviews` propre à la campagne ; aucune identité n'est transmise.

Vérification lecture seule de production : 95 candidatures ; 301 évaluations ; 95 dossiers ayant le minimum de 3 notes ; moyenne 13,02/20 ; 29 dossiers à plus de 5 points d'écart ; union de 31 dossiers sensibles. Quatre tests unitaires du moteur réussis et 20 tests Flutter ciblés réussis. Analyse statique des fichiers statistiques : aucune anomalie.

La mesure d'écart de **5/20** du rapport d'analyse est indépendante de `screening_disagreement_threshold=20` utilisé dans le flux de sélection (échelle différente). Ne pas fusionner ces deux interprétations.

## Correctifs déjà présents en production qui doivent être préservés

- Correction chat e-mail : les deux fichiers `email_delivery_service.py` et `notification_channels.py` ont exactement la même empreinte SHA-256 en fin de ligne LF sur cette branche et sur l'API en service.
- Documents : les fichiers du générateur PV de cette branche diffèrent du VPS uniquement par la gestion d'un objet ORM `User` et la séparation de la section confidentielle (correctifs positifs à valider).
- Schéma de la base : `20261107_0038`, également la dernière migration de la branche candidate.
- Année 2026–2027 : déjà courante, ne pas recréer.
- Web servi : dernière publication documentée `1.0.30+35`. La version candidate porte `1.0.30+37`, mais n'est pas déployée.

## Points externes encore bloquants

1. **PayDunya réel** : production `MOBILE_MONEY_ENABLED=false`, `PAYDUNYA_MODE=test`, clés manquantes et rapprochement désactivé. L'API candidate impose des garde-fous de non-crédit en mode test. Aucune transaction réelle n'a été lancée.
2. **Finances** : six pénalités sans saison en production ; ne pas déplacer les écritures sans audit et réconciliation avec sauvegarde.
3. **EnactMeet** : recette multiutilisateur réelle, coupures réseau, expulsion et réadmission, relay TURN et renouvellement JWT non réalisée dans cette convergence.
4. **Expérience utilisateur** : tests Flutter automatiques ne remplacent pas les parcours authentifiés mobile et Web ni la validation des parcours hors ligne / fichiers.
5. **Backend** : démarrage isolé de l'API candidate et tests PostgreSQL doivent être validés avant une bascule de conteneur.
6. **Intégrité** : toute publication doit conserver le hotfix e-mail, les métadonnées des documents, les uploads, les modèles PV et les données de candidature.

## Contrôles de publication

Un seul lot coordonné Web/API/workers est recherché, avec staging séparé, sauvegarde PostgreSQL, vérification du rollback et empreintes du Web actuel. Aucune activation de paiement réel, message candidat, publication de classement ou changement de statut de recrutement n'est compris dans cette livraison. Toute opération financière réelle ou modification de données doit être distinctement validée.

Le CI et l'audit de sécurité sont activés à la publication de la branche d'intégration, sans déploiement automatique.

## Contrôle élargi du frontend — première campagne de tests

Une exécution intégrale de `flutter test --no-pub` a terminé avec **1171 tests réussis et quatre erreurs de configuration/ressources** :
- `backend/app/services/recruitment_rubric.json` absent de la branche de développement ;
- `backend/app/services/project_presentations.json` absent de la branche de développement ;
- deux tests de revue visuelle utilisaient uniquement `/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf` (chemin Linux, non disponible sous Windows).

Les deux fichiers JSON ont été restaurés localement depuis le conteneur de production, puis validés. Ils sont exclus du dépôt public ; la CI génère ses ressources fictives sous APP_ENV=test. La livraison devra fournir les vraies ressources depuis une copie vérifiée, hors dépôt. Les tests visuels acceptent maintenant la variable `ENACTSPACE_QA_TEXT_FONT` sans modifier le chemin Linux par défaut de GitHub Actions. Les 4 groupes précédemment échoués ont ensuite réussi ensemble (**36 tests**).

L'analyse statique de la page statistique a été validée. La comparaison du chat a confirmé les SHA identiques (après normalisation des fins de ligne) entre la branche candidate et les fichiers du hotfix SMTP de production.

**Aucune bascule en production n'a été effectuée.** La validation de démarrage backend/PostgreSQL et du Web compilé sur GitHub reste un contrôle distinct.
