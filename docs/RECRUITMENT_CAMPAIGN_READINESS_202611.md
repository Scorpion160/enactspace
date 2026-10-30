# Préparation de la campagne Enactus ESP — novembre 2026

État de l'audit : 30 octobre 2026. Ce document organise les preuves, les corrections et les opérations restant à vérifier. Il ne constitue pas une garantie d'absence d'incident. Aucun dossier réel, compte candidat ou e-mail réel n'a été créé pendant les tests locaux. Aucune campagne n'a été activée par cet audit.

## Calendrier confirmé et décisions à compléter

| Étape | Dates 2026 | Réglage ou opération |
|---|---|---|
| Lancement et réception | Mercredi 4 au dimanche 8 novembre inclus | Une campagne avec début `2026-11-04`, fin `2026-11-08` et statut actif |
| Tri des candidatures | Lundi 9 au samedi 14 novembre | Fermer la réception sans supprimer la campagne ; les dossiers, évaluations et suivis restent disponibles |
| Convocations | Au plus tard le 15 novembre, proposition opérationnelle | Vérifier l'envoi et la réception avant le premier entretien ; cette échéance n'était pas explicitement donnée |
| Entretiens | Lundi 16 au samedi 21 novembre | Saisir date, heure et lieu ou lien, jury interne et observations privées |
| Admissions et liste d'attente | Après les entretiens, date à décider | Décisions humaines, notification, puis intégration des admis |
| Première connexion et accueil | Après admission | Activation individuelle, profil, pôle/projet et parcours Academy Nouveau Enacteur |

Le modèle de campagne stocke des dates, pas des heures d'ouverture. Pour ce calendrier, le correctif utilise le jour UTC, qui correspond à l'heure de Dakar : ouverture le 4 à 00 h 00 et dernière journée le 8 jusqu'à 23 h 59 min 59 s. Le 9 à 00 h 00, une nouvelle demande est refusée. L'annonce de lancement peut être publiée plus tard dans la journée du 4 ; une ouverture technique à une heure différente demanderait un autre réglage ou une évolution du modèle.

La note partagée mentionne un test de personnalité distinct et Google Forms. Le produit possède des questions configurables, dont une question de présentation personnelle, mais cet audit n'atteste pas un module séparé de test de personnalité, de notation psychométrique ou d'invitation automatique à un outil externe. Confirmer si cette étape est maintenue, son support, sa date et l'utilisation des résultats. Le parcours EnactSpace reste le parcours principal proposé ; un formulaire externe de secours n'est pas connecté automatiquement à la base.

## État réellement constaté

| Preuve | Résultat |
|---|---|
| Journal de publication transmis | Web **1.0.20, build 23**, succès de compilation, tests du publieur et vérification HTTPS |
| Empreinte du JavaScript publiée | `ba939eeae013086666dc3d8e43eb765bf80f56fc92e14e1252f5baeeab578d20` |
| Retour arrière web | `/opt/enactspace/releases/web-previous-03c47515b491422d94647aa6f8786907` |
| GET public `version.json` effectué pendant l'audit | HTTP 200, `1.0.20` / `23` |
| GET public `/health` | HTTP 200, API `1.0.17`, production |
| GET public des campagnes | HTTP 200, liste vide au contrôle ; cela n'indique pas si une campagne future existe en interne |
| GET sans connexion de la liste des candidatures et de l'export | HTTP 401 pour les deux |
| Prérequête CORS publique du formulaire | HTTP 200, origine web attendue, méthode POST et Content-Type autorisés |
| Backend / Android lors de la publication web | Non modifiés d'après le journal |

La santé HTTP ne prouve ni la délivrance d'un e-mail, ni la restauration d'une sauvegarde, ni le fonctionnement sous forte affluence. Les correctifs backend décrits ci-dessous sont des sources préparées ; leur présence en production doit être contrôlée avant de les considérer actifs.

## Corrections préparées dans cet audit

