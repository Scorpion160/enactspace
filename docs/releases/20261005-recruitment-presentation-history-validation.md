# EnactSpace 1.0.6+7 — Recrutement
Date : 5 octobre 2026.

La liste des candidatures et les fiches détaillées restent lisibles en mode clair et sombre, sur téléphone, tablette et ordinateur. Le formulaire ne demande plus de pôle ni de projet préféré et recueille la manière dont le candidat a connu Enactus ESP. L’équipe recrutement dispose désormais d’un historique daté des changements réellement enregistrés.

## Comportement
- Sept badges de statut avec contraste vérifié : reçue, étude, entretien, retenue, non retenue, attente, clôturée.
- Colonnes Évaluation et Documents séparées ; liste sous forme de cartes lorsque la largeur ou la taille du texte l’exige.
- Fiche : en-tête aéré, bouton de fermeture accessible, informations sur une ou deux colonnes selon la largeur, réponses et documents mieux espacés.
- Nouvelle question « Comment as-tu connu Enactus ESP ? ». Réponse conservée après un échec de soumission. Pas de doublon si le questionnaire de campagne possède déjà cette question.
- Anciennes réponses de préférence conservées dans les dossiers historiques. Affectations internes aux équipes après sélection toujours disponibles.
- Historique privé : réception initiale, changements de statut, entretien ou report, intégration du membre, date/heure et auteur lisible.
- Utilise les événements existants du journal d’audit ; aucune transition passée non enregistrée n’est inventée. Aucun changement de schéma ou remplissage artificiel.
- Évaluations : nom du membre du jury à la place d’une référence technique.
- Lecture anonymisée demandée au serveur ; identité, réponses libres et pièces jointes masquées selon le contrat de lecture anonymisée.
- Messages destinés aux utilisateurs reformulés. Les erreurs techniques du recrutement deviennent des indications humaines et contextualisées. Nettoyage des mentions techniques signalées dans Academy, Alumni et Documents.
- Les actions de sélection restent réservées aux personnes autorisées ; aucune modification de candidature réelle n’a servi aux tests.

## Validation
- Analyse Flutter : aucune anomalie.
- Tests Flutter ciblés : 130 réussis.
- Suite Flutter complète : 779 réussis.
- Huit rendus supplémentaires de listes et fiches sur 390 et 1600 pixels, en clair et sombre, générés sur données fictives ; contrôle visuel effectué.
- Tests de liste : quatre largeurs (360, 768, 1366, 1600), taille normale et agrandie à 200 %, clair et sombre.
- Contraste des sept badges : ratio minimal 4,5:1.
- Backend ciblé : 47 tests réussis.
- Backend complet sur SQLite : 429 tests découverts, 340 exécutés avec succès, 89 ignorés (cas PostgreSQL).
- PostgreSQL isolé : 36 parcours recrutement/pièces jointes + 52 tests de régression réussis.
- Parcours : réception, changements valides/invalides, répétitions sans doublon, entretien et report, lecture anonymisée, accès interdits, confidentialité du journal, conversion idempotente et évaluateur nommé.
- Vérification de production en lecture seule : version, accès protégés, campagnes publiques, droits du rôle présent, historique des dossiers et lecture anonymisée.
- Version publique web/API : 1.0.6 ; web build 7. Empreinte du JavaScript publié identique à la compilation.
- Services backend, e-mail, push et Veille en fonctionnement, zéro redémarrage constaté après publication.
- Sauvegarde privée avant déploiement ; comparaison des 111 tables confirmant la conservation des données lors de la mise à jour.
- Un contrôle de publication conservait initialement le numéro de build 6 au lieu de 7. Retour automatique à la version précédente, correction du contrôle, puis publication et vérification réussies.

## Livrables
- Web : https://enactspace.kerunjombor.net/
- API : https://api-enactspace.kerunjombor.net/
- APK : C:\Users\DIOP\Downloads\EnactSpace-1.0.6-release-20261005-recrutement.apk
- APK : 240553474 octets, package sn.enactusesp.enactspace, versionCode 7.
- SHA-256 APK : a4da699f8a2738ea01085aae5239e0345316f083568608f5450ae675670eb1c6
- Certificat Android conservé : 38e8274a7b63174cbf06f5d5b15e68b623fdb9fae92538ad9b7f470611e484d5
- JavaScript web SHA-256 : 327cc817aaa07424635255c7bbf0f7d0de99d4a201d16ed6410935394f366319
- Image backend : enactspace-backend:recruitment-20261005 (4b9bb5b4b6ec44aeb35a1694ef30091ee9be858619545ff0c3784e62582bf7b8).
- Révision Alembic conservée : 20261004_0022.

## Limites de validation
Aucun téléphone connecté à ADB au moment de cette publication : APK signé et compilé, mais cette version n’a pas été installée ni manipulée sur le Samsung physique. Les tests automatisés, les rendus Flutter et les contrôles serveur ne remplacent pas ce dernier contrôle matériel. Aucune candidature réelle acceptée, rejetée ou convertie, et aucune nouvelle campagne créée pour les besoins de cette validation.
