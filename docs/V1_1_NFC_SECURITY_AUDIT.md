# EnactSpace V1.1 - Audit Securite NFC

## Mesures V1.1

- UID brut non stocke en base.
- Hash HMAC-SHA256 avec `ATTENDANCE_NFC_HASH_SECRET`.
- Secret NFC distinct des secrets JWT et QR en production.
- Un seul badge actif par membre.
- Un badge actif ne peut pas etre attribue a plusieurs membres.
- Badges revoques, perdus, remplaces ou desactives refuses au pointage.
- Double pointage refuse par session.
- Session et perimetre verifies cote backend.
- Tous les scans NFC sont audites avec badge masque.

## Limite assumee

Un UID NFC simple peut etre copie. La V1.1 traite NFC comme une methode pratique de pointage, pas comme un facteur cryptographique fort.

## Evolutions prevues

- NDEF signe.
- Challenge dynamique.
- Badge cryptographique.
- Confirmation ponctuelle par responsable.
- Controle antifraude renforce par contexte de seance.
