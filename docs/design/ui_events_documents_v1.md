# UI Événements + Documents v1

## Architecture

Les écrans ne créent plus de services réseau. `EventsScreen` et `EventDetailScreen` utilisent un `EventsGateway` injectable, dont l’implémentation API orchestre événements, références pôle/projet, profil courant et présence. `DocumentsScreen` et `DocumentDetailScreen` utilisent de la même façon un `DocumentsGateway`, qui orchestre documents, upload et références. Les gateways mémoire permettent de tester toutes les mutations sans réseau.

## Événements

Le centre propose recherche, type et périodes À venir, Passés et Tous. Les cartes affichent uniquement les données du contrat : type humanisé, date, lieu, périmètre résolu, capacité, inscription courante et activation de la présence.

La création transporte désormais `season_id`, `pole_id` et `project_id`. Elle reste sans scope imposé pour les gestionnaires globaux. Pour un chef ou adjoint, les sélecteurs sont limités aux pôles/projets où sa responsabilité active a réellement été résolue. L’édition couvre le contrat PATCH complet, avec `can_manage` comme source de vérité pour chaque événement.

La route `/events/:eventId` supporte l’accès direct. La fiche regroupe Résumé, Inscription, Participants, Présence, Rapport et Gestion. L’état d’inscription vient de `current_user_registered`; les règles de début/capacité restent au backend. Les participants ne sont chargés qu’à la demande et uniquement lorsque `can_manage` est vrai. L’intégration Présences existante est conservée via la création d’une session liée. La suppression exige une confirmation et précise que l’événement et ses inscriptions seront supprimés.

## Documents

Le centre accepte recherche, catégorie, `status_filter`, visibilité, pôle, projet, événement, modèles et officiels. Les références sont chargées en parallèle puis mises en cache ; une source de référence en erreur est isolée et ne casse pas la liste.

Les statuts `draft`, `submitted`, `pending_validation`, `validated`, `rejected`, `archived` et `expired`, ainsi que les six visibilités, sont toujours humanisés. Après création, l’interface affiche strictement le statut renvoyé par le backend.

La route `/documents/:documentId` supporte l’accès direct. La fiche expose Résumé, Fichier, Périmètre, Validation et Métadonnées. Le téléchargement utilise le lien existant et aucune prévisualisation n’est inventée. La création exige `file_url` ou `file_id`; l’édition PATCH conserve le fichier lorsque l’utilisateur n’en choisit pas un nouveau.

Le workflow couvre Soumettre, Valider, Retirer la validation, Rejeter, Archiver et Supprimer. Les actions de gestion utilisent `can_manage`; validation, rejet, retrait et archivage utilisent `can_validate`. La validation et l’archivage sont confirmés. Le rejet exige un motif et garde le dialogue ouvert avec ses valeurs en cas d’erreur. Archivage et suppression restent des actions distinctes.

## Responsive et accessibilité

Les centres utilisent des grilles denses sur desktop et des cartes verticales sur mobile. Les filtres Documents deviennent repliables sous 700 px, les formulaires s’empilent et les fiches restent verticales. Les actions principales disposent de libellés, icônes, tooltips ou semantics explicites et de composants Material tactiles d’au moins 44 px.

## Tests

`frontend/test/events_documents_test.dart` couvre les listes, filtres, périodes, permissions de création global/pôle/projet, scopes de payload, édition Event complète, inscription, participants lazy, routes directes, mobile, contrats documentaires, fichier obligatoire/conservé, workflow, motif de rejet, expiration et humanisation. Les tests UI utilisent exclusivement des gateways mémoire ; les tests de transport utilisent un client HTTP local simulé sans requête réseau réelle.

## Limites backend

Le frontend ne fabrique aucun statut Event et ne duplique pas les règles backend d’inscription, de capacité ou de démarrage. Il ne déduit pas les permissions documentaires à partir d’un rôle local lorsque `can_manage` ou `can_validate` sont disponibles. Les noms de références non résolus restent explicitement indisponibles plutôt que d’être inventés.

## Validation visuelle finale

Les captures finales ont été produites avec un harness Flutter widget temporaire, des gateways mémoire déterministes, le vrai `ThemeData` EnactSpace et le vrai `AppShell`. Poppins a été embarquée uniquement pendant la capture et MaterialIcons a été chargée avec `FontLoader` depuis le SDK Flutter. Aucun navigateur intégré, appel réseau ou mutation applicative réelle n’a été utilisé.

Les huit vues validées sont :

- `01_events_center_desktop_1440x900.png` ;
- `02_event_detail_desktop_1366x768.png` ;
- `03_event_management_desktop_1366x768.png` ;
- `04_events_mobile_390x844.png` ;
- `05_documents_center_desktop_1440x900.png` ;
- `06_document_detail_desktop_1366x768.png` ;
- `07_document_form_desktop_1366x768.png` ;
- `08_document_workflow_mobile_390x844.png`.

Le contrôle visuel 8/8 confirme le thème EnactSpace non générique, Poppins, les glyphes MaterialIcons sans carré manquant, l’humanisation des enums, l’absence d’overflow et de loader bloqué, ainsi que la présence des états, scopes et permissions attendus. Les couleurs Material par défaut `#6750A4`, `#FEF7FF` et `#ECE6F0` ne dominent aucune capture. Le harness, le `FontLoader`, les polices et les caches temporaires ont été supprimés après génération. La trace reproductible et les SHA-256 sont consignés dans `docs/design/screenshots/ui_events_documents_v1/capture_state_results.json`.
