# EnactSpace — inventaire avant mise en service officielle

Date de contrôle : 7 octobre 2026. Ce document distingue les corrections déjà livrées, les défauts confirmés par cet audit et les parcours qui doivent encore être validés sur la version finale. Un test automatisé réussi ne suffit pas à déclarer tous les usages réels opérationnels.

## État constaté

| Élément | État |
| --- | --- |
| Web et serveur | Dernière livraison : 1.0.11+14 côté client, migration backend 20261006_0025. |
| Alumni | Cinq profils absents réparés ; création du profil liée aux nouvelles transitions Alumni. |
| Projets et Impact | Cinq fiches complétées ; SHERY relié au projet auparavant nommé Cherry ; cinq dossiers PDF de référence privés joints dans Impact. |
| Années | Année 2026-2027 préparée ; ouverture explicite par un responsable. Les tâches et les historiques sont conservés. |
| Tests Flutter | Dernière suite complète : 880 tests réussis ; analyse sans anomalie. |
| Backend de la dernière livraison | 63 tests sur SQLite, dont 3 réservés à PostgreSQL et ignorés ; 28 tests sur PostgreSQL isolé réussis. Les suites se recoupent : ne pas additionner leurs effectifs comme des tests distincts. |
| Android | Nouveau fichier APK 1.0.11 absent au moment de l’audit ; installation et tests physiques du build 14 non validés. Lecture du Samsung par ADB non aboutie. |
| Dépôt | Branche recovery/final-20260927, HEAD 90f1e33cc18737203a35baae9279eefa788839a3. Derniers changements applicatifs non committés. |
| Services serveur | Backend, email, push et Veille en fonctionnement ; compteurs de redémarrage à zéro lors du contrôle. |

Ces constats ne remettent pas dans la liste des développements les corrections déjà réalisées : aperçu de photo, fichiers justificatifs, navigation, textes des archives, parcours Academy et grille humaine de recrutement. Il faut toutefois refaire les parcours concernés sur la version finale.

## Travaux à terminer et validations à obtenir

P0 : indispensable avant ouverture publique. P1 : nécessaire à la qualité et aux usages annoncés. Les éléments explicitement reportés après lancement restent séparés.

