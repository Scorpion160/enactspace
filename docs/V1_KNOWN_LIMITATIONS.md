# EnactSpace V1 - Limites connues

> **HISTORIQUE / NON AUTORITATIF.** Cette liste décrit l'état du 2026-07-03. QR, NFC, paiements, push, paramètres et tests ont évolué depuis; vérifier le code et le [Test matrix](TEST_MATRIX.md). Les gates externes qui restent ouvertes sont dans [Mobile release and push](MOBILE_RELEASE_AND_PUSH.md) et la [Release checklist](RELEASE_CHECKLIST.md).

Date: 2026-07-03

## Hors scope à cette date historique

- QR code presence.
- NFC.
- Mobile Money reel.
- Push natif FCM en production.
- Messagerie externe.
- Deploiement production complet.

## Limites techniques observées à cette date

- WebSocket interne avec fallback polling; pas encore de push natif mobile.
- Certains exports sont prets cote backend mais le telechargement natif Flutter peut etre affine selon web/mobile.
- Le montage `/uploads` reste present pour compatibilite; privilegier `/api/files`.
- Les perimetres fins chefs de pole/projet peuvent encore etre renforces sur certaines vues globales.

## Limites fonctionnelles observées à cette date

- Routes dediees profil et parametres a ajouter en V1.1.
- UI admin complete pour Archives/Academy encore perfectible.
- Tests automatises multi-role a ajouter.
- Certains contenus historiques restent a enrichir avec preuves et medias reels.
