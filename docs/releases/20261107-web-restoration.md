# Restauration du Web pendant la campagne — 7 novembre 2026

La base de cette correction est la branche d’intégration du 7 novembre
(`4fa381ef010015d61c917291a86aa6119eef3a18`). Elle conserve les changements
récents du recrutement et des membres : seuil de trois avis, priorité aux
dossiers peu évalués, lecteurs temporaires et suppression sécurisée de comptes.
Le backend et les données de production ne font pas partie de cette livraison.

## Régressions corrigées

- Le formulaire actif indiquait `eligibility_required=true`, mais son client
  n’envoyait plus `other_clubs_count`. Le contrôle préalable, le nombre déclaré
  et sa transmission JSON/multipart sont rétablis. Les années terminales restent
  exclues ; les messages de doublon et de reprise après erreur sont conservés.
- Le résultat de présélection, le questionnaire obligatoire, l’entretien invité,
  le guide d’équipe et le calendrier modifiable sont rétablis. Les candidats
  voient seulement les dates de dépôt ; le planning détaillé reste interne.
- Les vues Alumni et Archives, les illustrations et les parcours associés sont
  récupérés de la version du 6 novembre. Une chronologie vide conserve le centre
  Archives moderne et permet de parcourir les collections existantes.
- Le correctif EnactMeet attend le conteneur Flutter, fonctionne dans le shadow
  DOM et annule une ouverture abandonnée. La création rapide simplifiée est
  conservée. Le candidat peut rejoindre son entretien sans compte membre.
- Les outils de passage Alumni sont remis aux côtés de la suppression de
  compte ; aucun compte n’est modifié lors du déploiement.

## Vérifications et publication

Les tests couvrent notamment l’envoi d’une candidature éligible et de son nombre
de clubs, les fichiers joints, les doublons, les erreurs de connexion, les droits
consultatifs, les trois avis et les vues restaurées. Les essais d’inscription sont
réservés à des données synthétiques et à une base isolée.

Le build Web utilise une configuration client externe, conserve Firebase/VAPID,
porte une version distincte et enregistre le commit, l’arbre Git et les empreintes
du bundle. Le script de compilation bloque une livraison sans API, sans nombre
de clubs ou sans le correctif EnactMeet. Aucun APK n’est prévu.

À la préparation de cette correction, le site public et l’API répondent. Le Web
servi a pour empreinte `fa19f83ae52ee3f88ec6ea7c1d1ec68b5c7f527d7b231bce0ddaa49486e130a7`.
L’accès SSH au VPS est indisponible : aucune nouvelle publication ne doit être
annoncée avant le transfert, le contrôle de l’empreinte servie et une vérification
publique du parcours candidat. La livraison est limitée au Web, sans migration,
modification de campagne, effacement de dossier ou envoi de mail réel.