| ID | Priorité | Domaine | État actuel | Ce qui reste et critère de clôture |
| --- | --- | --- | --- | --- |
| R01 | P0 | Android final | Livraison inachevée | Terminer la compilation signée, vérifier signature et numéro de version, installer sans remise à zéro, vérifier la conservation de session et exécuter les parcours sur Samsung. |
| R02 | P0 | Emails de recrutement | Lacune confirmée | Informer le candidat par son adresse de candidature pour les étapes importantes, même sans compte : invitation à un entretien, changement communiqué, décision et suite de l’admission. Ne pas envoyer les commentaires internes ni l’indice de présélection. |
| R03 | P0 | Confinement des emails | Protection incomplète | Recontrôler le destinataire immédiatement avant la remise au fournisseur SMTP. Couvrir un message créé avant activation du mode test, une reprise après erreur et une configuration invalide. |
| R04 | P0 | Catalogue des communications | À formaliser | Pour chaque événement, définir destinataire, contenu, lien utile, priorité, canal et dédoublonnage. Distinguer messages nécessaires, notifications facultatives et activité sociale pour éviter les emails répétitifs. |
| R05 | P0 | Permissions | Validation globale à refaire | Tester postulant, Enacteur, Enactrice, Alumni, Veille, financier, Team Leader, secrétaire général, chefs de pôle/projet et adjoints. Refuser les accès et écritures hors de leur périmètre, même en appel direct de l’API. |
| R06 | P0 | Recrutement complet | Parcours implémenté, recette globale à obtenir | Campagne, questionnaire modifiable, dépôt avec fichiers, accusé de réception, suivi, historique, évaluations indépendantes, décision humaine, admission et création du compte. Tester doublons, concurrence et fermeture de campagne. |
| R07 | P1 | Suivi public de candidature | Évolution ouverte | Prévoir une récupération du code de suivi par email vérifié, avec réponse neutre et limitation des tentatives. Le mécanisme automatique de récupération n’est pas présent dans les derniers comptes rendus de livraison. |
| R08 | P0 | Tâches et Veille | Fonctionnement partagé déjà intégré | Vérifier le même identifiant de tâche dans les deux espaces : À faire → En cours → travail remis avec fichier → validation du responsable → Terminé, avec retour pour correction, blocage, échéance et absence de doublon. |
| R09 | P0 | Alumni et ouverture d’année | Corrections livrées, recette finale à obtenir | Tester passage Alumni, visibilité selon confidentialité, relais des tâches ouvertes, fin des responsabilités et historique. Tester ouverture d’année, concurrence entre responsables, confirmation du niveau réel et conservation des travaux antérieurs. |
| R10 | P0 | Academy | Corrections livrées, validation finale à obtenir | Tous les cours et le parcours nouveau membre : accès progressif, leçons complètes, illustrations, quiz, reprise, progression et synchronisation. Tester fin de leçon, quiz terminé, répétition d’envoi et perte de connexion. |
| R11 | P0 | Finances avec justificatifs | Parcours à valider sur appareils | Déclaration espèces/Wave/Orange Money, partage d’un reçu vers EnactSpace, contrôle OCR, corrections manuelles, affectation partielle, validation ou rejet par le financier et mise à jour des soldes sans double paiement. |
| R12 | P0 | Paiement direct PayDunya | Désactivé, clés manquantes | Le paiement automatisé ne peut pas être déclaré opérationnel actuellement. Il faut des clés de test puis une recette des retours, annulations, callbacks signés, doublons et rapprochement avant toute activation réelle. |
| R13 | P0 | Notifications push | Actives mais restreintes au compte de test | Réception sur Android ouvert/fermé, permission refusée, ouverture vers la bonne fiche, déconnexion et renouvellement du jeton. Lever la restriction de test seulement lors de la bascule officielle. |
| R14 | P0 | Sécurité des fichiers et accès | Suites partielles disponibles | Vérifier pièces jointes privées de candidature, finances, tâches, Impact et documents ; téléchargement interdit aux tiers, limites de taille/type, session expirée, révocation de rôle et absence de diagnostic technique dans l’interface. |
| R15 | P0 | Charge de recrutement et stabilité | Mesure finale à obtenir | Fixer une charge cible selon la campagne attendue. Mesurer dépôt, suivi, liste paginée, évaluations simultanées, fichiers et file d’emails. Consigner temps de réponse, erreurs et comportement sous concurrence. |
| R16 | P0 | Sauvegarde et retour arrière | Sauvegardes existantes, restauration à éprouver | Tester la restauration de la base et des fichiers dans un environnement séparé ; vérifier les liens, les versions et les accès. Restaurer un scénario isolé, sans modifier les données réelles. |
| R17 | P0 | Dépôt, CI et documentation | À finaliser | Relire et enregistrer les changements validés ; préserver la sauvegarde préexistante du worker email. Aligner Flutter de la CI (3.44.9 dans le workflow actuel) avec la version de validation locale, mesurer la couverture et obtenir une exécution reproductible des suites. Aucun push inclus dans cet inventaire. |
| R18 | P1 | Interface et accessibilité | Dernière relecture nécessaire | Clair/sombre, téléphone/tablette/web, texte agrandi, clavier, boutons longs, retour système, chargement et erreur. Vérifier aussi les fiches Impact et les formulaires d’édition. |
| R19 | P1 | Archives, Minutes et projets | Contenus enrichis | Relecture des dates, personnes, projets, légendes, images et documents. Les champs opérationnels doivent rester modifiables ; distinguer résultats historiques et objectifs futurs, éviter les comptes doublés entre projets liés. |
| R20 | P1 | Communication | Recette multi-utilisateur à refaire | Texte, audio, photos, fichiers, sondages, mentions, réactions, droits des groupes et envoi après reconnexion. Pas d’email à chaque réaction sociale sans règle de canal définie. |
| R21 | P1 | EnactMeet | Domaine privé et JWT configurés | Appels à plusieurs appareils, micro/caméra, invitations, rôles, fermeture, retour Android et reconnexion. La configuration JWT ne remplace pas ces essais réels. |
| R22 | P1 | Pôles, projets, événements et présence | Outils déjà intégrés | Vérifier affectations, adjoints, filtres d’équipe, documents, séances, justificatifs d’absence, QR/NFC si disponibles sur l’appareil et cohérence du suivi Veille. |
| R23 | P1 | Jeux et classements | Recette multi-appareil à obtenir | Création/rejoindre, tours, déconnexion/reconnexion, fin de partie, points et récompenses sans double attribution. |
| R24 | P0 | Bascule officielle | À réaliser après recette | Fermer les essais, traiter les messages de test en attente, restaurer les destinataires réels des nouveaux emails et push, ouvrir l’année/campagne appropriée et surveiller une première utilisation contrôlée. |

