# EnactSpace V1.1 - Rapport tests sandbox Mobile Money

## Etat

Implementation backend et Flutter terminee pour la V1.1.

Validations automatiques executees pendant la tranche:

- `flutter analyze --no-pub`: OK.
- `backend\.venv\Scripts\python.exe -m compileall backend\app`: OK.
- `git diff --check`: OK.

## A tester avec cles PayDunya sandbox

- Creation transaction.
- Checkout PayDunya ouvert en HTTPS.
- Paiement reussi.
- Paiement echoue.
- Paiement annule.
- Transaction expiree.
- Callback valide.
- Callback avec mauvais hash.
- Callback duplique.
- Callback montant different.
- Callback devise differente.
- Refresh statut.
- Rapprochement.
- Double clic sur payer.
- Dette deja payee.
- Membre tentant de payer la dette d'un autre.
- Notification.
- Recu.
- Dashboard financier.

## Limite actuelle

Aucun secret PayDunya sandbox n'est present dans Git. Les tests provider reels doivent etre faits sur l'environnement configure.
