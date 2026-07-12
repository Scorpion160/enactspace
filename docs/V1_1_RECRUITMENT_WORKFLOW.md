# EnactSpace V1.1 - Recrutement public

## Objectif

Cette tranche prépare le parcours public de candidature sans ouvrir l'espace interne EnactSpace aux candidats.

## Parcours candidat

1. Le candidat ouvre `Rejoindre Enactus ESP` depuis l'écran de connexion.
2. L'application charge uniquement les campagnes publiques ouvertes.
3. Le candidat remplit le formulaire public.
4. Le backend crée la candidature avec le statut `submitted`.
5. Un code de suivi lisible est généré au format `ESP-AAAA-XXXXXXXX`.
6. Le candidat conserve ce code avec son email pour consulter son suivi.

## Données collectées

Le formulaire couvre l'identité, le contact, le parcours académique, le pôle souhaité, le projet d'intérêt, la motivation, les compétences, l'expérience associative, la disponibilité, les commentaires et les liens de pièces jointes optionnelles.

## Accès interne

Un candidat en statut `submitted`, `under_review`, `interview_scheduled`, `waiting_list`, `rejected` ou `cancelled` ne reçoit aucun accès aux modules internes. La conversion en membre reste une action interne explicite.

## Notifications

Chaque nouvelle candidature crée une notification interne pour les rôles recrutement autorisés. L'envoi email candidat est préparé côté configuration avec `EMAIL_ENABLED` et `SMTP_HOST`, sans appel réseau forcé dans cette tranche.

## Confidentialité

Le suivi public affiche seulement les informations utiles au candidat. Les notes internes, scores et avis restent absents du suivi public.

## Suivi candidature

Le portail public accepte le code `ESP-AAAA-XXXXXXXX` et reste compatible avec les anciennes références UUID. Il affiche le statut, la date de soumission, la dernière mise à jour, la prochaine étape, les informations publiques d'entretien si disponibles et le résultat final lorsque la décision est terminée.

## Évaluation et sélection

La liste interne des candidatures peut être filtrée par campagne, statut, recherche, genre, pôle souhaité, projet d'intérêt, département et classe. Les évaluateurs autorisés peuvent ajouter un score sur 20, une note interne et un avis `favorable`, `reserve` ou `defavorable`.

## Entretiens

Les responsables recrutement peuvent programmer un entretien depuis une carte candidat avec date, heure, lieu, lien visio, jury et note interne. La programmation passe automatiquement la candidature en `interview_scheduled`. Le suivi public affiche uniquement la date, le lieu et le lien, jamais la note interne.
