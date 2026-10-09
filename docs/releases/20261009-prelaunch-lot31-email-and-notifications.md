# Lot 31 — e-mails et notifications
Date : 9 octobre 2026.

## Vérifications exécutées
62 tests réussis en 6,363 secondes :
- test_prelaunch_email_lifecycle
- test_email_templates
- test_email_delivery
- test_email_preproduction_safety
- test_push_lifecycle

Base SQLite isolée, APP_ENV=test, secret éphémère, envois e-mails/push désactivés globalement. Les tests qui activent un canal utilisent leurs fournisseurs simulés. Aucun message réel envoyé. Les avertissements SQLAlchemy concernent le nettoyage des tables à dépendances croisées attendance_records/fees ; aucune assertion n’échoue.

## Relecture
Lecture complète de email_worker.py, email_delivery_service.py et email_provider.py. Repérage des appels de mise en file dans auth.py, recruitment.py, first_access.py et notification_channels.py ; ce repérage ne constitue pas une lecture complète de ces fichiers ni un inventaire exhaustif de tous les événements métier.

La redirection de test est appliquée à la mise en file et à nouveau immédiatement avant le transport SMTP, y compris pour des messages plus anciens. Une adresse de test invalide bloque le transport. La prise de messages utilise FOR UPDATE SKIP LOCKED sous PostgreSQL, un bail de traitement de cinq minutes et cinq tentatives maximales avec délai croissant pour les erreurs transitoires. Un message lié à une notification annulée ou dont la préférence e-mail a été désactivée n’est pas expédié. Le worker importe les modèles avant de traiter la file.

Le transport vérifie les certificats TLS avec ssl.create_default_context et masque les erreurs sous forme de codes fixes. L’existence de déduplication et d’un Message-ID stable ne garantit pas une livraison exactement une fois, notamment si le transport réussit mais que l’enregistrement du résultat échoue.

## Limites et suite
Les destinataires et paramètres actuels du VPS n’ont pas été lus ou modifiés ; la conservation effective de la redirection en production doit être contrôlée dans la recette opérationnelle. La réception réelle sur la boîte de test et sur Android/web reste à valider. Aucun fournisseur réel contacté par ces tests. Aucune modification applicative, build, déploiement ou bascule des courriels réalisée. La revue des autres services et la matrice complète des événements métier restent ouvertes.