L’EnacChef désigne le Team Leader, le secrétaire général, le financier, les chefs de pôle et de projet et leurs adjoints. Les permissions doivent suivre les responsabilités effectivement attribuées, sans donner automatiquement les mêmes droits à tous ces profils.

## Audit des emails

### Configuration réellement observée sur le serveur

- Emails activés.
- Restriction des destinataires de test activée.
- Boîte de test conforme : dioppylsci@gmail.com.
- Expéditeur conforme : enactus@esp.sn.
- Identifiants SMTP présents, sans lecture ni export de leur valeur.
- Zéro message pending/retry/processing ; zéro message en attente en dehors de la boîte de test.
- Cet audit n’a envoyé aucun email.

L’audit a également exécuté 14 tests existants d’email dans un conteneur isolé sans réseau, avec fournisseur simulé : 14 réussites. Ils couvrent notamment redirection lors de la mise en file, dédoublonnage, préférence utilisateur, erreurs, reprises et rendu HTML.

Un scénario supplémentaire a préparé un destinataire fictif avant traitement et activé la restriction de test. Le fournisseur simulé a reçu le destinataire d’origine : le worker ne recontrôle pas actuellement cette restriction avant l’envoi. Ce diagnostic a été obtenu sans SMTP réel et sans écrire dans la base de production. La file réelle est vide ; le défaut doit néanmoins être corrigé avant les prochaines campagnes d’essai.

### Couverture trouvée dans le code

| Famille | Ce qui est branché | Ce qui reste à valider ou compléter |
| --- | --- | --- |
| Compte et sécurité | Réception d’une demande de compte, réinitialisation, notifications de validation/refus/réactivation et changements de responsabilités. | Parcours complet, liens, expiration, dédoublonnage, textes humains et distinction transactionnel/préférences. |
| Recrutement | Accusé de réception au candidat ; nouvelle candidature aux responsables ; notifications de statut seulement si la candidature est liée à un compte. | Emails d’étapes pour les candidats sans compte, invitation d’entretien, décision et prochaines démarches. |
| Tâches et Veille | Affectation, travail remis, changements, échéances, bilans et alertes. | Destinataires exacts, dédoublonnage entre Tâches et Veille, cadence et confidentialité. |
| Finances | Paiement à vérifier, validation/rejet/annulation, montant à payer et confirmations du fournisseur. | Reçu compréhensible, bon responsable, état du solde et absence de doublon après callback/reprise. |
| EnactMeet | Invitations et événements de réunion via le service commun de notifications. | Liens utiles, permissions, actualisation/annulation et volume d’invitations. |
| Documents, Impact et Archives | Dépôts, validations, refus, corrections et preuves. | Droit du destinataire, lien vers la fiche, périmètre d’équipe et distinction document de référence/résultat mesuré. |
| Années et Alumni | Ouverture d’année, passage Alumni et tâches à transmettre. | Bon périmètre des membres et message adapté à leur statut, sans demander un cursus à une personne qui n’est plus étudiante. |
| Academy, présence, publications et chat | Plusieurs événements sont reliés au service commun ; un email peut être mis en file si les préférences le permettent. | Définir les événements qui méritent un email, ceux qui restent dans l’app et ceux à regrouper en résumé. |

Le routage commun relie actuellement les notifications aux emails selon les préférences. Cette présence dans le code n’atteste pas la réussite de chaque parcours réel.

### Bascule des emails après les tests

1. Terminer la recette avec fournisseur simulé ; réserver les essais SMTP à la seule boîte de test autorisée.
2. Vérifier immédiatement avant chaque envoi que le destinataire est autorisé en mode test.
3. Suspendre brièvement le worker lors du changement de mode et relever les messages en attente.
4. Clôturer ou traiter les messages d’essai ; conserver un relevé technique sans rejouer les anciennes notifications vers leurs destinataires réels.
5. Retirer la redirection pour les nouveaux événements seulement, conserver enactus@esp.sn comme expéditeur et vérifier le rendu des premiers messages.
6. Restaurer séparément le périmètre des push après les tests sur appareils.
7. Vérifier fonctionnement et reprise du worker, erreurs, dédoublonnage et destinataires. La redirection est conservée pendant l’inventaire présent.

