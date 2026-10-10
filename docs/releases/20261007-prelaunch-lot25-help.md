# Préproduction — lot 25 : accueil, guide et centre d’aide

Date : 7 octobre 2026. Source du dépôt Windows de référence, sans build, déploiement ni push.

## Résultat

Le guide et les quinze réponses de FAQ sont accessibles avant connexion, en dehors de la barrière de maintenance des activités. L’accueil obligatoire propose aussi une demande d’aide après connexion, sans contourner les droits des autres modules.

Le membre retrouve ses demandes, leur conversation et ses avis. Les avis disposent d’un état lisible et d’une réponse publique. Administration, Team Leader et SG actifs et habilités ont un écran de traitement : recherche, filtres, prise en charge personnelle, priorité, réponse, suivi, et notes internes pour les avis. Un ancien rôle de responsable chez un Alumni ne donne pas cet accès.

Les formulaires gardent le texte après un échec et restent ouverts jusqu’à confirmation. Les envois sont protégés pendant l’attente ; les nouvelles tentatives du même contenu disposent d’une clé conservée. Les informations techniques facultatives ne bloquent pas l’avis et restent stables lors des tentatives du même formulaire.

Les contrôles serveur vérifient l’auteur, les droits actualisés, l’état du compte, les transitions, les plafonds d’envoi et les versions de fiche. Les notes internes des avis sont exclues des réponses personnelles et de l’export des données de l’auteur. Modifier uniquement la note interne n’envoie pas une notification au membre. Les liens d’aide ne sont plus confondus avec Finance par le traitement des notifications.

## Validation

| Vérification | Résultat |
|---|---|
| Backend SQLite | **88 tests réussis**, 62.718 secondes |
| Backend PostgreSQL | **32 tests réussis**, 96.837 secondes |
| Flutter : accueil, aide, réglages, routes, notifications et régressions | **101 tests réussis** |
| Flutter : contrat HTTP du centre d’aide | **4 tests réussis** |
| Analyse Flutter ciblée et formatage | Réussis, aucune anomalie |
| Migration 0025 → 0031 | Réussie : schéma isolé, installation neuve, aller-retour et reprise |
| Conservation du schéma de référence | **110 tables initiales**, données synthétiques conservées |
| Clés d’envoi et réponses publiques | Trois contraintes d’unicité vérifiées ; conservation après retour arrière et reprise |

Les suites backend se recoupent : ces nombres ne représentent pas une somme de scénarios indépendants.

Les cinq courses PostgreSQL couvrent un double envoi, un retrait de rôle pendant l’attente, une suspension concurrente, une clôture pendant une réponse et deux modifications de la même version. Les essais vérifient effectivement une attente sur verrou pour les scénarios de retrait, suspension et clôture.

Les tests Flutter vérifient la recherche avec accents, la consultation sans requête privée, les droits de gestion, la nouvelle tentative après échec, le blocage du double clic, les informations de version facultatives, les réponses publiques, la séparation des notes internes, les conflits de fiche et les erreurs indépendantes des listes. Le guide et le dialogue de traitement d’un avis sont testés à 320 pixels, en sombre et à 200 % de texte. Les tests de l’accueil incluent aussi les largeurs 320 et 1024 pixels. Ces essais automatisés ne remplacent pas la recette sur les appareils finaux.

SMTP et push sont désactivés dans les essais. Aucun email, push ni paiement réel. La redirection de test reste conservée. Les conteneurs et réseaux de test nommés du lot sont supprimés ; les volumes non attribués ne sont pas touchés.

La revue manuelle couvre les nouveaux modules d’aide et les portions modifiées de leurs intégrations. Le manifeste conserve la portée, les empreintes et l’historique. **La relecture manuelle intégrale du dépôt reste inachevée.**

## Livraison et suite

Head source **20261007_0031** ; production **20261006_0025**, vérifiée et inchangée. La migration conserve les échanges et les clés d’envoi lors d’un retour de code ; garder la maintenance tant que les contrôles d’une ancienne version ne sont pas revérifiés.

Documentation : [centre d’aide et traitement](../HELP_SUPPORT_OPERATIONS.md), [premières connexions](../FIRST_ACCESS_ONBOARDING.md).

Restent avant ouverture : les autres audits et la relecture complète, la restauration d’une sauvegarde complète, la recette finale Android/web, la réception des emails et push en conditions de test, la validation Mobile Money, le nettoyage des données de recrutement identifiées comme tests, la confirmation individuelle des contacts, puis la bascule approuvée des courriels et le déploiement cohérent. Ce lot ne déclare pas toute l’application prête à ouvrir.
