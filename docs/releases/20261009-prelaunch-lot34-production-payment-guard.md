# Lot 34 — fournisseur simulé interdit en production
Date : 9 octobre 2026.

La validation de Settings autorisait APP_ENV=production avec MOBILE_MONEY_ENABLED=true et MOBILE_MONEY_PROVIDER=mock. Cette combinaison pouvait laisser un fournisseur simulé actif après une erreur de configuration. Elle est désormais refusée au démarrage avec un message explicite. Le fournisseur mock reste utilisable en test ; sa présence désactivée n’empêche pas le démarrage. La déclaration manual_proof reste autorisée.

Quatre tests ciblés ajoutés : refus du mock actif en production, acceptation en test, acceptation du mock désactivé et conservation du fournisseur manuel. Le lot de régression test_security_mobile_foundation, test_prelaunch_mobile_money_boundaries et test_prelaunch_payment_transport passe : 59 tests en 5,185 secondes. SQLite isolé, e-mails/push désactivés, fournisseurs simulés. git diff --check réussi.

Lecture ciblée du validateur de production : paramètres de sessions, Jitsi, push et paiements ; les autres parties de configuration et l’état du VPS ne sont pas certifiés par cette lecture. PayDunya reste reporté à plus tard selon la décision utilisateur ; MOBILE_MONEY_ENABLED=false est attendu pour le lancement actuel.

Le correctif est sauvegardé sur la branche d’audit et n’est pas encore intégré au dépôt Windows ni déployé. Aucun build, paiement réel, message réel ou mutation de production.
