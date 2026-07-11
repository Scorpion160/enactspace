# EnactSpace V1.1 - Rapport test import membres reels

Date du test: 2026-07-11

## Perimetre

Test local du workflow d'import des membres reels Enactus ESP avant tout `apply`.

Fichier source utilise localement:

```text
C:\Users\DIOP\Documents\Enactus\documents\listes_enacteurs.ods
```

Sortie CSV privee:

```text
data/import/private/membres_enactus_import.csv
```

Le fichier ODS reel et le CSV genere contiennent des donnees personnelles. Ils ne sont pas suivis par Git et ne doivent pas etre committes.

## Environnement Python

Le venv backend local a ete recree et les dependances ont ete reinstallees depuis `backend/requirements.txt`.

Verifications:

```text
SQLAlchemy: 2.0.51
FastAPI: 0.139.0
```

## Conversion ODS

Commande:

```powershell
.\backend\.venv\Scripts\python.exe tools\convert_members_ods_to_csv.py `
  --input "C:\Users\DIOP\Documents\Enactus\documents\listes_enacteurs.ods" `
  --output "data\import\private\membres_enactus_import.csv"
```

Resultat:

```text
26 ligne(s) convertie(s)
```

## Dry-run CLI

Commande:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\backend
.\.venv\Scripts\python.exe -m app.scripts.import_members `
  --file ..\data\import\private\membres_enactus_import.csv `
  --dry-run
```

Resultat:

```text
Lignes lues: 26
Utilisateurs crees: 26
Utilisateurs mis a jour: 0
Roles ajoutes: 50
Liaisons poles ajoutees: 32
Liaisons projets ajoutees: 23
Erreurs bloquantes: 0
Avertissements: 16 emails manquants avec identifiants internes temporaires proposes
```

Aucun import reel n'a ete applique: mode `DRY-RUN`.

## Preview API

Endpoint teste localement:

```text
POST http://127.0.0.1:8000/api/members/import/preview
```

Resultat agrege:

```json
{
  "health_ok": true,
  "total_rows": 26,
  "valid_rows": 26,
  "error_rows": 0,
  "warning_rows": 16,
  "duplicates": 0,
  "created_users": 26,
  "updated_users": 0,
  "pole_links": 32,
  "project_links": 23
}
```

Le test API a volontairement affiche uniquement les compteurs, sans noms, emails, telephones ni autres donnees personnelles.

## Observations

- Les 26 membres du fichier reel sont reconnus.
- Aucune erreur bloquante n'a ete detectee.
- Les avertissements concernent des emails manquants.
- Les poles coeur, poles support et projets sont reconnus par la logique actuelle.
- Le CSV prive est ignore par Git via `data/import/private/`.

Pendant le demarrage local du backend, `python-dotenv` a signale des lignes `.env` locales non parsees. Le fichier `.env` reel n'est pas commite; il faut verifier localement les lignes indiquees avant une recette longue.

## Decision

Statut: pret pour validation manuelle du preview.

Ne pas lancer `apply` sur une base de production avant:

1. validation humaine des avertissements email;
2. sauvegarde de la base cible;
3. preview sur VPS;
4. accord explicite pour import reel.
