# EnactSpace 1.0.5+6 — pièces jointes, équipes et recrutement

## Fonctionnement livré

Les preuves des tâches sont désormais des fichiers joints. Une tâche reste la même dans Tâches et dans Veille : les changements de statut, les retours et la preuve sont enregistrés sur le même objet. Le membre affecté commence le travail puis le remet ; « Terminé · à valider » distingue la remise de l’acceptation. La personne qui a confié la tâche valide ou demande une reprise. Le Team Leader et l’administration peuvent assurer un relais, sans accepter leur propre travail. Après un changement de personne ayant confié la tâche, l’ancien créateur ne conserve pas automatiquement le droit de validation.

Les pièces jointes remplacent les liens à saisir dans les preuves, les comptes rendus d’événements, les justificatifs d’absence, les dossiers de candidature et les indicateurs ou preuves d’impact. Les images s’ouvrent dans un aperçu agrandissable ; les autres fichiers peuvent être enregistrés avec leur nom et extension. Les anciens liens restent consultables. Les téléchargements internes exigent une authentification et un droit sur le dossier concerné ; ils ne deviennent pas publics parce que le fichier a été téléversé par la personne qui tente de le lire.

Les fichiers opérationnels sont limités à 20 Mio, et les pièces d’une candidature à 10 Mio chacune. Les formats autorisés, la taille, les signatures de fichiers et la structure des documents Office sont contrôlés. Les fichiers exécutables et HTML sont refusés. Ces contrôles ne constituent pas une analyse antivirus.

Le recrutement public présente des photographies réelles du club et un parcours de candidature en six étapes. Le candidat joint son CV, sa lettre et, s’il le souhaite, un complément. Les fichiers sélectionnés restent disponibles lors des retours entre étapes et après un échec d’envoi. Le questionnaire reste configurable pour chaque campagne, avec réponses obligatoires, version du questionnaire et photographie des questions au moment de la candidature. Les anciens clients utilisant les champs historiques restent compatibles ; une nouvelle question obligatoire sans équivalent historique ne peut pas être ignorée. Une campagne fermée refuse les candidatures. Les dates et la publication de la nouvelle campagne restent à renseigner par les responsables ; aucune campagne fictive n’est publiée.

Les pôles et projets disposent de cartes adaptées à la largeur de l’écran. Leurs fiches regroupent des accès aux tâches, engagements, blocages, bilans, documents et événements, filtrés sur l’équipe correspondante. L’espace Veille transversal reste accessible dans la navigation générale. Les membres actifs peuvent consulter les fiches des équipes ; les boutons et écritures de gestion conservent leurs permissions.

Le mot « année » désigne l’année du club. Les saisons agricoles conservent leur sens dans les leçons et l’histoire des projets. EnacChef désigne le Team Leader, le secrétariat général, le financier, les chefs de pôle et de projet et leurs adjoints. Le Faculty Advisor n’acquiert pas automatiquement ce statut.

## Accès selon la personne

| Personne | Fonctionnement |
| --- | --- |
| Enacteur ou enactrice | Consulte les équipes, retrouve ses tâches et engagements, commence et remet son travail avec preuve, signale un blocage et justifie ses absences. Ne valide pas son propre livrable. |
| Chef de pôle ou de projet et adjoint | Utilise les outils filtrés sur son équipe, suit ses membres et les tâches de son périmètre. La validation suit la personne ayant confié le travail, avec les relais explicites de direction. |
| Pôle Veille | Suit les activités et les indicateurs transversaux selon ses droits. Consulte les mêmes tâches que le centre Tâches. L’appartenance active au véritable Pôle Veille est reconnue pour le recrutement. |
| EnacChef | Dispose des outils correspondant à sa responsabilité. L’appartenance à EnacChef seule n’ouvre pas systématiquement les candidatures confidentielles. |
| Team Leader et administration | Gèrent les habilitations et disposent des relais de validation. Préparent et examinent les transitions alumni avant confirmation. |
| Faculty Advisor | Consulte les équipes s’il est membre actif. Son seul rôle ne donne pas les permissions internes d’EnacChef ou du recrutement. |
| Alumni | Conserve son profil et l’histoire de ses activités ; ne continue pas à effectuer les mutations réservées aux membres actifs. Les rôles et appartenances actifs sont retirés lors de la transition, sans effacer les traces historiques. |
| Postulant | Parcourt la présentation du club, répond au questionnaire de la campagne, joint ses fichiers et retrouve le suivi de candidature. Ses documents restent confidentiels. |

## Outils d’équipe et suite du travail

Les outils communs sont livrés et utilisent les mêmes tâches, documents, événements et données Veille. Ils ne créent pas une seconde liste de travaux indépendante.

| Équipe | Usage des outils livrés | Évolution spécifique à cadrer |
| --- | --- | --- |
| Veille | Engagements, échéances, remises, blocages, bilans et dossiers selon les habilitations | Ajustement des indicateurs et règles adoptées par le club |
| Secrétariat général | Documents, comptes rendus, événements et passation | Modèles de procès-verbal et décisions reliées aux réunions |
| Finance | Tâches, documents et suivi existant des contributions ou mesures financières | Budgets d’équipe, demandes de dépense et rapprochement des justificatifs |
| Communication | Tâches, événements, documents et livrables visuels | Calendrier éditorial et circuit de relecture des publications |
| Projets | Tâches, engagements, blocages, documents, événements et impact selon les droits | Suivi des entretiens terrain, expérimentations et bénéficiaires avec leurs règles de confidentialité |
| Autres pôles | Même espace de travail filtré sur le pôle | Fonctions propres définies à partir de la mission réelle de chaque pôle |

