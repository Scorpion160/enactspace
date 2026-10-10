# Inventaire avant mise en service — après le lot 16
Date : 7 octobre 2026. Cet inventaire distingue les tests déjà documentés des vérifications encore nécessaires. Il ne constitue pas une autorisation de mise en production.

## Avancement vérifié
Les lots 1 à 16 ont renforcé des chemins précis : courriels de test, jetons d'authentification et réinitialisation du mot de passe, limites des requêtes, rôles sensibles, tâches et Veille, finance et justificatifs, paiements Mobile Money et rapprochement. Les preuves et limites figurent dans chaque compte rendu. Les nombres de tests de ces lots se recoupent et ne doivent pas être additionnés comme une couverture globale.

La revue manuelle de tout le dépôt est incomplète. Les catégories du registre sont : 64 fichiers marqués relus intégralement, 6 avec sections relues, 573 autres ou en attente. Ces étiquettes ne démontrent pas à elles seules l'absence de vulnérabilités.

## Ordre des travaux restants
| Priorité | Domaine | Résultat à obtenir avant mise en service |
|---|---|---|
| 1 | Droits d'accès des autres modules | Examiner les pôles, projets, membres, contenus, documents, communication, réunions, présences et jeux ; vérifier membre, responsable, EnacChef, Alumni, compte suspendu et accès aux données d'autrui. |
| 1 | Revue complète du code | Poursuivre les fichiers non relus, les chemins indirects, les entrées utilisateur, fichiers, journaux et configurations ; corriger et tester les problèmes constatés. |
| 1 | Migrations et déploiement | Répéter toute la montée depuis 20261006_0025 vers 20261007_0028 sur une copie isolée, avec sauvegarde, contrôle des données et procédure de retour. |
| 1 | Tâches et Veille | Vérifier dans les interfaces l'attribution, le fichier de preuve, les statuts, la validation par le responsable, les échéances et l'absence de double traitement. |
| 1 | Recrutement | Recette du parcours candidat et jury, questionnaire modifiable, visibilité en sombre, pièces jointes, journal des transitions et critères explicites de présélection. |
| 1 | Alumni et année | Vérifier la transition avec visibilité dans Alumni, conservation de l'historique et retrait des permissions devenues inadaptées ; vérifier le changement d'année sans double traitement. |
| 1 | Courriels et push | Vérifier chaque notification nécessaire et son destinataire en mode test ; conserver la redirection actuelle jusqu'à la bascule finale validée. |
| 1 | Nettoyage ciblé | Revalider le manifeste identifiant une campagne de test et trois candidatures, sauvegarder les objets liés, puis supprimer uniquement les données prouvées de test. |
| 1 | Recette Android et web | Utiliser les versions finales cohérentes frontend/backend ; vérifier navigation, retours, sombre, mise en page, zoom, pièces jointes, connexion et reprise réseau. |
| 2 | Academy | Vérifier progression, blocages cohérents, leçons et illustrations, quiz, reprise, boutons, contraste et synchronisation réelle en ligne/hors ligne. |
| 2 | Archives, projets et Impact | Relecture humaine des contenus, cohérence historique, projets renseignés, légendes, photos, minutes de 2020 et hommage au professeur Ndiaga Ndiaye. |
| 2 | Profil et authentification | Vérifier aperçu de la photo, profils, tri par nom puis prénom et biométrie sur le téléphone, sans réinitialisation ni contournement. |
| Conditionnel | PayDunya | Configurer les clés du mode test et faire la recette de factures, confirmations et callbacks ; laisser Mobile Money désactivé tant que cette recette n'est pas validée. |
| Final | Documentation et ouverture | Terminer guides par rôle, exploitation, sauvegardes et incidents ; effectuer une validation regroupée, construire les versions finales, déployer, vérifier et rétablir les destinataires des courriels. |

## Conditions conservées
Aucun build intermédiaire inutile, aucun push Git et aucune suppression globale de données. L'année 2026–2027 est préparée mais son activation reste à vérifier. Les courriels de test restent redirigés vers dioppylsci@gmail.com ; l'expéditeur institutionnel reste enactus@esp.sn. La production n'intègre pas encore les correctifs des lots de préproduction.

L'enregistrement Jibri et une distribution iOS restent des sujets distincts : aucun résultat local iOS n'est annoncé sans environnement Apple.