## Apport d’ECC et adaptation prévue

Source officielle : https://github.com/affaan-m/ECC.
Révision de référence relevée : ef648e01899ba3e8dc6371642deaaf64b4477775.
Cinq fichiers officiels ont été téléchargés en lecture seule, à cette révision, avec leurs empreintes. Aucun installateur, hook ou code tiers n’a été exécuté ; aucune configuration globale n’a été installée.

| Composant ECC examiné | Utilisation prévue pour EnactSpace |
| --- | --- |
| verification-loop | Rapport par livraison : compilation, analyse/type, suites, couverture, sécurité et relecture du diff. Adapter les commandes à Dart/Flutter et Python. |
| e2e-testing | Structurer les parcours web, données de test et traces d’échec. Playwright pourra servir au web une fois les sélecteurs Flutter réellement accessibles ; il ne remplace pas les tests de l’app Android. |
| eval-harness | Définir le résultat attendu avant les corrections, relier chaque scénario à un défaut et enregistrer la non-régression. Répéter les parcours critiques pour détecter les résultats intermittents. |
| security-review | Cibler rôles, sessions, pièces jointes, recrutement, paiements, limites d’accès et données sensibles. Adapter les exemples de framework au backend réel. |
| .codex-plugin/README.md | Confirmer la voie d’installation Codex et le besoin de vérifier les capacités disponibles. Codex CLI n’a pas été trouvé sur l’ordinateur lors du contrôle. |

ECC sert à organiser et renforcer les vérifications. Les preuves de fonctionnement restent les résultats effectifs de Flutter, des tests Python/PostgreSQL, de la recette web et des essais Android.

La première campagne proposée se fait dans un environnement de recette isolé avec comptes fictifs pour chaque rôle, base séparée, fichiers de test, emails capturés localement et services externes simulés. Les contrôles de production restent des lectures pendant cet audit.

Pour chaque scénario : identifiant, rôle, données initiales, action, résultat attendu côté interface/API/base/email, moteur de test, état réel, journal et preuve de non-régression. Un test critique instable reste ouvert, même s’il réussit après une relance.

Le seuil de couverture indicatif de la démarche ECC est 80 %. La couverture d’EnactSpace n’a pas été mesurée dans cet audit ; le nombre de tests ne permet pas de la déduire. Les chemins sensibles doivent être couverts explicitement, quel que soit ce pourcentage.

## Ordre de travail proposé

1. Corriger le dernier contrôle des destinataires et compléter les emails de recrutement sans compte.
2. Préparer la recette isolée, les comptes par rôle, les scénarios et les preuves de validation selon la démarche ECC.
3. Terminer Android et exécuter les parcours recrutement, Tâches/Veille, Academy, Alumni/année, finances et notifications.
4. Faire la recette multi-appareil, hors connexion, interface, permissions et charge.
5. Valider restauration, CI, documentation et version finale du dépôt.
6. Effectuer la bascule officielle des emails/push et l’ouverture administrative de l’année et de la campagne.

## Évolutions distinctes de l’ouverture actuelle

- Enregistrement EnactMeet avec Jibri : actuellement désactivé, configuration et recette à prévoir.
- iOS natif, biométrie et push iOS : validation non réalisée, nécessite un environnement Apple et des appareils adaptés.
- Activation PayDunya réelle : dépend de la configuration et de la recette du fournisseur ; à distinguer du parcours existant de déclaration avec justificatif.

## Critères pour déclarer la mise en service prête

Les parcours indispensables sont validés sur le web et sur l’APK final ; aucun défaut bloquant confirmé ne reste ouvert ; les accès hors périmètre sont refusés ; les transitions et envois sont cohérents sous concurrence ; les essais ne contactent aucun membre/candidat réel ; les données et fichiers se restaurent correctement ; le mode de production des emails et des push est vérifié ; la version livrée et ses preuves sont documentées.

Un registre séparé conserve les évolutions reportées avec un périmètre clair. La présence de 880 tests réussis constitue une base solide, mais ne remplace pas cette recette de mise en service.
