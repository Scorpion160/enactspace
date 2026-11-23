# EnactMeet — Invitation de participants externes par e-mail

## Parcours
1. Un hôte/cohôte habilité ouvre une réunion EnactMeet ordinaire (club, pôle, projet ou sur invitation).
2. Cliquer sur **Inviter un externe**, saisir l'adresse e-mail (nom facultatif), puis confirmer **Envoyer l'invitation**.
3. L'e-mail institutionnel `enactus@esp.sn` contient un lien personnel vers l'API EnactSpace. L'invité n'a **pas besoin d'un compte EnactSpace**.
4. Le lien n'est utilisable que tant que la réunion est active, l'invitation valable et non révoquée. Une fois l'hôte en réunion, ouvrir le lien redirige vers la salle Jitsi et fournit un JWT **participant**, limité à une seule salle.
5. Le modérateur admet l'invité dans le lobby. L'organisateur peut suivre le statut d'envoi dans **Invités externes** et révoquer le lien.

## Garde-fous
- Jeton aléatoire de 256 bits ; **seul son hachage SHA-256** est stocké dans `meeting_guest_invitations`. Le lien lui-même est envoyé dans l'outbox institutionnelle.
- Accès externe à **une réunion uniquement**, jamais aux pages/données EnactSpace ni aux droits de modérateur.
- Autorisation hôte/cohôte requise pour inviter, voir et révoquer ; pas d'invitation externe depuis les réunions de recrutement gérées séparément.
- Expiration au plus tard 90 jours après l'invitation ; l'e-mail ne part que sur action explicite ; même adresse active non réinvitable avant révocation.
- Lobby obligatoire durant la validité d'une invitation. Toute tentative de désactiver le lobby via les paramètres de réunion est rejetée.
- Révocation des liens et annulation des e-mails encore en attente d'envoi.
- La révocation bloque **les prochaines entrées**. Une session Jitsi déjà authentifiée n'est pas interrompue automatiquement : le modérateur doit expulser la personne si elle est déjà présente.
- Un lien personnel est un **jeton porteur** : une personne à qui il est transféré peut essayer de l'utiliser ; garder le lobby et vérifier les invités.
- Le jeton Jitsi réémis à chaque ouverture du lien a une validité plafonnée à 60 minutes (et par la durée maximale configurée pour les jetons EnactMeet). Il peut être renouvelé en rouvrant le lien.

## Déploiement
1. Intégrer les commits à la branche de production réellement utilisée.
2. Exécuter `alembic upgrade head` dans l'environnement backend (migration `20261123_0041`).
3. Vérifier `MEET_REQUIRE_JWT=true`, `MEET_JWT_APP_ID`, `MEET_JWT_SECRET`, `MEET_JWT_SUBJECT`, `PUBLIC_API_BASE_URL=https://api.enactspace.kerunjombor.net` et l'envoi SMTP institutionnel.
4. Déployer le backend et le web ensemble.
5. Effectuer un test avec une adresse externe autorisée : invitation, réception e-mail, entrée avec lobby, déconnexion/reconnexion, révocation, tentative de réentrée refusée et statut d'envoi.
6. Vérifier que les journaux d'accès HTTP ne conservent pas les jetons d'invitation en clair dans les URLs.

## API
- `GET /api/meetings/{meeting_id}/guests` — liste des invitations, organisateurs uniquement
- `POST /api/meetings/{meeting_id}/guests` — e-mail, nom facultatif
- `DELETE /api/meetings/{meeting_id}/guests/{guest_id}` — révocation
- `GET /api/meetings/guests/join/{token}` — entrée externe publique à jeton, redirection Jitsi quand la réunion est en direct

Aucune invitation n'a été réellement envoyée lors du développement de cette fonctionnalité.
