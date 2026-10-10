# Préparation à la mise en service — lot 2 : accès, sessions et fichiers

Date : 7 octobre 2026. Lot commencé à 10:33 UTC.

## Corrections

- Le montage public /uploads exclut maintenant le répertoire files réservé aux pièces jointes authentifiées. L'exclusion porte sur le chemin physique résolu et couvre également les alias par lien symbolique.
- Les téléchargements et aperçus refusent les chemins physiques extérieurs au stockage autorisé.
- Les aperçus HTML, SVG et XHTML sont proposés en téléchargement, avec un type binaire. Les PDF, images matricielles et textes simples conservent l'aperçu.
- Les réponses de fichiers portent des protections nosniff et une politique sandbox. Les noms des fichiers sont encodés par FileResponse.
- Le point d'accès public aux photos de profil est limité aux images PNG, JPEG, WebP et GIF.
- Les jetons d'accès doivent porter un sujet et une expiration. Les identifiants de compte et de session mal formés sont rejetés avant interrogation SQL.
- Les identifiants de fichier mal formés renvoient une réponse 404.

## Validation isolée

Les tests utilisent la base SQLite temporaire d'un conteneur sans réseau, en lecture seule pour le code et avec un répertoire temporaire pour les données. Les fichiers modifiés sont montés depuis un répertoire de staging ; le code et les données de production ne sont pas remplacés.

La suite couvre :
- absence d'authentification et accès administratif refusé à un membre ordinaire ;
- accès aux fichiers privés d'un autre membre ;
- accès statique direct, chemin encodé et alias symbolique ;
- aperçus HTML/SVG/XHTML, PDF et photo publique ;
- chemin extérieur au stockage ;
- jetons sans expiration, expirés, mal formés ou signés avec une autre clé ;
- sessions inconnues/révoquées, rotation, rejeu, déconnexion et révocation globale ;
- preuves des tâches et validation par le responsable, candidatures et présences privées ;
- transition Alumni, protections de configuration et non-régression des courriels.

Le résultat final, les empreintes des sources et le nombre de tests sont enregistrés dans le fichier JSON de preuves associé après la fin de l'exécution.

## Limites et suite

Cette validation porte sur les scénarios exécutés et sur SQLite. Elle ne remplace pas les tests de concurrence PostgreSQL ni la recette réelle web/Android/iOS. La revue manuelle exhaustive des 617 fichiers initialement inventoriés reste en cours.

À contrôler dans les lots suivants : autres routes et permissions, protection contre les essais répétés sur connexion/OTP/suivi de candidature, configuration du proxy, dépendances, transactions PostgreSQL, CI, parcours Academy et recrutement, responsive et modes clair/sombre. Aucune absence générale de vulnérabilités n'est affirmée.

Aucun courriel ni push réel envoyé ; aucun build, déploiement, suppression de campagne ou changement des destinataires de test effectué pendant ce lot. Les correctifs de ce lot et du précédent ne sont pas encore en production.
