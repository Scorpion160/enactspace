# EnactSpace 1.0.9+10 — dossiers des projets

Les documents fournis le 6 octobre 2026 complètent les fiches Aquatus, SHERY, Mën Nañ et Terrasen dans Projets et Archives. Les présentations décrivent le besoin social, les solutions, les territoires, la continuité entre initiatives et les résultats datés. Les quatre PDF originaux sont accessibles depuis chaque projet concerné.

## Documents intégrés

| Projet | Document | Pages |
| --- | --- | ---: |
| Aquatus | Dossier de synthèse | 28 |
| SHERY | Présentation du projet | 10 |
| Mën Nañ | Présentation et bilan | 9 |
| Terrasen | Dossier World Cup | 26 |

Les tailles et empreintes SHA-256 figurent dans 20261006-project-source-inventory.json. Les fichiers ont été copiés sans modification ; les pages et l’absence de chiffrement ont été vérifiées avec pypdf. Les photographies existantes des quatre projets accompagnent les présentations.

## Contenu et cohérence

- Aquatus : rencontre à Ngayène Sabakh le 9 septembre 2023, conception du circuit, options de culture et préparation d’un pilote. Les hypothèses de rendement et d’économie d’eau restent des objectifs.
- SHERY : précarité menstruelle, conception de la protection, sensibilisation, accès solidaire et budget de lancement estimé à 2 758 000 FCFA. Les pistes techniques ne deviennent pas des promesses d’efficacité médicale.
- Mën Nañ : Niaguiss, Saré Yoba Diéga et Sinthiou Dimb ; transformation, organisation des GIE, séchoirs et accès à l’eau. Les bilans historiques gardent leur périmètre et leurs périodes.
- Terrasen : production, conservation, transformation et distribution ; volet volaille et perspective Aquatus. Le bilan maad de Niaguiss concerne 2024 ; les comptes de Khaffé distinguent 2023 et le point provisoire d’août 2025.
- Le rattachement de Mën Nañ et d’Aquatus à Terrasen reste lisible sans additionner à nouveau les résultats d’une même activité.

Les documents de lancement et leurs calendriers n’attestent pas, à eux seuls, la réalisation ultérieure des étapes envisagées. Aucun nouveau total global d’impact n’est calculé à partir de ces dossiers.

## Intégration

Un catalogue éditorial unique alimente les présentations dans la réponse des projets et les fiches historiques. Les variantes de noms sont reconnues par correspondance exacte normalisée. Les présentations complètent les données ; aucune affectation, tâche, progression, dépense ou donnée de projet enregistrée par l’équipe n’est remplacée.

Le portefeuille opérationnel comporte Aquatus, Men Nan et Terrasen ; leurs dossiers se retrouvent dans Projets. SHERY est enrichi dans sa fiche des Archives. Le nom « Cherry » existe aussi dans le portefeuille, mais les documents fournis ne permettent pas d’établir une équivalence avec SHERY ; aucun alias ne les fusionne sans confirmation.

La lecture des PDF s’ouvre en plein écran avec fermeture explicite, téléchargement et message lisible en cas d’échec. Les PDF sont livrés avec l’application et le web. Les cartes du résumé projet grandissent avec leur contenu ; les textes gardent une largeur de lecture adaptée sur grand écran. Les thèmes et l’agrandissement du texte sont pris en compte.

## Vérifications

- 91 tests serveur réussis sur une image isolée sans réseau, avec base SQLite de test, email et push désactivés : catalogue, Projets, Archives, Impact, recrutement et pièces jointes.
- 21 nouveaux tests Flutter couvrent les quatre fichiers PDF, le contrat commun, les chemins autorisés, les quatre récits dans leurs widgets réels, les thèmes clair et sombre, les largeurs 360/1440, le texte à 100/200 %, la fermeture et les erreurs.
- Suite Flutter complète : 851 tests réussis ; analyse sans anomalie. Compilation web réussie en 80,5 secondes.
- Deux captures complémentaires des widgets réels avec polices et thèmes de l’application ont été relues : Documents à 360 pixels en mode sombre et à 1440 pixels en mode clair. Ce contrôle ne remplace pas une lecture physique des PDF sur le Samsung.
- APK 1.0.9+10 compilé en 96 secondes, signé avec le certificat habituel, et vérifié : les quatre PDF contenus dans le paquet sont identiques aux originaux.
- APK : EnactSpace-1.0.9-release-20261006-projets.apk ; SHA-256 : 8dd67f8d57cbb6da31d200ddd9ce67e050dc569642fd867123b2ba26dfe50cd7.
- Web et API 1.0.9 publiés. Sauvegarde préalable dans /opt/enactspace/backups/projects-20261006 ; les 111 tables sont identiques avant/après mise à jour, avec la révision 20261004_0022 conservée.
- Les quatre endpoints des fiches historiques répondent avec leurs récits et documents sous authentification ; l’accès anonyme est refusé. Les contrôles de production utilisent le rôle réellement disponible (décideur) sans création de compte ni modification de candidature.
- Les huit routes web répondent ; les quatre PDF publics ont les mêmes empreintes SHA-256 que les originaux. main.dart.js : cba6e19c8c24268fbe04fe6fd98448a682639ea20bf073078fce4425a00bd8ee.

