# EnactSpace V1.1 - Import membres reels

Objectif: importer les Enacteurs, Enactrices et Alumni reels sans saisir chaque profil a la main.

## Regle de confidentialite

Ne jamais committer:

- CSV reel des membres;
- numeros de telephone reels;
- emails personnels reels;
- rapports contenant des donnees personnelles;
- mots de passe temporaires.

Le depot contient seulement:

```text
data/import/membres_enactus_template.csv
```

## Colonnes CSV

Colonnes obligatoires:

- `prenom`
- `nom`
- `email`

Colonnes optionnelles:

- `telephone`
- `genre`
- `role`
- `statut`
- `pole_coeur`
- `poles_support`
- `projet`
- `responsabilite`
- `date_adhesion`

Les colonnes recommandees dans l'ordre:

```text
prenom,nom,email,telephone,genre,role,statut,pole_coeur,poles_support,projet,responsabilite,date_adhesion
```

## Valeurs attendues

`statut`:

- `active`
- `pending`
- `alumni`
- `inactive`

`role` peut contenir plusieurs valeurs separees par `;`, `,` ou `|`.

Exemples:

```text
enacteur
chef_pole;enacteur
team_leader;enacteur
secretaire_generale;enacteur
financier;enacteur
alumni
```

`poles_support` peut contenir plusieurs poles:

```text
Communication;Veille
```

`date_adhesion` accepte:

- `YYYY-MM-DD`
- `DD/MM/YYYY`
- `DD-MM-YYYY`

## Commandes

Depuis `backend`:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\backend
```

Verifier l'environnement Python:

```powershell
.\.venv\Scripts\pip.exe install -r requirements.txt
```

Dry-run obligatoire avant tout import reel:

```powershell
python -m app.scripts.import_members --file ..\data\import\membres_enactus.csv --dry-run
```

Application effective:

```powershell
python -m app.scripts.import_members --file ..\data\import\membres_enactus.csv --apply
```

Mettre a jour les comptes existants par email:

```powershell
python -m app.scripts.import_members --file ..\data\import\membres_enactus.csv --apply --update-existing
```

## Ce que fait le script

1. Lit le CSV en UTF-8.
2. Verifie les colonnes obligatoires.
3. Normalise noms, emails, telephones et roles.
4. Detecte les doublons email dans le CSV.
5. Detecte les doublons telephone dans le CSV.
6. Verifie les telephones deja utilises en base.
7. Cree les utilisateurs absents.
8. Peut mettre a jour les utilisateurs existants avec `--update-existing`.
9. Assigne les roles existants.
10. Lie le membre au pole coeur si le pole existe.
11. Lie les poles support si les poles existent.
12. Lie le projet si le projet existe.
13. Produit un rapport d'erreurs et warnings.

## Mots de passe

Le script genere un mot de passe aleatoire non affiche pour chaque nouveau compte.

La procedure recommandee est ensuite:

1. verifier l'email du membre;
2. activer l'envoi email si disponible;
3. demander au membre d'utiliser "mot de passe oublie";
4. ou envoyer un lien d'activation dans une tranche ulterieure.

## Preparation des donnees

Avant `--apply`:

1. Sauvegarder la base.
2. Verifier que les roles existent.
3. Verifier que les poles existent.
4. Verifier que les projets existent.
5. Lancer le dry-run.
6. Corriger le CSV.
7. Relancer le dry-run.
8. Appliquer uniquement quand le rapport ne contient aucune erreur.

## Exemple minimal

```csv
prenom,nom,email,telephone,genre,role,statut,pole_coeur,poles_support,projet,responsabilite,date_adhesion
Awa,Fall,awa.fall@example.com,+221771234567,femme,enacteur,active,IT,Communication;Veille,Terrasen,membre,2026-01-15
```

## Limites V1.1

- Le CSV reel reste manipule hors depot.
- Le script ne cree pas automatiquement les poles ou projets manquants.
- Les mots de passe temporaires ne sont pas affiches pour eviter les fuites.
- L'interface admin d'import est prevue dans la tranche suivante.
