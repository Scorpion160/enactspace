# EnactSpace — finition recrutement et membres, fluidité Web

**Cible : 1.0.30+39.** Changement d'interface et d'optimisation sans modification de données métier.

## Recrutement
- Retrait des textes de règles et des avertissements longs de l'interface ; remplacement par des intitulés courts.
- Tranches sous 10, de 10 à moins de 15, à partir de 15 sur 20 ; accès direct à la file des dossiers sans décision.
- Champs des seuils repliés au chargement avec libellés simples, simulation d'effectifs repliée.
- Filtres existants inchangés, classement mémorisé entre les reconstructions sans changement des filtres.
- Conditions de délibération, cas d'évaluations incomplètes, confidentialité et publication ajoutés au guide `docs/recruitment/guide-espace-aide-decision.md`.

## Membres
- Même hauteur pour les cartes d'une même vue ; zones alignées (identité, badges, actions et gestion).
- Badges rôle, statut, département à géométrie uniforme, texte à largeur maîtrisée.
- Titres et e-mails longs accessibles au survol ou au toucher avec défilement doux ; libellé intégral aussi dans l'infobulle.
- Liste initiale limitée à 24 cartes, puis bouton « Afficher d'autres membres » par groupes de 24. La recherche, les filtres et les commandes sont conservés.
- Vérification des cartes avec textes longs, thème sombre, petit écran et zoom texte 200 %.

## Diagnostic de latence

- VPS vérifié sans saturation mémoire/CPU au moment du contrôle (charge ~0,6 ; mémoire disponible ~8,7 Gio).
- Requêtes HTTPS de santé de l'API : autour de 330 ms depuis le poste client (trois mesures ; ne mesure pas les pages authentifiées).
- Le fichier `main.dart.js` de la version +38 pèse ~6,65 Mo. Le front est compressé en Brotli par le chemin HTTPS public.
- Cause identifiée des rechargements inutiles : `Cache-Control: no-cache, no-store, must-revalidate` interdisait toute conservation navigateur.
- Correction Nginx appliquée indépendamment de la nouvelle interface, sur `/main.dart.js` uniquement : `private, no-cache, must-revalidate`, ETag disponible. Le CDN Cloudflare répond `BYPASS`, et une requête conditionnelle avec `If-Modified-Since` renvoie HTTP 304. L'HTML, le bootstrap et `version.json` conservent leur politique stricte. Fichier d'origine sauvegardé sur VPS.
- Cela réduit le trafic sur les rechargements dont le code n'a pas changé ; une mesure réelle de navigation et de rendu Flutter, sur un navigateur authentifié, reste nécessaire pour chiffrer le gain.

## Recette et publication

Tests de composants Flutter, contrôles visuels, modes clair/sombre, zoom et analyse statique avant publication. La CI vérifie les scénarios recrutement/membres et construit une archive Web signée par empreinte.

La publication de 1.0.30+39 doit préserver les services API et la base : ce lot est essentiellement Web (le correctif Nginx étant déjà chargé sur le VPS). Ne pas envoyer d'e-mails aux candidats ni publier de décisions automatiquement.

La version publique précédente est 1.0.30+38, et la configuration Nginx antérieure à la correction de cache est sauvegardée sur le serveur.