1. Les champs d'identité sont bornés selon les colonnes de la base et contrôlés avant écriture. Un champ trop long reçoit une réponse 422 plutôt que de risquer une erreur PostgreSQL. Les titres de campagne et le lieu d'entretien sont également bornés.
2. Les champs obligatoires représentables par un ancien client restent obligatoires lorsqu'il n'envoie pas le questionnaire structuré. Les questions personnalisées obligatoires restent protégées. Les libellés et réponses sont conservés à la soumission.
3. L'ouverture et la dernière journée se fondent explicitement sur l'horloge UTC. Un verrou partagé de campagne est pris pendant une soumission ; une modification ou clôture prend un verrou exclusif. Les soumissions peuvent conserver des verrous partagés en parallèle. Cette coordination exige une recette de concurrence sur PostgreSQL ; SQLite ne la démontre pas.
4. Une campagne contenant des candidatures doit être clôturée et ne peut plus être supprimée en bloc. Une campagne vide reste supprimable. Cela ne retire pas les actions individuelles de gestion déjà présentes.
5. Les notifications de nouvelle candidature visent les responsables actifs et vérifiés ainsi que les membres actifs du pôle Veille. Un ancien responsable alumni est exclu. Avant l'envoi d'une notification de recrutement encore en file, les autorisations du destinataire sont vérifiées de nouveau.
6. Les cellules pouvant être interprétées comme formules sont neutralisées dans le CSV. L'export accepte un `campaign_id`, expose la promotion, le niveau et le canal de découverte, et charge les avis par lot. Le paramètre de campagne est disponible dans l'API ; le bouton de l'ancien écran, sans paramètre, continue d'exporter toutes les campagnes. La nouvelle vue interne n'a pas reçu de nouveau bouton d'export dans cette étape.

Le test de première connexion contenait une chaîne de neuf caractères appelée « too short », alors que le minimum est huit. Seule cette donnée de test a été remplacée par une chaîne de cinq caractères ; la politique de mot de passe n'a pas été assouplie.

## Scénarios et réponse prévue

