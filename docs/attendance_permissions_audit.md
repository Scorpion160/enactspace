# Audit permissions Presences / Retards / Absences

Date: 2026-07-02

## Perimetre audite

- Backend: `backend/app/api/routes/attendance.py`
- Backend: `backend/app/models/attendance.py`
- Backend: `backend/app/schemas/attendance.py`
- Frontend: `frontend/lib/features/attendance/screens/attendance_screen.dart`
- Frontend: `frontend/lib/features/attendance/screens/attendance_session_detail_screen.dart`
- Frontend: `frontend/lib/features/attendance/services/attendance_service.dart`

## Synthese

Le module Presences est protege par `get_current_active_validated_user`. Les candidats et comptes non valides ne peuvent donc pas acceder au module interne.

Les actions sensibles sont controlees cote backend. Le frontend facilite l'experience et masque les actions selon le contexte, mais le backend reste la source de verite.

## Membre simple

- Voit ses propres pointages via `/attendance/my-records`.
- Peut soumettre une justification uniquement pour ses propres absences.
- Ne peut pas voir les records des autres membres dans les rapports/statistiques.
- Ne peut pas creer, ouvrir, modifier ou cloturer une seance.
- Ne peut pas valider/refuser une justification.
- Ne peut pas modifier les parametres de sanctions.

## Chef de pole

- Peut gerer les seances rattachees a son pole actif.
- Peut voir les records et rapports limites a son perimetre.
- Peut ajouter des membres attendus dans son perimetre.
- Peut valider/refuser les justifications des seances qu'il gere.
- Ne voit pas les finances globales hors sanctions liees aux records accessibles.

## Chef de projet

- Peut gerer les seances rattachees a son projet actif.
- Peut voir les records et rapports limites a son projet.
- Peut valider/refuser les justifications des seances qu'il gere.
- Ne voit pas les donnees globales du club.

## SG, Team Leader et Admin

- Peuvent creer des seances club, pole, projet ou groupe.
- Peuvent ouvrir, cloturer et modifier les seances.
- Peuvent voir les statistiques globales et rapports mensuels.
- Peuvent exporter le rapport mensuel.
- Peuvent modifier les parametres de sanctions.
- Peuvent valider/refuser les justifications.

## Alumni

- Les alumni sont exclus des requetes internes de sessions/records/rapports.
- Ils ne voient pas les presences internes.
- Ils ne peuvent pas justifier ou gerer les absences internes.

## Finance

- Les sanctions sont creees dans `fees` avec `related_attendance_id`.
- Une ligne de presence ne genere pas deux fois la meme sanction.
- Une justification en attente ou approuvee retire la sanction non payee liee.
- Le montant vient de `attendance_settings`, pas d'une valeur figee dans la logique metier.

## Responsive

- La liste des seances reste en cartes.
- Le pointage utilise des cartes membres et des boutons rapides.
- Les chips longs sont tronques avec `maxLines` et `ellipsis`.
- Les statistiques utilisent des grilles responsive.
- Les tableaux larges sont evites sur mobile.

## Limites connues

- La piece jointe de justification est prise en charge par les champs backend `file_id` et `file_url`; l'upload direct depuis le formulaire Flutter pourra etre branche sur `FileStorageService`.
- Le QR code et le NFC ne sont pas traites dans cette tranche.
- L'export est disponible cote backend en CSV; un bouton de telechargement dedie pourra etre ajoute dans une tranche UX export.

## Validation

- `flutter analyze --no-pub`: OK
- `python -m compileall backend/app`: OK
- `git diff --check`: OK
