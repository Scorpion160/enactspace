# Documents institutionnels — prérequis de déploiement

La génération des documents institutionnels Enactus ESP utilise les modèles LaTeX versionnés dans `backend/app/resources/institutional_documents`.

## Moteur PDF

Le backend doit disposer de `pdflatex` avec les paquets LaTeX utilisés par la charte (`babel` français, `geometry`, `xcolor`, `tabularx`, `longtable`, `booktabs`, `enumitem`, `fancyhdr`, `ragged2e`, `microtype`, `hyperref`) ainsi que des fontes PostScript standard utilisées par `helvet`.

### Déploiement Docker

`deploy/Dockerfile.backend` installe automatiquement :

```bash
texlive-latex-extra
texlive-lang-french
texlive-fonts-recommended
```

L'image copie également le logo Enactus ESP déjà présent dans `frontend/assets/img/logo_enactus_esp.png` vers les ressources du moteur PDF.

### Déploiement systemd / VPS

Avant de redémarrer `enactspace-api.service` :

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends texlive-latex-extra texlive-lang-french texlive-fonts-recommended
pdflatex --version | head -n 1
```

Le service systemd utilise `PrivateTmp=true`; la compilation LaTeX se fait dans un répertoire temporaire isolé et ne nécessite aucune écriture dans le dépôt applicatif.

## Vérification applicative

Après déploiement et authentification :

```text
GET /api/institutional-documents/renderer-status
```

La réponse attendue contient :

```json
{
  "available": true,
  "engine": "pdflatex"
}
```

Si `available` vaut `false`, l'API de génération retourne HTTP 503 sans modifier la demande ni créer de document officiel.

## Sécurité

- aucune donnée utilisateur n'est interprétée comme du LaTeX brut ;
- les caractères `\\ { } $ & # _ % ~ ^` sont échappés côté serveur ;
- la compilation utilise `-no-shell-escape` et `-halt-on-error` ;
- le temps de compilation est limité ;
- le fichier produit doit commencer par `%PDF-` et avoir une taille minimale avant archivage ;
- le PDF officiel est stocké avec `storage_scope=official`, `is_official=true` et `is_permanent=true` ;
- le SHA-256 est calculé par le service de stockage existant ;
- une demande déjà générée est idempotente : elle réutilise son `generated_document_id`.

## Logo UCAD

Le moteur sait utiliser `assets/ucad_logo.png` lorsqu'il est fourni dans les ressources institutionnelles. En son absence, la mise en page reste fonctionnelle sans générer une image de remplacement. Le logo Enactus ESP, lui, est repris depuis les assets officiels déjà présents dans le dépôt.