| Situation | Protection ou comportement | Contrôle / action avant lancement |
|---|---|---|
| Campagne absente ou dates erronées | Page sans campagne, dépôt refusé hors période | Vérifier en interne l'unique campagne du 4 au 8 ; ne pas créer un doublon |
| Lien consulté avant le 4 | L'API publique ne liste que les campagnes ouvertes | Prévoir un message de communication annonçant la date ; pas de promesse de compte à rebours non implémenté |
| Candidat sur un ancien onglet après clôture | Date et statut vérifiés par le serveur au dépôt | Tester la dernière minute du 8 et le 9 à 00 h 00 sur une base isolée |
| Clôture pendant un dépôt | Verrous de campagne coordonnés dans le correctif | Tester les deux ordres de concurrence sur PostgreSQL avant déploiement |
| Double clic ou réponse perdue après enregistrement | Bouton bloqué pendant l'envoi ; unicité campagne + e-mail sans distinction de casse | Rejouer le dépôt ; une seule ligne et un seul accusé sont attendus |
| Nouvelle campagne avec le même e-mail | Unicité limitée à la campagne | Vérifier qu'une candidature légitime d'une autre année n'est pas rejetée |
| E-mail mal saisi | Validation du format, pas de preuve de possession lors du dépôt | Le candidat doit relire son adresse ; prévoir une procédure de correction vérifiée par l'équipe |
| Code de suivi perdu ou accusé non reçu | Suivi exige e-mail + code ; pas de récupération publique dédiée attestée | Canal d'assistance et vérification d'identité ; retrouver le dossier en interne sans publier de code |
| Coupure réseau ou erreur serveur au dépôt | Message distinct, réponses et fichiers conservés dans l'écran pour réessayer | Vérifier retour aux étapes et nouvel envoi sans doublon |
| Fermeture ou rechargement de l'onglet avant envoi | Le brouillon actuel est en mémoire de l'écran | Ne pas présenter cela comme une sauvegarde durable ; décider d'une sauvegarde explicite avant de la promettre aux candidats |
| Retour sur une étape / modification du récapitulatif | Les autres réponses et le CV restent en place ; confirmation redemandée | Parcours de recette mobile complet |
| Changement du questionnaire pendant la saisie | Version refusée avec 409 ; relecture demandée et réponses conservées | Figer questions et critères avant le 4 ; ne pas éditer pendant la réception hors nécessité validée |
| Question requise omise, réponse inconnue ou trop longue | Contrôles serveur du questionnaire | Tester formulaire courant et ancien client ; le web actuel est le canal de référence |
| Champ d'identité trop long ou vide | Limites et nettoyage avant écriture | Cas limites 100/150/30 caractères selon le champ |
| Promotion ou canal « Autre » incohérent | Canonicalisation de l'année académique et du canal de découverte | Vérifier cohérence formulaire, fiche et export |
| CV vide, exécutable, extension trompeuse ou document corrompu | Type et signature contrôlés ; fichier refusé avant persistance | Cas PDF, images et formats bureautiques autorisés ; aucun fichier orphelin |
| CV trop lourd | Maximum 10 Mio par pièce, trois pièces possibles ; corps global borné à 32 Mio | Vérifier aussi la limite du proxy public : le contrôle applicatif ne prouve pas celle du tunnel |
| Stockage plein ou non persistant | L'erreur d'envoi doit permettre de réessayer ; surveillance nécessaire | Montage persistant, droits du backend, réserve d'espace, sauvegarde des fichiers et de la base |
| Document privé demandé par un tiers | Téléchargement authentifié et autorisations recrutement | Membre ordinaire, alumni et utilisateur non connecté refusés ; jury habilité autorisé |
| Affluence depuis un même Wi-Fi | Quotas par IP et par identité, message 429 et possibilité de réessayer | Tester un NAT partagé ; ne pas retirer les quotas ; vérifier les IP transmises par le proxy |
| Limite d'envoi atteinte sur une adresse | Quatre tentatives de dépôt par identité sur quinze minutes dans le code actuel | Éviter les essais répétés sur de vraies adresses ; contrôler Retry-After et conservation du brouillon |
| Pic de candidatures | Aucun test de charge de production n'est lancé par cet audit | Fixer le volume, tester la pile PostgreSQL/API/fichiers sur un environnement isolé |
| Beaucoup de dossiers à trier | Chargement par lot des avis et campagnes dans la liste ; réponses complètes encore chargées | Mesurer taille et délai de la liste au volume attendu ; paginer ou alléger si le seuil de recette est dépassé |
| SMTP indisponible | Candidature et accusé en file sont enregistrés dans la même transaction ; envoi par worker | Vérifier worker, progression de la file et réception réelle sur une adresse contrôlée |
| E-mail en échec définitif | État `dead`, reprise automatique limitée | Examiner l'erreur, corriger la cause, reprendre uniquement les messages concernés ; ne pas rejouer les envois `sent` |
| Responsable retiré du jury | Accès interne soumis aux rôles/adhésions ; recontrôle des notifications en attente dans le correctif | Retirer les habilitations effectives, pas seulement masquer un menu |
| Deux jurés évaluent le même dossier | Avis distinct par juré ; révision remplace son propre avis | Deux lectures indépendantes conseillées, calibration de la grille et répartition des dossiers |
| Note ou indice élevé | Aucun passage automatique à l'admission | Décision collective et traçable ; vérifier les besoins et places annoncés |
| Entretien déplacé | Historique conservé ; nouvel e-mail si date, lieu ou lien publics changent | Vérifier la nouvelle réception et le suivi ; notes et jury internes restent privés |
| Mauvais fuseau d'un poste de jury | Les envois et e-mails sont basés sur UTC ; l'interface de saisie utilise l'heure du poste | Recette avec postes réglés sur Dakar ; un poste hors Dakar doit faire l'objet d'un contrôle spécifique avant convocation |
| Deux candidats au même horaire ou juré indisponible | Pas de moteur de disponibilité ou d'anti-collision démontré | Construire un planning par jury, durée, pause et salle ; contrôler les conflits avant les envois |
| Absence, retard ou demande de report | Gestion humaine, replanification possible avant décision finale | Réserver des créneaux de reprise et un contact candidat ; conserver la trace |
| Mauvais destinataire ou décision terminale erronée | Confirmation renforcée et transitions limitées | Double contrôle avant admission/refus ; une correction exceptionnelle passe par une procédure administrateur documentée, pas une requête SQL improvisée |
| Suppression accidentelle d'une campagne | Suppression de campagne non vide bloquée par le correctif | Clôturer ; ne pas utiliser la suppression pour préparer le tri |
| Export partagé ou ouvert dans Excel | Export protégé et formules neutralisées | Exporter seulement la campagne utile, limiter les destinataires et protéger le fichier local |
| Compte déjà existant à l'admission | Réutilisation du compte compatible ; pas d'écrasement automatique d'un alumni/suspendu | Tester les comptes existants, la conversion répétée et les conflits en concurrence |
| Conversion répétée / deux responsables | Verrous, unicité et réponse idempotente déjà présents | Tests PostgreSQL réels avant d'attester la concurrence |
| Activation expirée ou mot de passe oublié | Code à usage unique, durée limitée, tentatives limitées, renvoi encadré | Tester activation, renvoi, saisie erronée et connexion ; aucun mot de passe diffusé par le bureau |
| Intégration après campagne | Profil, affectations et parcours Nouveau Enacteur | Contrôler le pôle/projet choisi, l'accès au chat et aux documents, puis la première formation |
| Panne, erreur de publication ou perte de données | Retour arrière applicatif et sauvegardes vérifiées | Conserver la bonne image et le web précédent ; tester restauration base + fichiers sur clone avant le 4 |
| Candidat introuvable après panne | Ne pas demander un second dépôt avant recherche | Rechercher le dossier par campagne/e-mail et vérifier les accusés ; réconcilier les demandes de secours sous contrôle |
| Fin de campagne et conservation des dossiers | Les suivis continuent après fermeture ; accès interne restreint | Fixer la durée de conservation et l'information aux candidats, puis archiver selon une procédure validée par le bureau |

