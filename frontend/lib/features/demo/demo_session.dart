import 'package:flutter/foundation.dart';

import 'demo_recruitment_gateway.dart';

enum DemoProfile {
  enacteur,
  alumni;

  String get label => this == enacteur ? 'Enacteur' : 'Alumni';
}

/// Scoped to one public demo screen. Never holds a token or writes to storage.
class DemoSession extends ChangeNotifier {
  DemoSession(this.profile);
  final DemoProfile profile;
  final completedTasks = <String>{};
  final joinedEvents = <String>{};
  final savedMemories = <String>{};
  final likedPosts = <String>{};
  final completedLessons = <String>{};
  final readNotifications = <String>{};
  String conversationId = 'generations';
  final _messages = <String, List<String>>{};
  final _sharedItems = <String, List<DemoSharedItem>>{};
  List<String> get messages => _messages.putIfAbsent(conversationId, () => []);
  List<DemoSharedItem> get sharedItems =>
      _sharedItems.putIfAbsent(conversationId, () => []);
  final contributions = <String>[];
  final documents = <String>[];
  final poleRequests = <String>{};
  final recruitment = DemoRecruitmentGateway();
  bool mentoring = false;
  bool quizPassed = false;
  int simulatedPaid = 0;
  int get points => completedLessons.length * 20 + (quizPassed ? 50 : 0);

  void toggle(Set<String> collection, String id) {
    if (!collection.remove(id)) collection.add(id);
    notifyListeners();
  }

  void send(String text) {
    if (text.trim().isEmpty) return;
    messages.add(text.trim());
    notifyListeners();
  }

  void selectConversation(String id) {
    if (!demoConversations.containsKey(id)) return;
    conversationId = id;
    notifyListeners();
  }

  void share(DemoSharedItem item) {
    sharedItems.add(item);
    notifyListeners();
  }

  void addContribution(String text) {
    if (text.trim().isEmpty) return;
    contributions.add(text.trim());
    notifyListeners();
  }

  void saveDocument(String text) {
    documents.add(text);
    notifyListeners();
  }

  void completeLesson(String id) {
    completedLessons.add(id);
    notifyListeners();
  }

  void passQuiz() {
    quizPassed = true;
    notifyListeners();
  }

  void setMentoring(bool value) {
    mentoring = value;
    notifyListeners();
  }

  void markRead(String id) {
    readNotifications.add(id);
    notifyListeners();
  }

  void simulatePayment() {
    simulatedPaid = 1000;
    notifyListeners();
  }

  @override
  void dispose() {
    recruitment.dispose();
    super.dispose();
  }
}

const demoConversations = <String, String>{
  'generations': 'Générations en lien',
  'project': 'Équipe projet',
  'direct': 'Awa Démo',
};

class DemoSharedItem {
  const DemoSharedItem(this.kind, this.label, {this.asset, this.data});
  final String kind, label;
  final String? asset, data;
}

class DemoModule {
  const DemoModule(this.id, this.title, this.description, {this.alumni = true});
  final String id;
  final String title;
  final String description;
  final bool alumni;
}

const demoModules = [
  DemoModule(
    'home',
    'Accueil',
    'Un club, plusieurs générations. Un même élan.',
  ),
  DemoModule(
    'archives',
    'Souvenirs & archives',
    'Photothèque, projets et moments qui nous relient.',
  ),
  DemoModule(
    'alumni',
    'Alumni & mentorat',
    'Retrouver le réseau et transmettre son expérience.',
  ),
  DemoModule(
    'projects',
    'Projets',
    'Du besoin de terrain à la solution.',
    alumni: false,
  ),
  DemoModule('academy', 'Academy', 'Apprendre, essayer et progresser.'),
  DemoModule('chat', 'Discussions', 'Des échanges qui font avancer les idées.'),
  DemoModule(
    'posts',
    'Vie du club',
    'Partager les nouvelles de la communauté.',
  ),
  DemoModule(
    'events',
    'Événements',
    'Se retrouver, apprendre et agir ensemble.',
  ),
  DemoModule('meetings', 'EnactMeet', 'Préparer et retrouver ses réunions.'),
  DemoModule(
    'recruitment',
    'Recrutement & candidatures',
    'Essayer le formulaire, suivre un dossier et découvrir son accompagnement.',
  ),
  DemoModule(
    'members',
    'Annuaire des membres',
    'Retrouver les compétences et les équipes.',
    alumni: false,
  ),
  DemoModule(
    'impact',
    'Impact & résultats',
    'Comprendre comment les résultats sont suivis et documentés.',
    alumni: false,
  ),
  DemoModule(
    'tasks',
    'Mes tâches',
    'Des responsabilités claires, des avancées visibles.',
    alumni: false,
  ),
  DemoModule(
    'documents',
    'Documents',
    'Consulter les dossiers et préparer un brouillon.',
    alumni: false,
  ),
  DemoModule(
    'finance',
    'Mes cotisations',
    'Comprendre ses paiements et ses justificatifs.',
    alumni: false,
  ),
  DemoModule(
    'attendance',
    'Mes présences',
    'Retrouver sa participation aux activités.',
    alumni: false,
  ),
  DemoModule(
    'poles',
    'Pôles & équipes',
    'Des compétences complémentaires au service des projets.',
    alumni: false,
  ),
  DemoModule(
    'veille',
    'Suivi & accompagnement',
    'Suivre les échéances et demander un accompagnement.',
    alumni: false,
  ),
  DemoModule(
    'games',
    'Jeux & récompenses',
    'Créer des liens et valoriser l’engagement.',
    alumni: false,
  ),
  DemoModule(
    'notifications',
    'Notifications',
    'Retrouver ce qui vous concerne.',
  ),
  DemoModule('profile', 'Mon profil', 'Vos compétences et votre parcours.'),
  DemoModule(
    'settings',
    'Préférences',
    'Choisir son apparence et comprendre les notifications.',
  ),
  DemoModule(
    'help',
    'Aide & découverte',
    'Tout comprendre et explorer à son rythme.',
  ),
];

List<DemoModule> modulesFor(DemoProfile profile) => demoModules
    .where((module) => profile == DemoProfile.enacteur || module.alumni)
    .toList(growable: false);

/// Every real module has an explicit destination in the guided public visit.
/// This catalog does not grant access to any real application route.
const demoModuleRoutes = <String, String>{
  '/dashboard': 'home',
  '/archives': 'archives',
  '/alumni': 'alumni',
  '/projects': 'projects',
  '/academy': 'academy',
  '/chat': 'chat',
  '/posts': 'posts',
  '/events': 'events',
  '/meetings': 'meetings',
  '/members': 'members',
  '/impact': 'impact',
  '/tasks': 'tasks',
  '/documents': 'documents',
  '/finance': 'finance',
  '/attendance': 'attendance',
  '/poles': 'poles',
  '/veille': 'veille',
  '/gamification': 'games',
  '/recruitment': 'recruitment',
  '/application-tracking': 'recruitment',
  '/notifications': 'notifications',
  '/profile': 'profile',
  '/settings': 'settings',
  '/help': 'help',
  '/help-guide': 'help',
  '/welcome-help': 'help',
  '/about': 'help',
  '/activate': 'help',
  '/legal': 'help',
};

String? demoModuleForPath(String path) {
  final clean = Uri.parse(path).path;
  for (final entry in demoModuleRoutes.entries) {
    if (clean == entry.key || clean.startsWith('${entry.key}/'))
      return entry.value;
  }
  return null;
}
