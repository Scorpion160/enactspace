# Documents institutionnels : corrections du 11 octobre 2026

État : sources corrigées, compilation client et déploiement à effectuer. Cette note ne déclare pas ces corrections déjà actives en production.

## Brouillon et aperçu

1. Créer le brouillon depuis Documents → Créer un document.
2. Dans Demandes, télécharger l'aperçu marqué BROUILLON — NON OFFICIEL.
3. Utiliser Modifier sur **la même demande** : les champs, sélections et rattachements enregistrés sont rechargés.
4. Modifier uniquement les informations nécessaires puis enregistrer. Les champs anciens et les listes structurées inchangées sont conservés sans conversion destructive.
5. En cas d'erreur réseau à l'enregistrement, rouvrir Modifier : les modifications non enregistrées sont conservées dans la vue courante. Elles ne sont pas un stockage durable et disparaissent si l'application est fermée ou la vue recréée.
6. Soumettre après vérification. La modification est bloquée pendant la validation ; une demande rejetée peut être corrigée puis soumise de nouveau.

## Contrôles et validation

Les règles de périmètre restent applicables : pôles/projets, SG, Team Leader et Veille pour le renvoi. L'administration ne remplace pas automatiquement un validateur SG ou TL. L'auteur ne se valide pas lui-même ; le validateur SG ne peut pas aussi approuver avec une deuxième fonction TL.

Les champs obligatoires vides, nombres non finis/négatifs, effectifs non entiers ou nuls, dates invalides et retours antérieurs au départ sont refusés à la soumission. Les champs textuels des huit modèles sont couverts par un test de présence dans les données LaTeX. Les notes internes du renvoi sont exclues de la lettre destinée au membre, tout en restant enregistrées dans la demande restreinte. Une absence sans précision n'est plus qualifiée automatiquement d'excusée.

## PDF officiel et conservation

La génération verrouille la demande en base jusqu'à la fin de la transaction pour sérialiser deux générations simultanées. Ce verrou nécessite PostgreSQL en production ; les tests SQLite ne démontrent pas la concurrence PostgreSQL.

Le PDF généré et son fichier associé sont protégés contre les actions génériques de modification, validation/retrait de validation, rejet, archivage et suppression, y compris pour l'auteur et les responsables globaux. Une correction officielle nécessite une **nouvelle demande** ; l'original et sa référence doivent rester conservés.

La validation applicative n'est pas une signature électronique. Après génération : télécharger, recueillir les signatures requises (notamment parent/représentant légal), puis remettre le document au destinataire. Il n'y a aucun envoi automatique externe ni confirmation de réception. Les documents privés restent accessibles selon les règles existantes, sans partage automatique au membre cité dans le formulaire.

## Vérification avant publication

- Backend isolé : `python -m unittest test_institutional_documents test_institutional_pdf_generation test_institutional_pdf_preview test_institutional_document_integrity`.
- Les tests utilisent SQLite en mémoire et ne déclenchent aucune sanction réelle. Ne jamais les exécuter contre une base de production.
- Les compilations PDF exigent pdflatex, Babel français et les packages du modèle. Un moteur installé sans ces dépendances doit produire une erreur, jamais un succès prétendu.
- Frontend : analyser les deux fichiers modifiés et exécuter `test/institutional_documents_test.dart`, `test/institutional_documents_service_test.dart`, `test/institutional_draft_edit_test.dart`.
- Recette web et Android : créer → enregistrer → aperçu → modifier un champ → vérifier tous les autres → enregistrer → aperçu → validations avec comptes distincts → génération → ouverture/téléchargement.
- Vérifier un appel simultané de génération sur PostgreSQL dans un environnement de recette isolé : même document et même référence, un seul fichier officiel.
- Tester un échec réseau d'enregistrement, puis rouvrir Modifier sans quitter la vue.
- Contrôler visuellement les huit PDF et les signatures avant leur transmission.