## Capacité et organisation

Le nombre attendu de candidatures, le nombre de places, la durée d'entretien et le nombre de jurys en parallèle restent à confirmer. L'audit de stockage utilise par défaut une **hypothèse de 500 candidatures**, modifiable par `--expected-candidates` ; il ne s'agit pas d'un volume annoncé par l'équipe.

Réserve conservatrice de stockage : `candidats × 3 pièces × 10 Mio × 2`, avec un minimum de 2 Gio. Le facteur 2 réserve une marge pour une copie supplémentaire ; il ne garantit pas la capacité de toutes les sauvegardes ni celle d'un stockage distant.

Capacité d'entretien : `jours × heures utiles/jour × 60 ÷ minutes/créneau × jurys parallèles`, puis garder une marge pour retards et reports. Exemple de dimensionnement, pas planning adopté : 6 jours, 5 heures utiles et 20 minutes par créneau donnent 90 entretiens par jury avant marge.

Prévoir un responsable campagne, un suppléant, un responsable technique, un référent des convocations et un contact candidat. Les noms et disponibilités restent à désigner ; l'application ne les déduit pas.

## Recette avant ouverture

1. Exécuter l'inventaire en lecture seule `tools/audit_recruitment_campaign.py` sur le VPS et examiner ses `blockers` et `unverified`.
2. Déployer les correctifs backend seulement après contrôle des tests et de la sauvegarde ; comparer les trois empreintes de source attendues par l'inventaire. Aucun changement de schéma n'est requis par ces correctifs.
3. Rejouer les parcours et la concurrence sur un PostgreSQL dédié, sans accès à la base de production. Inclure dépôt simultané du même e-mail, clôture contre dépôt, conversion répétée et conversion contre suppression.
4. Mesurer le pic attendu sur une copie isolée, en incluant les documents. Relever latence, erreurs, nombre de lignes, espace et file des e-mails. Ces mesures ne sont pas fournies par les tests SQLite.
5. Faire la recette navigateur réelle à 320/390 pixels et sur les navigateurs utilisés : clavier, menu, retour, fichiers, code sélectionnable, suivi, ouverture du lien depuis un e-mail et contraste clair/sombre. Tester Safari/iPhone si le public l'utilise.
6. Vérifier l'envoi réel vers une adresse contrôlée dans une campagne de recette identifiée, avec accord de l'opérateur ; vérifier spam et lien du suivi. Ne pas détourner les messages des vrais candidats vers cette adresse.
7. Vérifier une sauvegarde récente, sa restauration sur clone, la conservation des fichiers privés et la copie hors du VPS. Le simple statut actif du timer ne suffit pas.
8. Relire et figer dates, description, éligibilité, questions, grille, capacités, contact et procédure de report avant le 3 novembre au soir. Faire confirmer la compréhension du parcours par un candidat fictif et un juré.

