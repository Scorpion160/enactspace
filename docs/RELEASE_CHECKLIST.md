# Checklist de publication

La [dernière fiche de publication](releases/20261103-web-1.0.25-backend-1.0.23.md) consigne les preuves disponibles au 3 novembre 2026. Dupliquer cette checklist pour chaque nouveau lot et joindre les identifiants des preuves.

## Avant bascule

- [ ] Commit, périmètre fonctionnel, composants concernés, versions, révision Alembic, opérateur, relecteur et fenêtre de publication notés.
- [ ] Tests pertinents et contrôle CI du commit relus, avec justification des écarts et tests ignorés.
- [ ] Version et empreinte du bundle web, image backend et source identifiées. Si une image de base est réutilisée, consigner aussi son empreinte.
- [ ] Migration répétée sur PostgreSQL isolé si le schéma change. Compatibilité avec clients et artefact précédent revue.
- [ ] Configuration et droits vérifiés sans publier les valeurs. Sauvegarde PostgreSQL et fichiers vérifiée. Retour arrière préparé avec les artefacts précédents.

## Après bascule

- [ ] Web public HTTPS, version, empreinte et routes représentatives contrôlés.
- [ ] API et trois workers en état attendu, même image et révision correcte. Sondes et parcours concernés rejoués.
- [ ] État des files et incidents vérifié. Calendrier, texte public et réception SMTP/push testés séparément selon le périmètre.
- [ ] Durée, changements effectifs, éventuels écarts et décisions consignés dans une fiche datée liée au [registre des preuves](RELEASE_EVIDENCE_INDEX.md).

## Si le lot contient une livraison mobile

- [ ] Signature de distribution, version et numéro de build, archive et contrôle d’intégrité.
- [ ] Recette physique, autorisations, réception en arrière-plan et déconnexion. Pour iOS, vérification APNs et du profil de distribution.
- [ ] Métadonnées et déclarations de confidentialité conformes aux boutiques. Autorisation de publication et preuve d’envoi conservées.

Voir [le guide d’exploitation](OPERATIONS_RUNBOOK.md) pour les étapes et les critères de reprise, et [le guide mobile](MOBILE_RELEASE_AND_PUSH.md) pour la livraison native.
