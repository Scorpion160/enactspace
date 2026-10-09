import 'package:flutter/material.dart';

class HelpArticle {
  final String title, body;
  final IconData icon;
  const HelpArticle(this.title, this.body, this.icon);
}

class HelpQuestion {
  final String question, answer;
  const HelpQuestion(this.question, this.answer);
}

const helpGuideArticles = [
  HelpArticle(
    "Activer mon accès et compléter mon profil",
    "Si votre profil a été préparé par l’équipe, choisissez « Première connexion ». Utilisez votre email ou votre nom d’utilisateur pour recevoir votre code personnel. Vous choisissez votre propre mot de passe ; personne dans EnacChef n’a besoin de le connaître.\n\nAprès la connexion, vérifiez les informations préremplies. Votre année d’entrée dans Enactus ESP et votre parcours scolaire situent votre expérience. Une adresse provisoire doit être confirmée avec la SG. Gardez le même compte pour conserver votre historique.",
    Icons.key_outlined,
  ),
  HelpArticle(
    "Trouver ma place dans Enactus ESP",
    "Votre accueil présente trois repères : apprendre dans Academy, découvrir notre histoire dans Archives et contribuer avec votre équipe. Les pôles et les projets rassemblent leurs membres, leurs objectifs et leur travail. Les outils visibles dépendent de votre profil et de vos responsabilités.\n\nUn Alumni conserve son histoire au sein de Enactus ESP. Son accueil demande l’année de fin d’études. Ses anciens rôles ne lui donnent pas automatiquement les droits de gestion de l’équipe actuelle.",
    Icons.groups_outlined,
  ),
  HelpArticle(
    "Faire avancer une tâche",
    "Ouvrez Tâches et consultez l’objectif, l’échéance, le responsable et l’état du travail confié. Passez la tâche en cours lorsque vous commencez et signalez un blocage dès qu’il apparaît.\n\nÀ la remise du travail, joignez le fichier demandé comme preuve ou livrable et expliquez ce que vous avez réalisé. La remise et la validation sont deux étapes : le responsable habilité examine le résultat, peut demander une reprise et confirme la fin de la tâche.",
    Icons.task_alt_outlined,
  ),
  HelpArticle(
    "Apprendre dans Academy",
    "Commencez par le parcours des nouveaux membres, puis suivez les cours dans leur ordre. Ouvrez une leçon, lisez les explications, observez les illustrations et réalisez l’exercice proposé avant d’indiquer que vous l’avez terminée.\n\nLe quiz vérifie votre compréhension. Certains cours se débloquent après les prérequis du niveau précédent. Attendez la confirmation d’enregistrement ; si elle échoue, gardez le message affiché et réessayez lorsque la connexion revient.",
    Icons.school_outlined,
  ),
  HelpArticle(
    "Comprendre nos projets et notre impact",
    "Dans Archives, découvrez les projets, les concours, les voyages et les personnes qui ont construit Enactus ESP. La Minute de l’Enacteur réunit aussi les réflexions et conseils partagés au fil des années.\n\nProjets et Impact présentent le problème abordé, les bénéficiaires, les activités et les résultats. Pour contribuer aujourd’hui, utilisez les outils du projet auquel vous êtes rattaché et demandez une précision au responsable lorsque l’information manque.",
    Icons.auto_stories_outlined,
  ),
  HelpArticle(
    "Suivre mon année et mes informations",
    "Dans votre profil et Réglages, vérifiez vos coordonnées, vos notifications et votre parcours scolaire. Une confirmation enregistrée pour l’année courante est conservée. La SG accompagne les corrections de l’historique et le passage vers le statut Alumni.\n\nVous pouvez consulter les documents légaux, demander une copie de vos données et suivre une demande de suppression. Les informations obligatoires de l’accueil restent nécessaires pour utiliser votre espace.",
    Icons.manage_accounts_outlined,
  ),
  HelpArticle(
    "Demander de l’aide ou proposer une amélioration",
    "Une demande d’aide sert à obtenir une réponse pour votre situation : compte, accès, problème technique ou paiement. Donnez un sujet clair, décrivez votre objectif et les étapes qui conduisent au problème. Retrouvez les échanges et répondez dans « Mes demandes d’aide ».\n\nUn avis sert à signaler un bug, proposer une idée ou améliorer la navigation. Expliquez le résultat attendu et ce que vous observez. « Mes avis » présente le suivi et les réponses de l’équipe. Les notes internes ne sont pas publiées. Ne transmettez jamais votre mot de passe ni votre code personnel.",
    Icons.support_agent_outlined,
  ),
];
const helpQuestions = [
  HelpQuestion(
    "Comment activer un profil déjà créé ?",
    "Choisissez « Première connexion », utilisez votre email ou votre nom d’utilisateur et le code reçu par email. Il expire après 30 minutes. Vous définissez votre mot de passe, puis vous vous connectez normalement.",
  ),
  HelpQuestion(
    "Mon adresse email manque ou a changé. Que faire ?",
    "Contactez la SG pour confirmer votre identité et votre adresse personnelle. Pour un compte déjà utilisé, un administrateur prépare la récupération après vérification et ferme les anciennes sessions. Ne créez pas un deuxième compte.",
  ),
  HelpQuestion(
    "Pourquoi dois-je compléter mon profil ?",
    "Ces informations situent votre parcours, votre année d’entrée dans Enactus ESP et votre situation actuelle. Les champs obligatoires doivent être complétés avant l’accès à votre espace. Le formulaire reprend les informations déjà enregistrées.",
  ),
  HelpQuestion(
    "Puis-je demander de l’aide pendant mon accueil ?",
    "Oui. Le bouton « Besoin d’aide ? » ouvre vos demandes après la connexion, même si votre profil n’est pas terminé. Il ne débloque pas les autres activités. Avant la connexion, le guide et la FAQ restent accessibles.",
  ),
  HelpQuestion(
    "La biométrie remplace-t-elle la première activation ?",
    "Non. Activez d’abord votre accès et connectez-vous avec votre mot de passe. La biométrie dépend ensuite de votre téléphone et des réglages disponibles. Gardez votre mot de passe personnel pour la récupération d’accès.",
  ),
  HelpQuestion(
    "Pourquoi un cours reste-t-il verrouillé ?",
    "Certains cours demandent de terminer un niveau ou de valider un quiz auparavant. Consultez le parcours et ses prérequis. Si une réussite enregistrée ne débloque pas la suite, actualisez Academy et signalez le cours concerné.",
  ),
  HelpQuestion(
    "Comment remettre la preuve d’une tâche ?",
    "Ouvrez la tâche et joignez votre fichier ou livrable dans l’espace prévu, avec une explication. Le responsable habilité valide le résultat ou demande une reprise.",
  ),
  HelpQuestion(
    "Comment gérer mes notifications ?",
    "Ouvrez Réglages pour choisir les alertes dans l’application et par e-mail. Les notifications du téléphone dépendent aussi de son autorisation et de la connexion. Le suivi reste consultable dans le centre d’aide.",
  ),
  HelpQuestion(
    "Comment obtenir une copie de mes données ?",
    "Dans Réglages, choisissez « Exporter mes données », puis confirmez la copie.",
  ),
  HelpQuestion(
    "La suppression du compte est-elle immédiate ?",
    "Non. Vous envoyez une demande dont vous pouvez suivre l’état et annuler tant qu’elle est en attente.",
  ),
  HelpQuestion(
    "Comment signaler un bug utilement ?",
    "Dans « Donner mon avis », choisissez « Problème ». Indiquez l’écran, les étapes réalisées, le résultat attendu et le message observé. Pour un échange sur votre situation, ouvrez une demande d’aide. Ne communiquez aucun mot de passe ni code.",
  ),
  HelpQuestion(
    "Qui peut lire mes demandes et mes avis ?",
    "Vous retrouvez vos propres messages. Leur traitement est réservé à l’administration, au Team Leader et à la SG actifs et habilités. Ils ne sont pas publiés à tous les membres.",
  ),
  HelpQuestion(
    "Comment suivre une suggestion envoyée ?",
    "Dans « Mes avis », touchez la remarque pour lire son état : reçue, étudiée, prévue ou clôturée. Les réponses destinées aux membres y sont visibles.",
  ),
  HelpQuestion(
    "Que faire si un envoi échoue ?",
    "Le formulaire garde votre texte pour vous permettre de réessayer. Attendez le résultat avant de fermer la fenêtre. Ne considérez pas un message comme envoyé tant que l’application ne l’a pas confirmé.",
  ),
  HelpQuestion(
    "Que devient mon compte lorsque je deviens Alumni ?",
    "La transition conserve votre compte et son historique. Votre accueil demande l’année de fin d’études. Si le statut affiché ne correspond pas à votre situation, demandez une vérification à la SG.",
  ),
];

String _normalized(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');

class HelpGuidePanel extends StatefulWidget {
  const HelpGuidePanel({super.key});
  @override
  State<HelpGuidePanel> createState() => _HelpGuidePanelState();
}

class _HelpGuidePanelState extends State<HelpGuidePanel> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final search = _normalized(query);
    final articles = helpGuideArticles
        .where((a) => _normalized('${a.title} ${a.body}').contains(search))
        .toList();
    final questions = helpQuestions
        .where((q) => _normalized('${q.question} ${q.answer}').contains(search))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('help-search'),
          decoration: const InputDecoration(
            labelText: 'Rechercher dans le guide et la FAQ',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 20),
        Text(
          'Guide d’utilisation',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final article in articles)
          Card(
            child: ExpansionTile(
              leading: Icon(article.icon),
              title: Text(article.title),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      article.body,
                      style: const TextStyle(height: 1.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Questions fréquentes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final question in questions)
          ExpansionTile(
            title: Text(question.question),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    question.answer,
                    style: const TextStyle(height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        if (articles.isEmpty && questions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Aucune réponse trouvée. Essayez un autre mot ou ouvrez une demande d’aide après connexion.',
            ),
          ),
      ],
    );
  }
}
