# Lot 33 — périmètre de lancement et Academy
Date : 9 octobre 2026.

## Décision utilisateur
PayDunya est reporté à une phase ultérieure. Les essais sandbox PayDunya et l’activation du checkout ne sont plus des conditions de la première mise en service. Le lancement doit conserver MOBILE_MONEY_ENABLED=false et proposer la déclaration manuelle avec reçu et validation financière. Ce lot n’a pas lu ou modifié la configuration du VPS ; le contrôle de ce paramètre et de la présentation des actions en Android/web reste requis dans la recette finale.

## Academy et aide
49 tests réussis en 16,892 secondes pour test_academy_operational, test_academy_progression, test_academy_curriculum, test_academy_quiz_idempotency et test_prelaunch_help_boundaries. Base SQLite isolée, fournisseurs désactivés, aucun message ou paiement réel.

Le premier passage avait une seule assertion échouée : le test d’archives exigeait exactement 29 Minutes de l’enacteur tandis que le catalogue enrichi en contient 43. Cette assertion impose désormais la conservation d’au moins 29 entrées ; elle ne bloque plus un enrichissement. Les contrôles existants d’unicité des identifiants, des dates 2020 des six premières contributions et de l’absence de date inventée pour l’hommage sont conservés. Aucun contenu n’a été retiré pour satisfaire le test.

Les 49 tests passent après correction. Un avertissement SQLAlchemy sur le nettoyage des tables attendance_records/fees reste présent sans échec. Pas de modification du parcours utilisateur par ce lot. Les essais Flutter et la recette sur téléphone restent ouverts, notamment quiz, illustrations, progression et hors connexion.

Aucun build, déploiement ni changement de production.
