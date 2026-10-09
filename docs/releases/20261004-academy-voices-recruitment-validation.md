# EnactSpace 1.0.1 — Academy, Minutes et recrutement
Date : 4 octobre 2026 (UTC).
Dépôt : branche recovery/final-20260927. Version précédente : e74984a.

## Résultat
- Academy utilise les cours, leçons et quiz réellement persistés, avec leurs UUID et la progression de chaque membre. Les anciens liens discover-enactus / sdgs-impact et les anciennes leçons l1–l6 retrouvent les contenus correspondants.
- La première action hors connexion ne modifie plus une liste constante. Les actions en attente sont appliquées à la vue locale puis synchronisées.
- Commencer ouvre la lecture ; J’ai terminé cette leçon enregistre la progression. Relecture, fermeture et retour restent accessibles.
- 23 cours publiés, 71 leçons et 23 quiz (69 questions). Nouveaux cours : entrepreneuriat social, social business avec Muhammad Yunus, immersion, ciblage, brainstorming / idéation, design thinking, vie et transmission du club, cas Terrasen / SHERY.
- Archives : 29 Minutes, recherche par personne / thème / année, choix aléatoire, extraits conservés, défis pédagogiques et sources. Les résumés de PV et les invitations créées pour l’application sont distingués des paroles originales.
- Hommage au professeur Ndiaga NDIAYE, Faculty Advisor et mentor, dans le Hall of Fame. Aucune date de décès inventée.
- 21 photographies authentiques optimisées : quatre visuels de Minutes, portrait du professeur, distinctions 2020, MobiGel, Deconaane, Dimbali, World Cups et terrain 2025. Provenance et empreintes dans 20261004-pv-photo-provenance.json.
- Trois distinctions 2020 ajoutées : initiative MobiGel, esprit d’équipe, Team Leader Ibrahima CISSE (le visuel mentionne également Eugène NAMAR de l’UGB).
- Fiches d’archives : sections aérées, cartes, paragraphes lisibles et textes sélectionnables. Suppression du badge générique dans le détail d’archive.
- Chaque campagne peut ajouter, retirer, reformuler, réordonner les questions et choisir celles qui sont obligatoires. Le questionnaire par défaut reprend les neuf thèmes demandés, avec les disponibilités.
- Les candidatures conservent les libellés et réponses au moment de l’envoi. Une modification du questionnaire avant envoi déclenche une demande de relecture. Les vues anonymisées retirent ces réponses. Les anciens clients restent compatibles.

## Sources
34 PV de réunions du dossier doc ont été examinés, ainsi que la mémoire institutionnelle Enactus ESP fournie (28 pages). Les PDF internes ne sont pas distribués comme fichiers publics. Les synthèses retiennent les réflexions pertinentes pour la mémoire collective.
Les images proviennent de la photothèque et des dossiers de missions du club. Les originaux sont conservés.
Les premières Minutes d’Aïta Ndir DIA et Seydina TOURE proviennent des textes partagés. Le fragment de Seydina demeure un fragment ; le visuel d’Ibrahima est le volet 1/4 conservé.
Références pédagogiques primaires :
- https://www.muhammadyunus.org/post/363/seven-principles-of-social-business
- https://www.muhammadyunus.org/post/2113/social-business
- https://dschool.stanford.edu/tools/design-thinking-bootleg
Les exemples chiffrés des exercices sont fictifs et ne deviennent pas des résultats d’impact du club.

## Vérification
- Flutter analyze : No issues found.
- Suite Flutter : 677 tests réussis.
- Backend : 110 tests réussis sur Academy, recrutement, archives, photos, mémoire institutionnelle, intégrité et impact.
- Tests spécifiques : première action hors connexion, lecture et complétion, synchronisation, édition du questionnaire, conservation des réponses, version périmée, anonymisation et compatibilité.
- Archives et Minutes : 360 / 1440 px, texte 100 / 200 %. Éditeur : 390 px.
- Migration 20261004_0020 : aller / retour vérifié sur SQLite ; PostgreSQL vérifié dans une transaction annulée, puis migration appliquée.
- La commande indépendante de chargement Academy est testée dans un nouveau processus. Son second passage ne crée rien.
- Serveur : backend sain, workers en cours d’exécution ; API /health publique OK, Academy anonyme 401 et recrutement public 200.
- Base après chargement : 23 cours publiés, 71 leçons, 23 quiz, 69 questions. Deuxième passage : zéro création.

## Déploiement et restauration
Sauvegarde : /opt/enactspace/backups/academy-voices-20261004
- db-before.dump : sauvegarde PostgreSQL avant migration.
- backend-before.tgz : sources précédentes.
- Image précédente : enactspace-backend:before-academy-voices-20261004.
Image serveur active : sha256:9511ad4e9f18de366afc59947410c16c587cb5111e25fc40c4ee7c7bd1932922.
Les deux nouvelles colonnes sont nullable ; une restauration de l’image précédente n’impose pas une suppression immédiate des réponses.
Les cours et quiz préexistants modifiés par un administrateur sont préservés par le chargement.

## Android
APK : C:\Users\DIOP\Downloads\EnactSpace-1.0.1-release-20261004-academy.apk
SHA256 : D68442FDEE2A585828E6C3AB2E95D4404B9284BF64490635349BB6FD33E2B2AB
Signature APK v2 vérifiée ; sn.enactusesp.enactspace, versionName 1.0.1, versionCode 2, Android minimum 26 et cible 36.
Le téléphone n’apparaît pas dans adb devices au moment de cette livraison. Installation et contrôle biométrique physique non effectués pour cette version. Les corrections de photo de profil, retour et biométrie de la version précédente sont conservées.

## Web
Compilation réussie et publication dans /opt/enactspace/web après sauvegarde web-before.tgz.
Adresse publique : https://enactspace.kerunjombor.net/ — HTTP 200.
Archive de compilation : enactspace-web-voices.tgz
SHA256 : 87C27190C47873EF459B6B000171195D5B4E5BA4FAA0B1DE07199A1A299D28FA
main.dart.js : 8501FD9898391F33E4E54C12305B57DE173A1E471BDF86A323FF945255547B94
Empreinte identique entre compilation, serveur et téléchargement HTTPS public.
Les 21 images intégrées ont été vérifiées dans le paquet web et dans l’APK contre le manifeste de provenance.
Contrôle dans le navigateur : connexion, liste des campagnes ouvertes, première étape de candidature, retour à la liste, suivi de candidature et retour à la connexion.
Aucune candidature de test envoyée en production.
Les écrans réservés aux membres ne sont pas revérifiés dans une session authentifiée de production ; leurs parcours sont couverts par les tests automatisés.
