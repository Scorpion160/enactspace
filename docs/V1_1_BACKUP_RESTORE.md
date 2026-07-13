# EnactSpace V1.1 - Sauvegarde et restauration

## PostgreSQL

La base PostgreSQL ne doit pas etre exposee publiquement. Utiliser un utilisateur dedie et un acces local uniquement.

Backup recommande:

```bash
sudo mkdir -p /var/backups/enactspace
sudo chown postgres:postgres /var/backups/enactspace
sudo -u postgres pg_dump -Fc enactspace > /var/backups/enactspace/enactspace-$(date +%F-%H%M).dump
```

Restauration sur base vide:

```bash
sudo -u postgres createdb enactspace_restore
sudo -u postgres pg_restore -d enactspace_restore /var/backups/enactspace/enactspace-YYYY-MM-DD-HHMM.dump
```

Avant toute migration production:

1. stopper `enactspace-api`;
2. creer un dump;
3. verifier que le fichier existe et n'est pas vide;
4. restaurer sur une base de test si possible;
5. lancer la migration.

## Fichiers utilisateurs

Dossier recommande:

```text
/var/lib/enactspace/uploads
```

Backup:

```bash
sudo tar -czf /var/backups/enactspace/uploads-$(date +%F-%H%M).tar.gz /var/lib/enactspace/uploads
```

Restauration:

```bash
sudo tar -xzf /var/backups/enactspace/uploads-YYYY-MM-DD-HHMM.tar.gz -C /
sudo chown -R enactspace:enactspace /var/lib/enactspace/uploads
```

## Verification

- restaurer une sauvegarde sur environnement test;
- verifier login, documents, preuves, media, recus, archives;
- verifier permissions de lecture/ecriture du service `enactspace`.
