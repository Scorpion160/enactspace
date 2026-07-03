# EnactSpace V1 - Notes de release

Date: 2026-07-03

## Nom

EnactSpace V1

## Objectif

EnactSpace V1 est la premiere release candidate de la plateforme interne Enactus ESP. Elle centralise la vie de l'equipe: communication, membres, poles, projets, presences, finances, documents, recrutement, impact, formation, archives et reconnaissance.

## Modules disponibles

1. Dashboard adapte au role.
2. Chat interne avec conversations privees et groupes.
3. Posts et communication interne.
4. Notifications.
5. Documents et fichiers.
6. Membres et gestion des statuts.
7. Poles.
8. Projets.
9. Presences.
10. Finance.
11. Recrutement.
12. Alumni et mentorat.
13. Impact.
14. Academy.
15. Archives.
16. Hall of Fame.
17. Gamification.

## Roles disponibles

1. Administrateur.
2. Team Leader.
3. Secretaire generale.
4. Financier.
5. Chef de pole et adjoint.
6. Chef de projet et adjoint.
7. Enacteur / Enactrice.
8. Alumni.
9. Candidat.
10. Faculty Advisor.

## Etat technique

- Analyse Flutter V1: OK.
- Compilation backend V1: OK.
- Documentation V1: OK.
- Seed V1: disponible et protege.
- Permissions backend: auditees.
- Responsive global: stabilise.
- Android reel: telephone detecte par ADB, configuration reseau documentee.
- APK: commandes pretes, generation bloquee dans cette session par l'outil Flutter local.

## Limites connues

1. Push natif FCM non integre en V1.
2. QR code et NFC presence hors scope V1.
3. Mobile Money reel hors scope V1.
4. Signature Android release encore basee sur la signature debug pour usage interne.
5. Backend local necessaire pour les tests Android via IP du PC.
6. Certains tests multi-role restent manuels.
7. Deploiement production non finalise.

## Prochaines fonctionnalites prevues

1. QR code presence.
2. NFC presence.
3. Mobile Money reel.
4. Push natif FCM.
5. Deploiement production.
6. Signature Android dediee.
7. Tests automatises multi-role.
8. Parametres avances et personnalisation utilisateur.

## Documents utiles

- `docs/V1_OVERVIEW.md`
- `docs/V1_MODULES.md`
- `docs/v1_test_accounts.md`
- `docs/V1_ANDROID_TEST_NOTES.md`
- `docs/V1_ANDROID_BACKEND_CONNECTION.md`
- `docs/V1_ANDROID_BUILD_NOTES.md`
- `docs/V1_TEST_PLAN.md`
- `docs/V1_KNOWN_LIMITATIONS.md`