Ces évolutions spécifiques sont des propositions, pas des modules annoncés comme déjà livrés.

## Vérifications et livraison

- Flutter : 759 tests réussis dans la suite complète. Analyse finale sans anomalie. Affichage contrôlé à 360, 768 et 1 440 px, avec thèmes clair et sombre et caractères agrandis.
- Backend SQLite final : 411 tests recensés, 331 réussis et 80 ignorés selon leur configuration.
- PostgreSQL : 72 parcours Veille et pièces jointes réussis sur l’image finale ; 52 régressions des autres modules et un contrôle Academy complémentaire réussis. Bases et fichiers de test isolés, email et push désactivés.
- Les scénarios couvrent la remise et la validation, le changement de personne ayant confié le travail, la reprise, les notifications sans doublons, les références de fichiers d’un autre dossier, les téléchargements et suppressions interdits, les formats et tailles, les dossiers de candidature, les questionnaires historiques, les justificatifs, les comptes rendus, Impact et la transition alumni.
- Diff Git contrôlé sans erreur de whitespace. Les sources sont comparées à leur empreinte après les tests pour détecter un changement concurrent.
- Web publié : version 1.0.5, build 6. API publique : version 1.0.5. JavaScript public identique au build validé : `3433f9f317af27c128b97b05d9050c779b4e0e2be2eb7173f4b13e2f39c8da49`.
- Archive web : `a2cc01b0da3cd96ce998a4e739187a510701ba8b308cfac1beaf7b89b84eec10`.
- Image serveur : `enactspace-backend:attachments-20261005`, SHA-256 `fe9a2b0339e887d6624ea1bdc8eb7ff5b79b5d44354c362f6d319cb1646fdb55`, également marquée `enactspace-backend:local`.
- Base inchangée par le changement d’exécutables : empreintes des 111 tables identiques avant le redémarrage. Révision conservée : `20261004_0022`. Aucune nouvelle migration n’est nécessaire.
- Lectures authentifiées de production réussies pour le profil décisionnaire disponible : Veille, profil, tâches, pôles et projets. Les autres profils sont vérifiés dans les bases isolées. Aucun compte de test créé en production.
- Web, backend et PostgreSQL en bonne santé ; travailleurs email, push et Veille actifs, sans redémarrage observé. Les endpoints privés renvoient 401 sans authentification ; le JavaScript est servi sans cache.
- Présentation du recrutement vérifiée visuellement dans le navigateur, avec les quatre photos réelles, le lien direct `https://enactspace.kerunjombor.net/#/recruitment/apply`, le suivi de candidature et son bouton de retour. Le web utilise les routes Flutter avec un fragment `#/`.
- Sauvegarde privée : `/opt/enactspace/backups/attachments-20261005`. Dump PostgreSQL contrôlé avec `pg_restore --list`, empreinte `e5f040985299b18d3d0090b9f442949e50305c4e790e407e874b4c378f892daf`. Sources : `bbfedb17edbe0420205e557d464e6b5d80c38cbf1ac17e1bde3bbe305567497c`. Ancien web : `4b213096d92e598eb29d59557b90e81112eab2e9eb463ca10baa62e5f5af10fe`.
- Retour possible aux exécutables `enactspace-backend:veille-20261004`, au Compose et au web sauvegardés. Ne pas restaurer automatiquement la base : elle peut contenir de nouvelles activités depuis la livraison.
- Android release compilé et signature vérifiée : `sn.enactusesp.enactspace`, version 1.0.5, code 6, architectures arm64-v8a, armeabi-v7a et x86_64. Fichier `C:\Users\DIOP\Downloads\EnactSpace-1.0.5-release-20261005-equipes.apk`, 240 537 090 octets. SHA-256 : `4ca5d63bf7b5bc42b01fc444dc17a31c58239352804135a67d3403fa98520193`. Certificat identique à la version précédente : `38e8274a7b63174cbf06f5d5b15e68b623fdb9fae92538ad9b7f470611e484d5`.

## Limites des essais

Les transitions alumni et les écritures des parcours sont testées sur des bases isolées. Aucun membre réel n’est converti, aucune sanction ou règle disciplinaire n’est ajoutée pendant ces essais. Les contrôles authentifiés de production restent des lectures.

Le suivi repose sur le code communiqué après la candidature et envoyé par email. La récupération automatique d’un code perdu n’est pas disponible ; elle reste une évolution à prévoir.

Aucun téléphone Android physique n’est connecté à ADB. Les compilations et les tests ne remplacent pas un essai sur téléphone pour la biométrie, le sélecteur natif de fichiers ou les téléchargements. Aucun push Git n’est effectué. La sauvegarde préexistante `email_worker.py.before-model-registration-fix` reste exclue du commit et du paquet serveur.
