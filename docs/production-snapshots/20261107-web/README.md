# EnactSpace — sauvegarde des sources Web en production (7 novembre 2026)

Cette révision sauvegarde les **neuf fichiers Flutter et PowerShell** ayant servi à
construire le site Web déployé lors de la campagne Enactus ESP 2026–2027.
Ils ont été extraits du paquet de provenance présent sur le VPS et comparés
octet par octet aux sources du poste local.

La branche `main` est plus ancienne et ne contient pas plusieurs services
du recrutement qui sont déjà actifs sur le VPS. **Ces sources ne doivent pas
être remplacées à l'aveugle dans `main`** : l'intégration nécessite une
réconciliation des dépendances et des tests du parcours complet.

Fonctions visibles de cette version :
- Formulaire public et suivi de candidature.
- Choix préalable : candidat ou enacteur/alumni lors de la création d'un compte.
- Évaluations du jury et consultation EnacChef, avec minimum de trois évaluations.
- Autorisations temporaires consultatives des dossiers.
- Suppression sécurisée des comptes depuis Membres (l'API correspondante est
  uniquement sur le backend en production ; cette archive est centrée sur le Web).

Le seul fichier placé à son chemin d'exécution directement dans cette
branche est `frontend/tool/build_web_production_guarded.ps1`.
Il exige explicitement `ENACTSPACE_API_URL` et vérifie sa présence dans
`main.dart.js` **avant toute publication**.

## Vérifications effectuées

- Les neuf fichiers correspondent au tar de provenance sur le VPS.
- Compilation Flutter Web et analyse Dart ciblée : réussies.
- Vérification SHA256 du fichier `main.dart.js` depuis le domaine public.
- Test du formulaire public dans un navigateur Edge à profil neuf.
- Aucune compilation Android dans ce travail de synchronisation.
- Aucune modification de la base de données ni du serveur durant le présent archivage.

## Intégration à poursuivre

1. Comparer la structure du frontend de `main` avec celle du backend actuellement
   exécuté en production et reconstituer la chaîne de dépendances.
2. Réintégrer les fichiers applicatifs dans un branche d'intégration séparée.
3. Tester analyse, widget tests, soumission et suivi sans créer de vrai dossier
   sur la production.
4. Fusionner dans `main` seulement une fois les CI et tests conformes.

L'archive de la version Web complète et la sauvegarde du précédent site
restent sur le VPS. Ne jamais inclure de fichier `.env`, de clé de signature,
de jeton de production, ni de base de données dans un commit public.
