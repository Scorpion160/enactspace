# Passation technique au pôle IT

Cette page sert de point de départ à la personne qui reprend EnactSpace. V1 conçue et développée par Chicodev. La maintenance est confiée au pôle IT d’Enactus ESP. Le responsable du pôle organise les accès et valide la prise en main avec un second mainteneur.

## Première semaine

| Échéance | À faire | Preuve de prise en main |
| --- | --- | --- |
| Jour 1 | Accéder au dépôt et aux procédures, identifier le code livré et les responsables des services | Clone isolé de la branche de reprise, liste des rôles et versions concordantes avec la fiche de release |
| Jours 2 et 3 | Lancer API et Flutter avec une base locale, visiter la démo et suivre une fonctionnalité de l’écran à la base | Démarrage reproductible, sonde de santé, test ciblé avec un rôle autorisé et un rôle refusé |
| Jours 4 et 5 | Soumettre une contribution de test ou une correction réelle et la faire relire | PR ciblée, résultats des tests, impact sur données, accès et publication |
| Avant l’astreinte | Répéter une publication et une restauration en environnement isolé | Reçus, mesure de la restauration, décision de retour arrière documentée et revue |

Commencer par la [fiche de la version en service](releases/20261103-web-1.0.25-backend-1.0.23.md), puis suivre [architecture](ARCHITECTURE.md), [développement](DEVELOPMENT.md), [tests](TEST_MATRIX.md) et [exploitation](OPERATIONS_RUNBOOK.md). Le code de reprise est sur `feature/recruitment-ui-20261101`. La branche par défaut `main` porte un état applicatif antérieur et oriente vers la branche de reprise. La convergence des branches fait l’objet d’une revue d’intégration propre.

## Attribution des responsabilités

| Activité | Exécution | Décision et revue |
| --- | --- | --- |
| Triage, contributions et dépendances | Mainteneur pôle IT | Responsable du pôle avec référent métier |
| Production et retour arrière | Opérateur habilité | Responsable de publication et second relecteur |
| Migrations, sauvegardes et restauration | Référent données et exploitation | Responsable de publication avec pôle IT |
| DNS, TLS, SMTP, Firebase et Jitsi | Propriétaire de chaque service et référent pôle IT | Enactus ESP pour les comptes et accès |
| Candidatures et dossiers privés | Responsables recrutement habilités | Enactus ESP pour finalité, durée et export |
| Signature Android/iOS et boutiques | Responsable de livraison mobile | Titulaire institutionnel du compte |
| Incident ou exposition | Référent sécurité et exploitation | Autorité Enactus ESP et propriétaires concernés |

`@Scorpion160` est le contact GitHub de repli. Formaliser l’équipe GitHub, les binômes, les canaux privés, les habilitations et les suppléants. Consigner la personne, le périmètre, la date et la preuve d’accès par rôle dans un espace institutionnel restreint. La [politique de sécurité](../SECURITY.md) décrit l’escalade.

## Accès à vérifier

- [ ] Dépôt, revue, checks Actions, règles de branches et droits de publication.
- [ ] Hébergeur, accès SSH nominatif, proxy, DNS, certificats et journaux.
- [ ] Accès PostgreSQL approprié, volume des fichiers, sauvegarde hors site et procédure de déchiffrement.
- [ ] SMTP institutionnel, Firebase/GCP, Jitsi privé et fournisseur de paiement si le périmètre le prévoit.
- [ ] Coffre institutionnel, clés de signature, comptes de boutiques et récupération d’accès.

## Valider le transfert

Chaque responsable doit pouvoir expliquer un flux métier, reproduire son test, publier un lot de recette et indiquer l’action à prendre si un contrôle échoue. Vérifier une restauration complète en isolation, y compris les fichiers et les droits. Conserver une preuve de revue et les durées mesurées. Faire décider à Enactus ESP les objectifs RPO/RTO et les droits restants.

Les validations fonctionnelles externes sont distinctes de l’état de déploiement. Le dernier lot atteste le web, le backend et son calendrier côté serveur. La visibilité du texte du 23 novembre, la réception contrôlée des notifications et la preuve de distribution mobile sont à documenter selon leur périmètre.
