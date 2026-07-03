# EnactSpace V1 - Limites connues

Date: 2026-07-03

## Hors scope V1

- QR code presence.
- NFC.
- Mobile Money reel.
- Push natif FCM en production.
- Messagerie externe.
- Deploiement production complet.

## Limites techniques

- WebSocket interne avec fallback polling; pas encore de push natif mobile.
- Certains exports sont prets cote backend mais le telechargement natif Flutter peut etre affine selon web/mobile.
- Le montage `/uploads` reste present pour compatibilite; privilegier `/api/files`.
- Les perimetres fins chefs de pole/projet peuvent encore etre renforces sur certaines vues globales.

## Limites fonctionnelles

- Routes dediees profil et parametres a ajouter en V1.1.
- UI admin complete pour Archives/Academy encore perfectible.
- Tests automatises multi-role a ajouter.
- Certains contenus historiques restent a enrichir avec preuves et medias reels.
