# Adaptation des maquettes Postuler — 17 octobre 2026

## Référence et intégration
Adaptation des propositions mobile et web fournies par le propriétaire : accroche Tes idées. Notre énergie. Un impact ensemble., accent jaune, campagne dans le bloc d’accueil, photos réelles de la photothèque, cartes compactes. Le formulaire et le backend ne sont pas modifiés.

Une campagne ouverte : carte et bouton de démarrage dans le bloc d’accueil, avant la photo en mobile ; route exacte /recruitment/apply/:id. Plusieurs campagnes : bouton Choisir ma campagne et défilement vers une liste sans sélection automatique. Aucune campagne : annonce d’attente et suivi, sans action d’inscription. Titres, dates et descriptions viennent des données API ; aucun millésime ou indicateur Campagne de test n’est inventé.

L’accès au suivi reste unique et le retour reste dans la barre d’application. Aucun nouveau lien factice dans les cartes éditoriales. Le toucher des photos conserve l’agrandissement réel existant. Sur ordinateur, la photo principale et une photo de terrain composent le visuel ; sur mobile la photo suit la candidature. Les cartes éditoriales sont horizontales quand l’espace et la taille des caractères le permettent, sinon verticales. Le parcours explicatif et les FAQ sont conservés sans indicateur d’avancement personnel trompeur.

## Bouton mobile
Le bouton fixe apparaît uniquement après que le bouton principal a entièrement quitté le haut de la zone défilante. Il disparaît au retour et n’est jamais présent sur ordinateur, ni sans campagne. Le calcul utilise les positions réelles des éléments, pas une distance de défilement arbitraire. Le pied de page occupe son espace dans une Column sous la zone Expanded, sans superposition sur les contenus. Le contrôleur et ses écouteurs sont libérés. Les changements de largeur sont revérifiés après layout. Pour plusieurs campagnes, l’action fixe rejoint la liste ; pour une seule elle ouvre son formulaire.

## Validation
Le lot précédent a passé analyse et 60 tests sur Windows (journal du 17 octobre). Ce nouveau lot doit passer l’analyse des quatre fichiers et les tests public/landing/campaigns via tools/sync_recruitment_visual_windows.ps1. Couverture ajoutée : bouton mobile absent à l’arrivée, apparition après défilement, disparition au retour ; plusieurs campagnes restent un choix. Les tests 320/390/1200, texte 100/200 %, clair/sombre, FAQ et navigation sont maintenus et adaptés au nouveau placement. Aucun SDK Flutter n’est disponible dans l’environnement de préparation : ne pas présenter ces nouveaux tests comme déjà exécutés.

Après intégration : redémarrage Flutter avec R majuscule (changement de StatelessWidget à StatefulWidget), contrôle visuel Edge/mobile, campagne unique/multiple/vide, grands caractères et sombre. Aucun build ni déploiement dans ce lot.
