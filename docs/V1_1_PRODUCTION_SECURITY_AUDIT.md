# EnactSpace V1.1 - Audit securite production

Date: 2026-07-13

## Risques critiques

| Risque | Statut | Action |
| --- | --- | --- |
| Secrets dans Git | corrige | `.env`, cles PayDunya, backups, APK et imports reels sont ignores/interdits. |
| PostgreSQL expose publiquement | a verifier | Configurer acces local uniquement et pare-feu VPS. |
| HTTPS absent | a verifier | Installer Nginx + certificat avant recette externe. |
| Migrations non controlees | corrige partiellement | Alembic baseline ajoute; tester sur copie de base V1 avant production. |

## Risques eleves

| Risque | Statut | Action |
| --- | --- | --- |
| CORS trop large | a verifier | `CORS_ORIGINS` doit contenir uniquement les domaines officiels HTTPS. |
| Fichiers servis sans controle | corrige partiellement | Nginx bloque `/uploads/`; acces par API a verifier pendant recette. |
| Secrets QR/NFC reutilises | corrige | Config valide que QR/NFC different des secrets JWT en production. |
| PayDunya non teste sandbox | accepte temporairement | Marque READY WITH CONFIGURATION jusqu'a reception des cles. |
| Auto-create schema en production | corrige | `AUTO_CREATE_TABLES=false` dans l'exemple production. |

## Risques moyens

| Risque | Statut | Action |
| --- | --- | --- |
| Rate limiting global incomplet | accepte pour RC interne | Ajouter reverse-proxy limits si exposition publique large. |
| Logs non structures | a verifier | Journald suffit pour RC; structuration JSON future possible. |
| Emails SMTP indisponibles | accepte | Notifications internes restent le fallback. |
| Activation membres a finaliser | a verifier | Parcours d'activation securise a confirmer avant import definitif. |

## Risques faibles

| Risque | Statut | Action |
| --- | --- | --- |
| Swagger accessible | accepte temporairement | Proteger/desactiver avant ouverture publique si necessaire. |
| NFC copiable | accepte | NFC est un outil pratique, pas un facteur cryptographique fort. |

## Checklist avant RC1

- `python -m app.scripts.validate_environment` OK sur VPS;
- `alembic upgrade head` OK;
- `AUTO_CREATE_TABLES=false`;
- `/health` HTTPS OK;
- `/api/system/status` HTTPS OK;
- backup PostgreSQL teste;
- backup uploads teste;
- service backend non-root;
- aucun secret dans logs;
- PayDunya reste sandbox ou desactive tant que non teste.
