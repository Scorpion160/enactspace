# EnactSpace V1.1 - Pointage NFC

Le pointage NFC complete les modes QR et manuel. Il est pense pour un telephone responsable utilise comme lecteur pendant une seance ouverte.

## Parcours

1. Un responsable autorise ouvre `Presences > Badges NFC`.
2. Il selectionne un membre actif.
3. Il approche le badge NFC du telephone.
4. Le backend enregistre uniquement une empreinte HMAC du badge.
5. Pendant une seance ouverte, le responsable utilise `Pointage NFC`.
6. Chaque badge scanne cree une presence ou un retard selon les regles de la seance.

## Endpoints

- `POST /api/attendance/nfc/tags/enroll`
- `GET /api/attendance/nfc/members/{member_id}/tag`
- `POST /api/attendance/nfc/tags/{tag_id}/revoke`
- `POST /api/attendance/nfc/tags/{tag_id}/replace`
- `GET /api/attendance/nfc/tags`
- `POST /api/attendance/nfc/check-in`

## Fallbacks

QR et pointage manuel restent disponibles si le telephone ne supporte pas NFC, si un badge est perdu, ou si le reseau bloque temporairement.