## Essais sur le téléphone

L’APK 1.0.9+10 est installé sur le Samsung SM-A065F (Android 16), sans réinitialisation des données. La session est conservée. L’ouverture, le rendu et la fermeture des quatre dossiers ont été vérifiés en mode sombre : Aquatus, Mën Nañ et Terrasen depuis Projets, SHERY depuis Archives. Les quatre captures montrent les couvertures rendues et le début de la page suivante. Le défilement de SHERY affiche aussi les pages de présentation et de ciblage. Le retour retrouve la fiche ou l’onglet Documents.

Le bouton de téléchargement de SHERY ouvre le sélecteur d’enregistrement Android. L’annulation retrouve le PDF puis sa fiche, sans perte de navigation. Le fichier SHERY-presentation-du-projet.pdf est ensuite présent dans Download sur le Samsung : 592 544 octets, 10 pages et SHA-256 ae100d7154a46ae12da13dc9b1e6099e57faeafc9e122a14cb76632fcddc102d, identique à l’original. La vérification porte sur le fichier réellement enregistré ; l’essai instrumenté de confirmation n’est pas déclaré réussi, car le sélecteur était déjà fermé à son démarrage. Le test de recherche des archives distingue la fiche SHERY de CAJOR, dont la description mentionne également SHERY.

Neuf essais instrumentés ont réussi sur cette version : aperçu de la photo de profil et fermeture ; liste de recrutement ; ouverture d’une candidature ; historique de réception sans message technique ; fermeture de la fiche ; Academy ; bouton Continuer ; lecture d’une leçon jusqu’au contrôle final ; retour à l’accueil. Les essais ne soumettent ni candidature, ni évaluation, ni réponse de quiz et ne valident aucune leçon à la place de l’utilisateur. Ils ne constituent pas une validation physique de tous les rôles ou de tous les quiz.

Le réglage temporaire de maintien de l’écran est restauré après chaque lot. Les essais préliminaires du lecteur ont nécessité d’ajuster les sélecteurs du pilote aux filtres repliés, au texte conservé et aux onglets défilants ; ces échecs de pilotage ne sont pas comptés comme des réussites.


Le parcours complet SHERY depuis les Archives réussit ensuite : sélection exacte du projet, lecture du PDF, défilement, ouverture et annulation de l’enregistrement, fermeture du dossier, bouton Retour vers la collection puis Accueil. Le retour explicite est ainsi vérifié séparément. Un essai par la touche système Android après enregistrement est non concluant (retour au lanceur) ; il n’est pas compté comme une navigation validée.


## Correction du retour Android

Deux essais reproductibles ont montré qu’après la fermeture du PDF et un enregistrement, la touche système Android quittait l’application au lieu de retrouver la collection. La flèche Retour de l’app fonctionnait. La navigation des fiches annonce désormais sa prise en charge du retour au système et utilise le même retour vers la page précédente ou parente. Les pages principales conservent leur comportement de sortie normal.

Trois nouveaux tests couvrent la prise en charge Android d’une route imbriquée, la fermeture de la modale avant la fiche et le comportement des pages principales. Les 851 tests Flutter passent après cette correction ; analyse sans anomalie. Le web final est publié, avec sauvegarde préalable dans /opt/enactspace/backups/back-nav-20261006. Les huit routes et les quatre PDF sont de nouveau vérifiés, sans opération sur la base ni redémarrage du serveur.

Référence technique : https://docs.flutter.dev/release/breaking-changes/android-predictive-back . La validation physique du nouvel APK est consignée à la suite une fois terminée.
