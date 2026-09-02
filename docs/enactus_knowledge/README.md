# Base de connaissance Enactus ESP

Cette arborescence centralise les documents internes et ressources de référence
utiles au développement et à l'évolution d'EnactSpace.

## Structure

- `sources/` : documents sources conservés dans leur structure d'origine.
- `catalog/sources.csv` : inventaire, empreinte SHA-256 et classification.
- `normalized/` : contenu textuel normalisé généré à partir des sources.
- `analysis/` : analyses métier et recommandations pour EnactSpace.

## Classification

Les documents contenant des données personnelles sensibles, des signatures,
des mesures disciplinaires, des listes nominatives détaillées, des
autorisations parentales ou certains médias personnels ne sont pas stockés
dans ce dépôt.

Ils restent dans un stockage restreint séparé.

## Git LFS

Les formats binaires sont stockés via Git LFS afin de préserver la taille et
la maintenabilité du dépôt.

## Mise à jour

Les sources locales de référence se trouvent hors du dépôt.
Toute nouvelle synchronisation doit :

1. inventorier les nouveaux fichiers ;
2. calculer leur SHA-256 ;
3. appliquer la classification ;
4. exclure les ressources restreintes ;
5. mettre à jour `catalog/sources.csv` ;
6. vérifier Git LFS avant commit.

## Utilisation

Cette base doit notamment servir à :

- documenter le fonctionnement d'Enactus ESP ;
- améliorer les règles métier d'EnactSpace ;
- conserver l'historique et les ressources des projets ;
- alimenter les modules projets, pôles, impact, finance, communication,
  événements, formation, partenariats et archives ;
- faciliter la passation au Pôle IT.

Les documents sources ne constituent pas automatiquement des politiques
institutionnelles à jour. Leur contenu doit être daté, contextualisé et
validé avant d'être transformé en règle métier.