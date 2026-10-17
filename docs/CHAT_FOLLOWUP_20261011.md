# Discussions, GIF et contrôle du chat — 11 octobre 2026

Base : cbaf02260f304feb950926fb94ef437e838b8762. Les changements restent dans les sources tant qu'un build frontend et un déploiement backend ne sont pas effectués.

## Comportement corrigé
- La création d'une discussion privée ne produit aucune notification. Chez le destinataire, elle apparaît seulement après l'envoi du premier message ; chez son créateur, le brouillon de conversation reste disponible.
- La création d'un groupe et l'ajout d'un membre notifient la personne ajoutée, en indiquant l'auteur et le groupe. Un groupe sans message figure dans la liste dès l'ajout. L'écran chat recharge la liste via sa synchronisation existante (au plus 12 secondes lorsqu'il est ouvert), et lors de l'ouverture du chat.
- Une discussion privée reste entre deux personnes ; l'API refuse l'ajout d'un troisième participant. L'interface réservait déjà l'ajout aux groupes.
- Quarante GIF animés originaux de réactions et de messages d'équipe sont intégrés : salutations, remerciements, humour et motivation. Recherche par libellé/catégorie et import personnel conservé. Les GIF sont envoyés par la même API privée que les photos, pas par un lien externe. Aucun service externe ni clé supplémentaire.
- Le réglage Téléchargement auto est respecté pour les photos et GIF jusqu'à 10 Mo ; les autres pièces jointes restent à télécharger à la demande. L'échec conserve le bouton Réessayer.
- Les réactions proposées correspondent désormais aux six réactions acceptées par le serveur.
- Les quatre imports relatifs du test de pièces jointes sont remplacés par des imports package.

## Audit des fonctions existantes
Le chat contient déjà la liste et la recherche des conversations, les indicateurs non lus, présence et saisie, les messages vocaux, réponses, réactions, épinglage, suppression locale, réessai d'envoi et cache local. Les nouveaux lecteurs couvrent photos, GIF, PDF et vidéos, avec téléchargement des autres documents. Les emails de messages, sondages et réactions ne contiennent plus de contenu privé dans le correctif précédent.

## Améliorations restant à concevoir et vérifier
- Les accusés de réception distinguent Envoyé et Lu, mais ne prouvent pas encore Livré par appareil. En groupe, la lecture actuelle indique qu'au moins un membre de l'aperçu a lu ; ce n'est pas une confirmation de lecture par tous.
- La réponse actuelle insère une citation dans le texte : ajouter une vraie relation reply_to avec navigation au message source demanderait une modification des données et de l'API.
- Les transferts, édition d'un message envoyé, galerie partagée, pagination et téléchargement avec progression réelle restent à traiter séparément.
- Ce correctif ne met pas en place le chiffrement de bout en bout ni les appels WhatsApp.

## Validation
Trois tests backend passent, y compris la liste réelle des conversations sur une base SQLite isolée. Les 40 fichiers GIF intégrés sont décodables et possèdent chacun 12 images. Deux tests de confidentialité du correctif précédent restent passants.
Le script Windows formate les versions de référence et les candidats avant comparaison, pour accepter le formatage déjà effectué sans écraser une modification locale inconnue. Il exécute l'analyse et les tests Flutter ; ceux-ci doivent passer sur le poste utilisateur avant compilation.