## Pendant et après la campagne

- Chaque matin et après une diffusion importante : santé web/API, campagne attendue, nombre de dossiers, accusés récents, file en erreur, stockage et dernière sauvegarde. Les seuils d'alerte doivent être attribués à une personne joignable.
- En cas d'incident : conserver heure, statut et identifiant technique sans publier de CV ni réponse ; désigner un responsable, informer les candidats sur le canal annoncé et noter les demandes reçues. Fixer un délai de nouvelle information ; ne pas inventer de date de rétablissement.
- Un retour arrière du code ne doit pas restaurer une ancienne base au-dessus de candidatures récentes. Une restauration de données exige comparaison et réconciliation des dépôts depuis la sauvegarde.
- Le 9 : vérifier la clôture, compter les dossiers et conserver un export protégé ; attribuer les lectures. Le suivi candidat et la gestion interne doivent rester ouverts.
- Avant le 16 : vérifier planning et convocations réellement reçues, salles/liens, jury de secours et modalités de report.
- Après les entretiens : vérifier avis, décisions et nombre de places, puis traiter admissions et attente. Tester l'activation d'un premier admis avant de traiter tout le lot.
- Après intégration : vérifier les affectations et l'accueil Academy ; retirer les habilitations temporaires du jury et archiver la campagne avec une politique de conservation explicitement validée.

## Validation automatisée et limites

Les tests sont exécutés localement avec Python 3.12, une base SQLite éphémère, des fichiers fictifs et des fournisseurs de notification simulés. Ils n'envoient pas d'e-mails réels et n'utilisent pas la base de production. Les versions installées satisfont `backend/requirements.txt` ; cela ne prouve pas qu'elles sont identiques à l'image de production.

Les tests de campagne couvrent les dates limites, la clôture, le suivi après fermeture, les bornes d'identité, les réponses obligatoires des anciens clients, le doublon sans distinction de casse, l'accusé en file sans connexion SMTP, les destinataires autorisés, le retrait d'autorisation avant envoi, la suppression de campagne et les exports. Les tests de l'outil couvrent ses requêtes en lecture seule, les sauvegardes, les erreurs bloquantes et l'interdiction de conclure à une campagne prête sur la seule base de l'inventaire.

Résultat local : **150 tests réussis, aucun échec et aucun test ignoré**, en 42,317 secondes lors du dernier passage. Ce total comprend 14 nouveaux tests de campagne, 6 tests de l'inventaire et 130 tests existants couvrant questionnaire, préparation, historique, grille, fichiers, permissions, e-mails, première connexion et quotas. La syntaxe des fichiers Python modifiés a également été contrôlée.

Les contrôles VPS restent à compléter avec leur compte rendu. Tant que les preuves externes ci-dessus ne sont pas obtenues, l'état reste **préparation en cours**, et non « campagne certifiée prête ».
