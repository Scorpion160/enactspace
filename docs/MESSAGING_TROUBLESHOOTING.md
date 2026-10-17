# Diagnostic mails, première connexion et push

## Interpréter les résultats

Les paramètres actuels activent les mails et push sans redirection de test. L’adresse institutionnelle est enactus@esp.sn. Le statut email_deliveries.sent signifie que le transport a accepté l’envoi selon le worker; il ne prouve pas la présence dans la boîte du destinataire. L’absence dans le dossier « Envoyés » n’est pas non plus une preuve de non-envoi SMTP.

Une notification de changement de responsabilités n’est pas un mail d’activation. Vérifier le sujet, le type de parcours, le compte et l’existence d’un challenge avant de conclure qu’un code a été envoyé.

## Ordre de diagnostic

1. Confirmer l’adresse du compte, son statut, son activation et le parcours choisi. Ne jamais imprimer le mot de passe ou le code.
2. Contrôler en lecture seule les métadonnées des activation_challenges : création, expiration, tentatives et correspondance de l’adresse; ne pas lire le code ou son hash pour les transmettre.
3. Contrôler les métadonnées des email_deliveries : sujet, destinataire autorisé, statut, nombre de tentatives, dates, code d’erreur et Message-ID. Masquer les contenus privés dans un compte rendu.
4. Vérifier que le worker est actif, sa configuration effective et la redirection. Des identifiants présents ne suffisent pas à valider le transport.
5. Si sent, rechercher côté destinataire dans spam/quarantaine et faire tracer le Message-ID par l’administrateur messagerie si nécessaire. Examiner les rejets/bounces sans publier de secrets.
6. Si aucun challenge ni mail d’activation, examiner la politique d’éligibilité avant de retenter. Respecter les délais et limites du service; ne pas fabriquer de challenge ou modifier directement le mot de passe.

Dans l’incident Mariama, aucun challenge n’existait et le mail observé portait sur ses responsabilités. Le correctif ciblé permet la première activation sans retirer son rôle administratrice, uniquement sous les conditions décrites dans [Première connexion](FIRST_ACCESS_ONBOARDING.md). La réception réelle du nouveau code n’a pas encore été attestée.

## Validation sans émission massive

Demander un nouveau code depuis le parcours normal avec le destinataire concerné, puis confirmer réception, validation et connexion. Ne pas rejouer toutes les livraisons historiques ni réactiver les messages de test. Conserver les preuves sans code, token ou corps de message.

Pour les push, vérifier permission navigateur/Android, token enregistré pour le bon compte, worker et résultat fournisseur, réception en premier plan/arrière-plan puis déconnexion. Un ancien push sent ou dead ne permet pas de conclure au bon fonctionnement général. Les restrictions Firebase et la recette multi-appareils restent à confirmer.
