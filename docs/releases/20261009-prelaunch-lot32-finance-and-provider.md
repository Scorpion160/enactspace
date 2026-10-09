# Lot 32 — finance et transport Mobile Money
Date : 9 octobre 2026.

74 tests réussis en 7,880 secondes, sur SQLite isolé : test_prelaunch_finance_boundaries, test_prelaunch_payment_transport, test_finance_receipts et test_prelaunch_mobile_money_boundaries. Les fournisseurs sont simulés ; aucun transfert financier ou message réel effectué.

Lecture de finance_integrity.py et provider_factory.py ; lecture ciblée du transport PayDunya, du contrôle des URL, des résultats et callbacks, ainsi que can_access_transaction et validate_provider_result dans mobile_money_service.py. La relecture exhaustive de finance.py et mobile_money_service.py reste ouverte.

Constats : les références de déclaration et empreintes des justificatifs disposent de verrous transactionnels PostgreSQL ; ce lot SQLite ne les exerce pas. Le compte financier est créé sous verrou du parent. Les accès aux transactions sont limités au membre concerné ou à la gestion financière. Une confirmation positive exige la cohérence du prestataire, du jeton de facture, du montant et de la devise. Les callbacks PayDunya déclenchent une consultation du fournisseur ; leur statut et montant ne sont pas pris seuls comme autorisation financière. Les réponses réseau ont une limite de taille, les redirections sont refusées et les erreurs exposées restent des codes contrôlés.

Les intégrations directes wave_direct et orange_money_direct sont explicitement réservées à une évolution future ; elles ne doivent pas être présentées comme déjà opérationnelles. Le remboursement automatique PayDunya est également refusé explicitement. Les tests simulés ne valident ni les contrats ni la réception d’un callback réel sandbox.

Aucune modification applicative ajoutée. Restent les tests sandbox avec configuration vérifiée, la recette du partage de reçu depuis le téléphone et les autres contrôles de livraison finale. Aucun build, déploiement ou mutation de production.
