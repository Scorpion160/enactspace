# Envoi des candidatures et validation — 6 octobre 2026

Version livrée : **EnactSpace 1.0.8+9**. Le code du serveur reste celui de la version précédente ; sa version d'exécution et le client sont mis à jour. Aucun changement de schéma.

## Diagnostic et correction

La capture signalait un échec d'envoi associé à un conseil de vérifier la connexion. Les journaux de production contiennent deux réponses **HTTP 409** sur l'envoi avec fichiers : le serveur avait reçu les demandes et les avait refusées. Le corps exact de ces deux anciennes réponses n'a pas été conservé dans les journaux consultés.

Une vérification du garde-fou de doublon sur la campagne concernée, dans une transaction explicitement en lecture seule, confirme le contrat : « Une candidature existe déjà pour cet email », statut 409. Cette vérification conserve le nombre de candidatures et ne déclenche aucun e-mail.

Le client reconnaît désormais séparément une candidature déjà enregistrée, un questionnaire modifié, une campagne fermée ou absente, des informations invalides, un document trop volumineux, une limitation des tentatives, une panne du service et une interruption de connexion. Les détails techniques du serveur ne sont pas affichés.

Lorsqu'une candidature existe déjà, un bouton « Suivre ma candidature » ouvre le suivi public. Le retour restaure le formulaire à son étape de confirmation avec ses réponses. Les pièces sélectionnées restent également disponibles après un refus. Le message utilise les couleurs de contraste du thème, y compris en mode sombre.

## Validation automatisée

- **827 tests Flutter réussis** sur la suite complète.
- **44 tests ciblés réussis** sur le formulaire et le contrat HTTP, inclus dans le total.
- **25 nouveaux tests du contrat HTTP** : succès avec et sans fichier, doublon, questionnaire modifié, refus de validation, taille limite, fermeture, campagne absente, limitation, panne et erreurs réseau. Ils utilisent le client API et le service réels avec un transport HTTP simulé ; aucun envoi réel en production.
- Navigation du doublon vers le suivi puis retour au formulaire vérifiée en thèmes clair et sombre.
- **Analyse Flutter : aucun problème signalé**. Un ajout d'accolades dans un test corrige le contrôle de style sans modifier ses assertions.
- **41 tests serveur réussis** : pièces privées, candidature avec fichiers, doublon sans fichiers orphelins, questionnaire et historique. Exécutés dans un conteneur jetable sans accès réseau, avec SQLite et fichiers temporaires, e-mail et push désactivés.

## Contrôles sur le téléphone

Installation réussie sur le **Samsung SM-A065F connecté**, package `sn.enactusesp.enactspace`, version **1.0.8**, code **9**. Même certificat de signature que la version précédente ; aucune suppression des données de l'application.

La première tentative a été arrêtée par des délais d'attente DNS sur le réseau mobile. Le passage au Wi-Fi puis « Réessayer » rétablit l'accueil et la session. Le test photo attend désormais le chargement de l'image et le test de dossier fait défiler le bouton entièrement à l'écran avant de cliquer. Le code de l'application n'est pas modifié par ces ajustements des essais.

Deux contrôles ont réussi sur cet APK avant les interruptions suivantes : aperçu et fermeture de la photo, et présentation du recrutement. Les autres parcours ne sont pas considérés comme validés sur cette version.

Les essais d'ouverture de dossier ont rencontré une notification superposée aux contrôles, des cibles partiellement hors écran et une navigation du pilote vers le menu puis le lanceur Android. Le pilote a été adapté, sans modification de l'application. Au redémarrage final, Android affiche explicitement « EnactSpace », « Authentication required », « Verify identity » et « Déverrouiller votre session EnactSpace ». La suite est arrêtée en attendant la validation biométrique du propriétaire. Aucun contournement de l'authentification n'est effectué.

L'ouverture de dossier, l'historique, le retour à la liste et les quatre contrôles Academy/accueil restent donc à terminer physiquement sur 1.0.8. Les neuf parcours avaient réussi sur 1.0.7 ; ils ne sont pas comptés comme une nouvelle validation complète sur 1.0.8.

Le réglage Android maintenant temporairement l'écran allumé pendant les essais est restauré à sa valeur initiale 0.

Ces essais physiques portent sur les écrans et la navigation. Les erreurs et succès d'envoi sont validés par les tests automatisés et le diagnostic en lecture seule ; aucune candidature de test n'est créée en production. Aucun statut, avis, résultat de quiz ou progression de leçon du compte réel n'est modifié.

## Explication du barème de présélection existant

Le getter `screeningScore`, dans `frontend/lib/features/recruitment/models/application_model.dart`, vient du commit historique `1fa95ba9` et reste inchangé dans cette livraison.

| Critère | Condition actuelle | Points |
| --- | --- | --- |
| Motivation | Au moins 80 caractères après suppression des espaces extérieurs | 20 |
| Connaissance d'Enactus | Au moins 50 caractères | 15 |
| Contribution proposée | Au moins 50 caractères | 15 |
| Profil de leadership | Au moins 40 caractères | 10 |
| Idées de projets | Au moins 40 caractères | 10 |
| Département | Renseigné | 10 |
| Téléphone | Renseigné | 5 |
| Niveau d'études | DIC1/L1 ou certaines mentions de première année : 15 ; DIC2/L2 ou certaines mentions de deuxième année : 10 ; autre niveau renseigné : 5 ; vide : 0 | 0–15 |

Le total est plafonné à 100, sans points partiels sur les cinq réponses textuelles. Les libellés sont : à partir de 75 « Priorité forte », 55–74 « Bon potentiel », 35–54 « À creuser », moins de 35 « Dossier incomplet ».

Ce calcul mesure surtout la complétude et la longueur des réponses. Il n'analyse pas leur pertinence, ne prend pas automatiquement en compte les questions personnalisées et reconnaît imparfaitement les libellés des niveaux d'études. Ses seuils ne prouvent donc pas la qualité d'une candidature ; même le libellé « Dossier incomplet » peut être trompeur.

L'indice affiché est distinct de la note finale : `recompute_application_score`, côté serveur, calcule la moyenne des notes renseignées par les évaluateurs. L'indice ne prend pas de décision d'admission. Une évolution devra séparer la complétude documentaire et une grille qualitative adaptée au questionnaire de la campagne, avec des critères et pondérations explicites.

## Publication et conservation des données

Web public et API vérifiés en **1.0.8**, build web **9** ; JavaScript servi identique au build, sept routes web accessibles. Lectures privées vérifiées pour les catégories de comptes réellement présentes et contrôles d'accès sans authentification.

Sauvegarde complète de la base et du site précédent avant la publication. Comparaison des **111 tables** avant/après le remplacement : données identiques. Révision de schéma `20261004_0022`. Services e-mail, push et Veille relancés.

APK conservé dans `C:\Users\DIOP\Downloads\EnactSpace-1.0.8-release-20261006-candidature.apk`.

Empreintes SHA-256 :
- APK : `ce2c2d6e2a9b4419f500a913daa1023af644050c2b04ab4020f455020f4d260c`
- Certificat : `38e8274a7b63174cbf06f5d5b15e68b623fdb9fae92538ad9b7f470611e484d5`
- JavaScript public : `96b09cc9fb6b5d6fe9d539d0e5632ac37c5fbba0a2bfb53a167afcad9ab8075e`

Les captures et journaux contenant des informations personnelles restent hors du dépôt.
