# Préproduction — lot 24 : première connexion et accueil

Date : 7 octobre 2026. Dépôt Windows de référence, branche recovery/final-20260927. Correctifs et essais réalisés sans build, déploiement ni push Git.

## Résultat pour chaque personne

| Personne | Fonctionnement implémenté |
|---|---|
| Enacteur ou Enactrice précréé | Code d'activation individuel, choix de son mot de passe, connexion habituelle, profil obligatoire et découverte de l'espace. |
| Membre avec une connexion enregistrée | Son mot de passe est conservé ; les informations manquantes sont demandées lors de l'accueil. |
| Alumni | Accueil adapté, année de fin d'études, conservation du cursus et de l'historique scolaire. |
| Profil sans adresse utilisable | La SG, le Team Leader ou l'administrateur prépare le contact après vérification individuelle. Aucun compte doublon n'est créé. |
| Compte déjà utilisé, adresse devenue inaccessible | Récupération réservée à l'administrateur, justifiée et confirmée explicitement. Révocation des sessions, nouveau contact et choix personnel du nouveau mot de passe. |
| Compte suspendu, refusé, en attente ou incohérent | L'activation ne donne pas accès à l'application. |
| Administrateur de déploiement | Accès préservé pour préparer la mise en service ; exclu des invitations ordinaires. |

Le mot de passe n'est plus demandé aux responsables lors de la création d'un membre ou de la conversion d'une candidature. Le serveur génère un secret initial aléatoire puis le membre définit lui-même son mot de passe. Les comptes issus des imports suivent également la préparation individuelle.

L'accueil repose sur un état serveur ; les informations connues sont préremplies. La saisie obligatoire précède l'espace privé et son contrôle légal existant. Les contrôles backend ne reposent pas uniquement sur la navigation Flutter. Les informations effectivement enregistrées peuvent être retrouvées sur un autre appareil ; les saisies non enregistrées ne sont pas un brouillon persistant.

## Cohortes actuellement présentes

Inventaire agrégé, en lecture seule, sans extraction de fiches personnelles :

- **25 comptes opérationnels cohérents**, dont **un administrateur**.
- **24 comptes non administrateurs sans session enregistrée** dans l'historique disponible.
- **15 comptes non administrateurs avec une adresse absente, provisoire ou réservée** selon le contrôle SQL d'inventaire.
- **Une année courante non archivée**.

Ces comptes ne sont ni modifiés ni invités par cet inventaire. L'absence de session conservée ne prouve pas l'absence d'utilisation d'une ancienne version. La vérification individuelle des contacts et de la situation d'accès reste nécessaire avant les invitations. Le contrôle SQL ne prouve pas la délivrabilité des adresses restantes.

## Protections et cohérence

Codes de huit chiffres, aléatoires, liés au compte et à l'adresse, à usage unique, expiration de 30 minutes et maximum de cinq erreurs. Le défi stocke un HMAC SHA-256 ; le code destiné au membre figure nécessairement dans le corps du courriel en file. Aucun code, mot de passe ou nouveau jeton de connexion n'est renvoyé par les réponses d'activation. L'activation est suivie d'une connexion habituelle.

La préparation de contact, l'invitation et la récupération relisent les comptes et les droits sous verrou. La récupération d'un compte déjà utilisé est réservée à l'administrateur et exige une note de vérification non vide, une confirmation d'identité et une confirmation de révocation des sessions. Les conflits d'adresse annulent la transaction sans perdre les anciens accès. Une récupération concurrente ayant lu l'ancien contact est refusée après la première modification.

Une notification de sécurité est préparée pour l'ancienne adresse utilisable, sans code ni nouvelle adresse. Les confirmations d'activation restent distinctes après une récupération ultérieure. Les réponses de validation HTTP ne réaffichent plus les mots de passe, codes ou données brutes de formulaire.

L'accueil utilise le verrou commun de transition d'année. Il confirme une seule fois le niveau pour l'année courante, réutilise une confirmation existante et refuse une saisie devenue périmée après changement d'année. Le parcours Alumni ne réécrit ni cursus ni niveau historiques et ne crée pas de confirmation scolaire active.

Les écrans utilisent le thème, des contenus défilants et des largeurs limitées. L'accueil a été testé à 320 et 1024 pixels, en mode sombre et avec texte à 200 %. Le formulaire de récupération possède ses contrôleurs dans son propre cycle de vie : le plantage détecté pendant sa fermeture a été corrigé et son scénario a été réexécuté.

## Vérification finale

| Vérification | Résultat |
|---|---|
| Backend SQLite | **141 tests réussis**, 88.928 secondes. |
| Backend PostgreSQL | **45 tests réussis**, 127.004 secondes. |
| Flutter : accueil, activation, services, conversion et sessions | **82 tests réussis**. |
| Analyse Flutter ciblée | Aucune anomalie. |
| Répétition de migration | Réussie : installation neuve, schéma de production isolé, aller-retour, répétition et conservation de l'accueil. |
| Schéma de référence | **110 tables initiales** conservées dans la répétition. |

Les nombres des suites se recoupent ; ils ne doivent pas être additionnés comme des scénarios indépendants. Les suites backend vérifient notamment les comptes inexistants, mots de passe invalides, codes expirés ou réutilisés, cinq erreurs, adresse modifiée, suspensions, rôles Alumni hérités, conflits d'adresse, profil obligatoire, année courante, récupération et révocation d'un véritable jeton de session synthétique.

Les cinq courses PostgreSQL couvrent la double activation, une suspension concurrente, la double complétion de profil, un changement d'année pendant l'attente et deux récupérations simultanées du même compte.

Les derniers essais utilisent uniquement des données synthétiques, avec SMTP et push désactivés. La suite SQLite fonctionne sans réseau ; la suite PostgreSQL utilise son réseau de test interne. Aucun courriel ni paiement réel. Les conteneurs et réseaux nommés du lot sont vérifiés après leur suppression ; aucun nettoyage global de volumes non attribués n'est exécuté.

La revue manuelle couvre les nouveaux modules de première connexion et les portions modifiées de leurs points d'intégration. Le manifeste conserve les empreintes, le nombre de lignes et la portée de cette revue. La revue manuelle intégrale de tout le dépôt reste inachevée.

## État de livraison et suite

Head source : **20261007_0030**. Production : **20261006_0025**, inchangée. La migration a été répétée avant les derniers raffinements du formulaire et des courriels, qui ne modifient pas son schéma. Le retour arrière conserve l'historique d'accueil ; un retour de code impose de garder la maintenance car l'ancien code ignore les nouveaux contrôles.

Guide opérationnel : [premières connexions](../FIRST_ACCESS_ONBOARDING.md).

Restent avant la mise en service globale : terminer les autres audits et la revue du dépôt, répéter une restauration de sauvegarde complète, réaliser la recette Android/web avec le build final, vérifier la couverture des courriels et push, traiter la validation Mobile Money, supprimer la campagne et les candidatures de test selon leur provenance, puis effectuer la bascule approuvée des mails et le déploiement. Ce lot n'annonce pas l'application entière prête à ouvrir.
