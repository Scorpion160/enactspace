# Préproduction — lot 12 : initiation et confirmations Mobile Money
Date : 7 octobre 2026. Code local non déployé.

## Vérification finale
52 tests SQLite ont réussi en 18.669 secondes et 9 tests PostgreSQL ont réussi en 29.398 secondes, sans test ignoré. Les sept parcours HTTP sont exécutés sur les deux bases. Deux scénarios PostgreSQL supplémentaires testent une initiation concurrente et deux notifications concurrentes. Les comptes des suites se recoupent.

Le premier état du lot, avant la lecture du format formulaire, avait réussi avec 51 tests SQLite et 8 tests PostgreSQL. Les journaux sont distincts. Les appels PayDunya sont remplacés par des réponses synthétiques ; aucun paiement, mail ou push réel n'a été envoyé.

## Corrections
Une notification PayDunya ne suffit plus à déclarer un paiement réussi. Après contrôle du hash et de la présence du token, le serveur consulte l'état de la facture auprès du prestataire. Le statut et le montant contenus dans la notification ne sont pas utilisés pour autoriser la comptabilisation.

La consultation du prestataire exige une réponse technique réussie. Le token est encodé dans le chemin de requête. Le résultat transporte le montant de la facture et sa devise ; le prestataire PayDunya est configuré pour XOF et conserve ce défaut lorsque la réponse ne fournit pas de devise. Les données personnalisées sont limitées à un dictionnaire.

Avant toute confirmation réussie, la notification et l'actualisation partagent le contrôle du prestataire, du token, du montant entier positif exact et de la devise. Une confirmation sans montant, avec un montant différent ou non fini, une devise différente, un token différent ou un autre prestataire est refusée.

L'initiation concurrente acquiert un verrou transactionnel sur la sélection, le membre et le montant avant de chercher une facture active. Deux requêtes identiques retournent la même facture et n'appellent le prestataire qu'une seule fois dans le scénario PostgreSQL testé. Les attentes de verrou dans les routes asynchrones sont exécutées hors de la boucle événementielle.

Les retours simultanés et répétés produisent une seule comptabilisation et une seule entrée de caisse. Un paiement reçu après l'annulation d'un frais reste enregistré comme montant non affecté ; le frais annulé n'est pas réactivé. L'allocation se limite aux dettes encore ouvertes du membre concerné.

## Format officiel des notifications
La documentation officielle indique que les notifications utilisent application/x-www-form-urlencoded, avec les informations sous data. La route accepte maintenant ce format et le JSON utilisé par les tests et intégrations internes. Le corps est limité à 64 Kio, les formulaires à 200 champs et huit niveaux de clés. Les champs dupliqués ou structures incompatibles du formulaire sont refusés avant l'appel du prestataire.

Référence consultée le 7 octobre 2026 : https://developers.paydunya.com/doc/FR/http_json. La documentation confirme aussi l'endpoint de consultation par token et la réponse response_code 00.

## Limites et suite
Les ressources PostgreSQL et réseaux jetables ont été contrôlés absents. La compilation Python et le contrôle d'espacement Git réussissent. Aucun build, déploiement, push Git ou changement des données du club.

Ces tests ne valident pas une transaction dans le sandbox réel du prestataire : les clés requises ne sont pas encore configurées. Le paiement intégré reste désactivé en production. Restent le traitement des erreurs réseau, les limites des réponses et URL distantes, les quotas de notifications, le payload client/canal et le nettoyage des helpers historiques, puis les autres audits et essais Android/web. La relecture complète du dépôt est inachevée.
