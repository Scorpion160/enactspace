import 'dart:convert';

import '../../../core/api/api_client.dart';
import 'demo_heritage_data.dart';
import 'demo_session.dart';

typedef DemoJson = Map<String, dynamic>;

/// Contract-shaped example records for the production screens. Each visit owns
/// this store. Unknown endpoints fail here; there is no upstream or persistence.
class DemoNativeData {
  DemoNativeData(this.profile) {
    user = {
      'id': 'demo-${profile.name}',
      'first_name': 'Awa',
      'last_name': 'Démo',
      'email': 'awa.demo@example.test',
      'gender': 'femme',
      'status': profile == DemoProfile.alumni ? 'alumni' : 'active',
      'profile_type': profile.name,
      'roles': profile == DemoProfile.alumni ? ['alumni'] : ['chef_projet'],
      'can_access_recruitment': profile == DemoProfile.enacteur,
      'department': 'Génie informatique',
      'cursus': 'DIC',
      'study_level': 'DIC2',
      'promotion': '2025-2026',
      'academic_year': '2026-2027',
      'enactus_join_year': 2022,
      'graduation_year': 2024,
      'bio': 'Profil fictif de présentation · Alumni Day',
      'skills': 'Gestion de projet, communication et entrepreneuriat social',
      'created_at': stamp,
    };
    collections['/users'] = [
      user,
      {
        ...user,
        'id': 'demo-mamadou',
        'first_name': 'Mamadou',
        'email': 'mamadou.demo@example.test',
        'roles': ['enacteur'],
      },
      {
        ...user,
        'id': 'demo-fatou',
        'first_name': 'Fatou',
        'email': 'fatou.demo@example.test',
        'status': 'alumni',
        'roles': ['alumni'],
      },
    ];
    collections['/poles'] = [
      for (final entry in const {
        'tech': ('Tech', 'Concevoir et prototyper des solutions utiles.'),
        'chimie': ('Chimie', 'Transformer les ressources avec rigueur.'),
        'gestion': ('Gestion', 'Construire des modèles économiques durables.'),
        'it': ('IT', 'Créer les outils numériques du club.'),
        'communication': ('Communication', 'Faire rayonner les initiatives.'),
        'organisation': ('Organisation', 'Donner vie aux rencontres.'),
        'veille': ('Veille', 'Accompagner et suivre les avancées.'),
      }.entries)
        {
          'id': 'demo-${entry.key}',
          'name': entry.value.$1,
          'description': entry.value.$2,
          'status': 'active',
          'created_at': stamp,
        },
    ];
    collections['/projects'] = [
      for (final entry in const {
        'terrasen': (
          'Terrasen',
          'Valorisation des ressources et agriculture durable.',
        ),
        'aquatus': ('Aquatus', 'Innover autour de l’eau et de l’aquaculture.'),
        'men-nan': (
          'Mën Nañ',
          'Accompagner l’autonomie par l’entrepreneuriat.',
        ),
        'shery': (
          'Shery',
          'Une initiative portée par les générations Enactus ESP.',
        ),
        'dimbali': (
          'Dimbali',
          'Construire des solutions avec les communautés.',
        ),
      }.entries)
        {
          'id': 'demo-${entry.key}',
          'name': entry.value.$1,
          'description': '${entry.value.$2} Dossier de démonstration.',
          'problem_statement':
              'Identifier un besoin concret avec les communautés.',
          'solution': 'Tester une solution utile, viable et mesurable.',
          'objectives': 'Apprendre du terrain et améliorer le prototype.',
          'expected_impact': 'Objectifs fictifs pour illustrer le suivi.',
          'budget_estimated': 150000,
          'status': 'active',
          'created_at': stamp,
          'started_at': '2026-10-01',
        },
    ];
    collections['/seasons'] = [
      {
        'id': 'demo-season',
        'name': '2026-2027',
        'label': '2026-2027',
        'is_active': true,
        'start_date': '2026-09-01',
        'end_date': '2027-08-31',
      },
    ];
    collections['/tasks'] = [
      for (final entry in const {
        'terrain': ('Préparer la prochaine visite de terrain', 'en_cours'),
        'prototype': ('Partager le retour sur le prototype', 'a_faire'),
        'souvenirs': ('Sélectionner les souvenirs de l’équipe', 'termine'),
      }.entries)
        {
          'id': 'demo-task-${entry.key}',
          'title': entry.value.$1,
          'description': 'Exemple modifiable dans cette visite uniquement.',
          'status': entry.value.$2,
          'priority': 'normale',
          'can_manage': true,
          'current_user_assigned': true,
          'can_validate': false,
          'creator_id': user['id'],
          'project_id': 'demo-terrasen',
          'pole_id': 'demo-tech',
          'due_date': '2026-11-15',
          'created_at': stamp,
          'updated_at': stamp,
        },
    ];
    collections['/events'] = [
      {
        'id': 'demo-alumni-day',
        'title': 'Alumni Day · Les générations se retrouvent',
        'description':
            'Exemple d’événement : retrouvailles, souvenirs et transmission.',
        'event_type': 'conference',
        'location': 'ESP · Dakar',
        'start_time': '2026-10-24T09:00:00Z',
        'end_time': '2026-10-24T18:00:00Z',
        'requires_registration': true,
        'registered_count': 24,
        'current_user_registered': false,
        'max_participants': 80,
        'attendance_enabled': false,
        'can_manage': false,
        'created_at': stamp,
      },
      {
        'id': 'demo-atelier',
        'title': 'Atelier · De l’idée au prototype',
        'description':
            'Un atelier fictif pour découvrir les échanges entre pôles.',
        'event_type': 'training',
        'location': 'Salle des projets',
        'start_time': '2026-11-07T10:00:00Z',
        'requires_registration': true,
        'registered_count': 12,
        'max_participants': 30,
        'can_manage': false,
        'project_id': 'demo-terrasen',
        'created_at': stamp,
      },
    ];
    collections['/alumni/profiles'] = [
      for (final member in rows('/users'))
        {
          'id': 'alumni-${member['id']}',
          'user_id': member['id'],
          'display_name': '${member['first_name']} Démo',
          'graduation_year': 2024,
          'current_company': 'Entreprise de démonstration',
          'current_position': 'Ingénierie & entrepreneuriat',
          'domain': 'Innovation',
          'skills': 'Gestion de projet, mentorat, innovation',
          'experience_summary':
              'Un parcours fictif pour découvrir le réseau et le mentorat.',
          'available_for_mentoring': true,
          'visibility': 'internal',
          'created_at': stamp,
          'updated_at': stamp,
        },
    ];
    collections['/alumni/mentorships'] = [
      {
        'id': 'demo-mentorat',
        'alumni_id': 'alumni-demo-fatou',
        'title': 'De l’idée au terrain',
        'objective': 'Préparer un premier test utilisateur.',
        'status': 'active',
        'project_id': 'demo-terrasen',
        'created_at': stamp,
        'updated_at': stamp,
      },
    ];
    collections['/posts'] = [
      {
        'id': 'demo-post-generations',
        'title': 'Bienvenue aux générations Enactus ESP !',
        'content':
            'Le club continue de grandir grâce à ce que chaque génération transmet. '
            'Dans cet exemple, partagez un souvenir ou un conseil avec les équipes.',
        'post_type': 'announcement',
        'visibility': 'all',
        'is_official': true,
        'created_by': 'demo-fatou',
        'author_id': 'demo-fatou',
        'author_name': 'Fatou Démo',
        'created_at': stamp,
        'updated_at': stamp,
        'reactions_count': 8,
        'comments_count': 1,
      },
      {
        'id': 'demo-post-projet',
        'title': 'Une idée, plusieurs compétences',
        'content':
            'Tech, Gestion, Communication : chaque pôle apporte sa pierre au projet. '
            'Exemple de publication dans la vie du club.',
        'post_type': 'update',
        'visibility': 'all',
        'created_by': user['id'],
        'author_id': user['id'],
        'created_at': stamp,
        'updated_at': stamp,
      },
    ];
    collections['/notifications'] = [
      {
        'id': 'demo-notification',
        'title': 'Retrouvons-nous à l’Alumni Day',
        'message': 'Découvrez les souvenirs et les équipes dans cette visite.',
        'type': 'event',
        'related_type': 'event',
        'related_id': 'demo-alumni-day',
        'is_read': false,
        'route_path': '/events/demo-alumni-day',
        'created_at': stamp,
      },
    ];
    collections['/meetings'] = [
      {
        'id': 'demo-meeting',
        'title': 'Transmission entre générations',
        'description': 'Exemple de réunion EnactMeet pour préparer un échange.',
        'room_key': 'demo-local-only',
        'status': 'scheduled',
        'scope_type': 'club',
        'scheduled_start': '2026-11-02T18:00:00Z',
        'invited_count': 3,
        'created_by': user['id'],
        'can_manage': false,
        'can_delete': false,
        'start_with_audio_muted': true,
        'start_with_video_muted': true,
        'recording_enabled': false,
        'created_at': stamp,
      },
    ];
    collections['/chat/threads'] = [
      for (final entry in demoConversations.entries)
        {
          'id': 'demo-${entry.key}',
          'title': entry.value,
          'display_title': entry.value,
          'thread_type': entry.key == 'direct' ? 'direct' : 'group',
          'created_by': user['id'],
          'participants_count': 3,
          'unread_count': 1,
          'current_user_role': 'admin',
          'last_message': 'Les générations se retrouvent !',
          'created_at': stamp,
          'updated_at': stamp,
          'last_message_at': stamp,
          'participants_preview': chatMembers,
        },
    ];
    for (final thread in rows('/chat/threads')) {
      collections['/chat/threads/${thread['id']}/messages'] = [
        {
          'id': '${thread['id']}-welcome',
          'thread_id': thread['id'],
          'author_id': 'demo-fatou',
          'sender_name': 'Fatou Démo',
          'content': 'Bienvenue ! Quel souvenir du club aimerais-tu partager ?',
          'message_type': 'text',
          'created_at': stamp,
          'reactions': [],
        },
        {
          'id': '${thread['id']}-photo',
          'thread_id': thread['id'],
          'author_id': 'demo-mamadou',
          'sender_name': 'Mamadou Démo',
          'content': '',
          'message_type': 'image',
          'attachment_url': '/${demoHeritage.first['image_asset']}',
          'attachment_name': 'Un souvenir Enactus ESP',
          'attachment_mime_type': 'image/jpeg',
          'created_at': stamp,
          'reactions': [],
        },
      ];
    }
    collections['/finance/accounts'] = [
      {
        'id': 'demo-account',
        'user_id': user['id'],
        'balance_due': 1000,
        'total_paid': 2000,
        'updated_at': stamp,
      },
    ];
    collections['/finance/fees'] = [
      {
        'id': 'demo-fee',
        'user_id': user['id'],
        'account_id': 'demo-account',
        'title': 'Cotisation · exemple',
        'fee_type': 'membership',
        'amount': 3000,
        'amount_paid': 2000,
        'status': 'partial',
        'due_date': '2026-11-30',
        'created_at': stamp,
      },
    ];
    collections['/finance/payments'] = [
      {
        'id': 'demo-payment',
        'user_id': user['id'],
        'account_id': 'demo-account',
        'fee_id': 'demo-fee',
        'amount': 2000,
        'status': 'validated',
        'payment_method': 'cash',
        'reference': 'EXEMPLE-ALUMNI-DAY',
        'created_at': stamp,
      },
    ];
    collections['/attendance/sessions'] = [
      {
        'id': 'demo-attendance',
        'title': 'Atelier de rentrée · exemple',
        'session_type': 'training',
        'status': 'closed',
        'session_date': '2026-10-10',
        'start_time': '2026-10-10T10:00:00Z',
        'created_at': stamp,
      },
    ];
    collections['/attendance/my-records'] = [
      {
        'id': 'demo-presence',
        'session_id': 'demo-attendance',
        'user_id': user['id'],
        'status': 'present',
        'attendance_status': 'present',
        'created_at': stamp,
      },
    ];
    collections['/documents'] = [
      {
        'id': 'demo-document',
        'title': 'Dossier projet Terrasen',
        'description': 'Présentation publique du projet dans la photothèque.',
        'document_type': 'project',
        'category': 'project',
        'status': 'validated',
        'visibility': 'all',
        'file_url': 'assets/documents/terrasen-world-cup.pdf',
        'project_id': 'demo-terrasen',
        'created_by': user['id'],
        'created_at': stamp,
      },
    ];
    collections['/archives/media'] = [
      for (final row in demoHeritage)
        {
          ...row,
          'id': row['id'],
          'title': row['title'],
          'description': row['description'],
          'year': row['year'],
          'media_type': 'photo',
          'url': row['image_asset'],
          'file_url': row['image_asset'],
          'source_url': row['source_url'],
          'visibility': 'all',
          'status': 'validated',
          'created_at': stamp,
        },
    ];
    collections['/academy/courses'] = [
      for (final entry in const {
        'discover-enactus': ('Découvrir Enactus', 'culture_enactus'),
        'sdgs-impact': ('Comprendre les ODD', 'impact'),
        'pitch': ('Présenter son projet', 'competition'),
      }.entries)
        {
          'id': entry.key,
          'title': entry.value.$1,
          'category': entry.value.$2,
          'description':
              'Apprendre pour agir, avec un exemple de parcours complet.',
          'level': 'debutant',
          'duration_minutes': 15,
          'points': 40,
          'is_required': true,
          'is_published': true,
          'lessons': [
            {
              'id': '${entry.key}-lesson',
              'title': 'Des idées à l’action',
              'summary':
                  'Comprendre le besoin avant de construire la solution.',
              'lesson_type': 'texte',
              'duration_minutes': 5,
              'completed': false,
              'content':
                  'Une démarche Enactus commence par l’écoute. Rencontrez les personnes '
                  'concernées, identifiez leur besoin et construisez la solution avec elles.\n\n'
                  'Testez ensuite un prototype simple. Observez ce qui fonctionne, mesurez les '
                  'résultats et ajustez le modèle économique avec votre équipe.',
              'is_published': true,
            },
          ],
          'quiz': quiz(entry.key),
        },
    ];
    collections['/academy/me/paths'] = [
      {
        'id': 'welcome',
        'title': 'Mes premiers pas Enactus',
        'description': 'Un parcours pour comprendre, apprendre et agir.',
        'course_ids': ['discover-enactus', 'sdgs-impact', 'pitch'],
        'progress': 0,
      },
    ];
    for (final key in const [
      '/archives/items',
      '/archives/historical-projects',
      '/archives/awards',
      '/archives/competitions',
      '/archives/documents',
      '/archives/hall-of-fame',
      '/archives/historical-impact/statistics',
      '/impact/records',
      '/gamification/points',
      '/gamification/badges',
      '/gamification/user-badges',
      '/games/rooms/mine',
      '/games/leaderboard',
      '/support/tickets',
      '/feedback',
      '/institutional-documents/templates',
      '/institutional-documents/requests',
    ]) {
      collections[key] = [];
    }
    collections['/institutional-documents/templates'] = [
      {
        'code': 'demo_compte_rendu',
        'label': 'Compte rendu de réunion · exemple',
        'version': '1',
        'category': 'Vie du club',
        'scope': 'optional',
        'visibility': 'internal',
        'can_create': true,
        'requires_sg_validation': true,
        'fields': [
          {
            'name': 'title',
            'label': 'Objet de la réunion',
            'type': 'text',
            'required': true,
          },
          {
            'name': 'summary',
            'label': 'Points abordés',
            'type': 'textarea',
            'required': true,
          },
        ],
      },
    ];
    collections['/impact/records'] = [
      {
        'id': 'demo-impact',
        'project_id': 'demo-terrasen',
        'title': 'Suivi du pilote · exemple',
        'summary':
            'Fiche fictive : préparer les indicateurs avant la prochaine visite.',
        'problem_statement':
            'Documenter le besoin avec les personnes concernées.',
        'solution_summary': 'Tester un prototype et mesurer ses résultats.',
        'status': 'DRAFT',
        'sdgs': ['12'],
        'created_at': stamp,
        'updated_at': stamp,
      },
    ];
    collections['/impact/records/demo-impact/metrics'] = [];
    collections['/impact/records/demo-impact/evidence'] = [];
    collections['/gamification/badges'] = [
      {
        'id': 'demo-badge',
        'name': 'curieux',
        'label': 'Esprit curieux',
        'description': 'Une récompense fictive pour découvrir les parcours.',
        'created_at': stamp,
      },
    ];
    collections['/gamification/points'] = [
      {
        'id': 'demo-points',
        'user_id': user['id'],
        'points': 60,
        'source_type': 'academy',
        'reason': 'Progression d’exemple',
        'created_at': stamp,
      },
    ];
  }

  static const stamp = '2026-10-24T09:00:00Z';
  final DemoProfile profile;
  late final DemoJson user;
  final collections = <String, List<DemoJson>>{};
  final requests = <String>[];
  final preferences = <String, dynamic>{
    'locale': 'fr',
    'theme': 'system',
    'notification_in_app_enabled': true,
    'notification_email_enabled': false,
    'notification_push_enabled': false,
  };
  DemoJson? deletion;
  final completedLessons = <String>{};
  final passedQuizzes = <String>{};
  List<DemoJson> rows(String path) => collections[path] ?? const [];
  List<DemoJson> get chatMembers => [
    for (final m in rows('/users'))
      {
        'user_id': m['id'],
        'display_name': '${m['first_name']} Démo',
        'first_name': m['first_name'],
        'last_name': 'Démo',
        'participant_role': 'member',
        'joined_at': stamp,
      },
  ];

  DemoJson quiz(String id) => {
    'id': '$id-quiz',
    'title': 'À vous de jouer',
    'category': 'Culture Enactus',
    'time_limit_minutes': 5,
    'questions': [
      {
        'id': '$id-question',
        'question': 'Par quoi commencer un projet ?',
        'options': [
          'Écouter les personnes concernées',
          'Choisir un logo',
          'Acheter le matériel',
        ],
        'correct_answer_index': 0,
        'explanation': 'Un projet commence par un besoin réel.',
      },
    ],
  };

  Object? handle(String method, String raw, [DemoJson data = const {}]) {
    final uri = Uri.parse(raw);
    if (uri.hasScheme || uri.hasAuthority) return _unsupported();
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    requests.add('$method $path');
    Object? result;
    if (path == '/users/directory') {
      result = rows('/users');
    } else if (path == '/users/pending') {
      result = [];
    } else if (path == '/users/me') {
      if (method != 'GET') user.addAll(data);
      result = user;
    } else if (path == '/seasons/context') {
      result = {'can_manage': false, 'active_season': rows('/seasons').first};
    } else if (path == '/academic-profile/catalog') {
      result = {
        'departments': {
          'Génie informatique': {
            'DIC': ['DIC1', 'DIC2', 'DIC3'],
          },
          'Génie Électrique': {
            'DIC': ['DIC1', 'DIC2', 'DIC3'],
          },
        },
      };
    } else if (path.startsWith('/academic-profile/me')) {
      if (method != 'GET') user.addAll(data);
      result = {
        ...user,
        'level': user['study_level'],
        'requires_confirmation': false,
      };
    } else if (path == '/veille/context') {
      result = {
        'user_id': user['id'],
        'can_coordinate': true,
        'members': [
          for (final m in rows('/users'))
            {...m, 'name': '${m['first_name']} Démo'},
        ],
        'poles': rows('/poles'),
        'projects': rows('/projects'),
        'seasons': rows('/seasons'),
      };
    } else if (path == '/veille/summary') {
      result = {
        'totals': {'tasks': 3, 'completed': 1, 'late': 0},
        'tasks': [
          for (final t in rows('/tasks'))
            {
              ...t,
              'assignees': [
                {'id': user['id'], 'name': 'Awa Démo'},
              ],
            },
        ],
        'members': [],
        'groups': [],
      };
    } else if (path == '/veille/records') {
      result = {
        'plans': [],
        'blockers': [],
        'reports': [],
        'leaves': [],
        'cases': [],
      };
    } else if (path == '/users/me/preferences') {
      if (method != 'GET') preferences.addAll(data);
      result = preferences;
    } else if (path == '/users/me/deletion-request/cancel') {
      deletion = {
        ...?deletion,
        'id': 'demo-deletion',
        'status': 'cancelled',
        'requested_at': stamp,
      };
      result = deletion;
    } else if (path == '/users/me/deletion-request') {
      if (method != 'GET') {
        deletion = {
          'id': 'demo-deletion',
          'status': 'pending',
          'requested_at': stamp,
          'reason': data['reason'],
        };
      }
      result = deletion;
    } else if (path == '/users/me/data-export') {
      result = {
        'metadata': {'generated_at': stamp, 'demo': true},
        'profile': user,
      };
    } else if (path.contains('mobile-money') ||
        path.startsWith('/payments') ||
        path.endsWith('/join') && path.startsWith('/meetings')) {
      return _unsupported(
        'Les paiements et les appels réels sont désactivés dans la démo.',
      );
    } else if (path == '/dashboard/summary') {
      final alumni = profile == DemoProfile.alumni;
      result = {
        'profile': {
          ...user,
          'display_name': 'Awa Démo',
          'is_alumni': alumni,
          'can_view_attendance': !alumni,
          'can_view_finance': !alumni,
          'can_view_recruitment': !alumni,
          'is_enacchef': !alumni,
        },
        'counts': {
          'my_tasks': 3,
          'my_tasks_pending': 2,
          'my_tasks_completed': 1,
          'my_tasks_late': 0,
          'upcoming_events': 2,
          'unread_notifications': 1,
          'projects': 5,
          'active_projects': 5,
          'poles': 7,
          'alumni': 3,
          'my_balance_due': 1000,
          'my_total_paid': 2000,
        },
        'recent_activity': [
          {
            'type': 'event',
            'title': 'Retrouvez les générations Enactus ESP',
            'created_at': stamp,
            'route': '/archives',
          },
          {
            'type': 'project',
            'title': 'Découvrez les projets de l’équipe',
            'created_at': stamp,
            'route': '/projects',
          },
        ],
      };
    } else if (path == '/chat/contacts') {
      result = rows('/users');
    } else if (path.endsWith('/unread-count')) {
      result = {'unread_count': 1};
    } else if (path == '/chat/uploads') {
      return _unsupported(
        'Choisissez un média proposé dans la démo. Aucun fichier personnel n’est envoyé.',
      );
    } else if (parts.length >= 4 &&
        parts[0] == 'chat' &&
        parts[1] == 'threads') {
      final base = '/chat/threads/${parts[2]}/messages';
      if (parts[3] == 'messages' || parts[3] == 'shared') {
        if (method == 'POST') {
          final message = {
            ...data,
            'id': 'demo-message-${rows(base).length}',
            'thread_id': parts[2],
            'author_id': user['id'],
            'sender_name': 'Awa Démo',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'reactions': [],
          };
          collections.putIfAbsent(base, () => []).add(message);
          result = message;
        } else {
          result = rows(base)
              .where((m) => parts[3] != 'shared' || m['message_type'] != 'text')
              .toList();
        }
      } else if (parts[3] == 'participants' || parts[3] == 'members') {
        result = chatMembers;
      } else if (parts[3] == 'read') {
        result = {'ok': true};
      } else {
        return _unsupported();
      }
    } else if (parts.length == 3 &&
        parts[0] == 'events' &&
        parts[2] == 'register') {
      final event = _find('/events', parts[1]);
      final registering = method == 'POST';
      final previous = event['current_user_registered'] == true;
      if (registering != previous) {
        event['registered_count'] =
            (event['registered_count'] as int? ?? 0) + (registering ? 1 : -1);
      }
      event['current_user_registered'] = registering;
      result = event;
    } else if (path == '/notifications/read-all') {
      for (final n in rows('/notifications')) {
        n['is_read'] = true;
      }
      result = {'updated_count': 1, 'unread_count': 0};
    } else if (parts.length == 3 && parts[0] == 'notifications') {
      final row = _find('/notifications', parts[1]);
      row['is_read'] = parts[2] == 'read';
      result = row;
    } else if (path.startsWith('/academy')) {
      result = _academy(method, path, data);
    } else if (path == '/institutional-memory/timeline') {
      var items = demoHeritage
          .map(
            (m) => <String, dynamic>{
              'id': m['id'],
              'resource_type': 'media',
              'title': m['title'],
              'year': m['year'],
              'summary': 'Photothèque publique Enactus ESP · ${m['title']}',
              'date_precision': 'year',
              'validation_status': 'HISTORICAL_REPORTED',
              'origin': 'manual',
              'source': {
                'label': 'Photothèque publique Enactus ESP',
                'url': m['source_url'],
              },
            },
          )
          .toList();
      final q = uri.queryParameters;
      if (q['search']?.isNotEmpty == true) {
        items = items
            .where(
              (m) => '${m['title']} ${m['year']}'.toLowerCase().contains(
                q['search']!.toLowerCase(),
              ),
            )
            .toList();
      }
      if (int.tryParse(q['start_year'] ?? '') case final int y) {
        items = items.where((m) => (m['year'] as int) >= y).toList();
      }
      if (int.tryParse(q['end_year'] ?? '') case final int y) {
        items = items.where((m) => (m['year'] as int) <= y).toList();
      }
      if (q['resource_type']?.isNotEmpty == true &&
          q['resource_type'] != 'media') {
        items = [];
      }
      final offset = int.tryParse(q['cursor'] ?? '') ?? 0;
      final limit = (int.tryParse(q['limit'] ?? '') ?? 25).clamp(1, 100);
      result = {
        'items': items.skip(offset).take(limit).toList(),
        'next_cursor': offset + limit < items.length
            ? '${offset + limit}'
            : null,
      };
    } else if (path.startsWith('/institutional-memory/timeline/')) {
      final row = demoHeritage.firstWhere((m) => m['id'] == parts.last);
      result = {
        'id': row['id'],
        'resource_type': 'media',
        'title': row['title'],
        'year': row['year'],
        'summary': row['title'],
        'date_precision': 'year',
        'validation_status': 'HISTORICAL_REPORTED',
        'origin': 'manual',
        'related_entities': [
          {
            'type': 'media',
            'id': row['id'],
            'label': 'Voir la photo',
            'available': true,
          },
        ],
      };
    } else if (path == '/archives/historical-impact/summary') {
      result = <String, dynamic>{};
    } else if (path == '/impact/summary') {
      result = {
        'organization': {'active_members': 3, 'completed_tasks': 1},
        'historical_impact': {},
        'enacteurs': [],
        'poles': [],
      };
    } else if (path == '/impact/projects') {
      result = [
        for (final p in rows('/projects'))
          {
            'id': p['id'],
            'project_id': p['id'],
            'project_name': p['name'],
            'status': 'active',
            'problem': p['problem_statement'],
            'solution': p['solution'],
            'progress': 35,
            'completed_tasks': 1,
            'methodology':
                'Données fictives de présentation, sans résultat réel revendiqué.',
          },
      ];
    } else if (path.startsWith('/gamification/ranking')) {
      result = [
        for (final m in rows('/users'))
          {
            'user_id': m['id'],
            'display_name': '${m['first_name']} Démo',
            'first_name': m['first_name'],
            'last_name': 'Démo',
            'total_points': 60,
            'rank': 1,
          },
      ];
    } else if (path.startsWith('/gamification/winner')) {
      result = <String, dynamic>{};
    } else if (path.startsWith('/games/profile')) {
      result = {'points': 60, 'wins': 1, 'games': 2, 'badges': []};
    } else if (path == '/finance/accounts/me') {
      result = rows('/finance/accounts').first;
    } else if (path == '/finance/fees/me' || path == '/finance/payments/me') {
      result = rows(path.replaceFirst('/me', ''));
    } else if (path == '/tasks/my' ||
        path == '/tasks/late' ||
        path.startsWith('/tasks/pole/') ||
        path.startsWith('/tasks/project/')) {
      result = path == '/tasks/late' ? [] : rows('/tasks');
    } else if (parts.length >= 3 &&
        (parts[0] == 'poles' || parts[0] == 'projects') &&
        parts[2] == 'members') {
      result = parts[0] == 'poles'
          ? rows('/users')
          : [
              for (final m in rows('/users'))
                {
                  'id': 'team-${m['id']}',
                  'project_id': parts[1],
                  'user_id': m['id'],
                  'position': 'member',
                  'display_name': '${m['first_name']} Démo',
                  'is_active': true,
                  'joined_at': stamp,
                  'user': m,
                  'first_name': m['first_name'],
                  'last_name': 'Démo',
                },
            ];
    } else if (parts.length >= 3 && parts[0] == 'tasks') {
      if (parts[2] == 'assignees') {
        result = [
          {'id': 'demo-assignee', 'task_id': parts[1], 'user_id': user['id']},
        ];
      } else if (parts[2] == 'status' ||
          parts[2] == 'proof' ||
          parts[2] == 'validate') {
        final task = _find('/tasks', parts[1]);
        task.addAll(data);
        result = task;
      } else {
        return _unsupported();
      }
    } else if (parts.length >= 3 && parts[0] == 'posts') {
      if (parts[2] == 'stats') {
        result = {
          'post_id': parts[1],
          'reactions_count': 8,
          'comments_count': 1,
          'views_count': 16,
        };
      } else if (parts[2] == 'comments') {
        result = collections.putIfAbsent(path, () => []);
      } else {
        result = _find('/posts', parts[1]);
      }
    } else if (path == '/posts/comments') {
      final row = {
        ...data,
        'id': 'demo-comment-${requests.length}',
        'user_id': user['id'],
        'created_at': stamp,
      };
      collections
          .putIfAbsent('/posts/${data['post_id']}/comments', () => [])
          .add(row);
      result = row;
    } else if (path == '/posts/reactions') {
      result = {
        ...data,
        'id': 'demo-reaction',
        'user_id': user['id'],
        'created_at': stamp,
      };
    } else if (parts.length == 3 &&
        parts[0] == 'meetings' &&
        parts[2] == 'members') {
      result = chatMembers;
    } else if (path.startsWith('/attendance/expected-members/')) {
      result = [
        for (final m in rows('/users'))
          {
            'id': 'expected-${m['id']}',
            'user_id': m['id'],
            'session_id': 'demo-attendance',
            'status': 'expected',
          },
      ];
    } else if (path.endsWith('/records') &&
        path.startsWith('/attendance/sessions/')) {
      result = rows('/attendance/my-records');
    } else if (path == '/institutional-documents/renderer-status') {
      result = {'available': false};
    } else if (path == '/attendance/stats') {
      result = {'present': 1, 'absent': 0, 'total': 1, 'attendance_rate': 100};
    } else {
      // Only explicitly seeded collections and their records can be changed.
      String? base;
      for (final key in collections.keys) {
        if (path == key || path.startsWith('$key/')) {
          if (base == null || key.length > base.length) base = key;
        }
      }
      if (base == null) return _unsupported();
      final suffix = path.substring(base.length);
      if (suffix.isEmpty) {
        if (method == 'GET') {
          result = rows(base).where((row) {
            for (final key in [
              'status',
              'project_id',
              'pole_id',
              'category',
              'visibility',
              'year',
              'media_type',
            ]) {
              final value = uri.queryParameters[key];
              if (value != null &&
                  value.isNotEmpty &&
                  value != 'all' &&
                  '${row[key]}' != value) {
                return false;
              }
            }
            final search = uri.queryParameters['search']?.toLowerCase() ?? '';
            return search.isEmpty ||
                jsonEncode(row).toLowerCase().contains(search);
          }).toList();
        } else if (method == 'POST') {
          final row = {
            ...data,
            'id': 'demo-created-${requests.length}',
            'created_by': user['id'],
            'created_at': stamp,
            'updated_at': stamp,
            if (base == '/institutional-documents/requests') ...{
              'status': 'draft',
              'requested_by': user['id'],
              'can_edit': true,
              'can_submit': true,
              'template_label': 'Compte rendu de réunion · exemple',
              'template_version': '1',
            },
          };
          collections[base]!.add(row);
          result = row;
        } else {
          return _unsupported();
        }
      } else if (suffix.split('/').length == 2) {
        final row = _find(base, suffix.substring(1));
        if (method == 'DELETE') collections[base]!.remove(row);
        if (method == 'PATCH' || method == 'PUT') row.addAll(data);
        result = row;
      } else {
        return _unsupported();
      }
    }
    // Return detached JSON just as a real transport does.
    return jsonDecode(jsonEncode(result));
  }

  Object? _academy(String method, String path, DemoJson data) {
    if (collections.containsKey(path) && method == 'GET') return rows(path);
    if (path == '/academy/me/progress') {
      return {
        'completed_lessons': completedLessons.length,
        'total_lessons': 3,
        'passed_quizzes': passedQuizzes.length,
        'total_quizzes': 3,
        'points': completedLessons.length * 20 + passedQuizzes.length * 40,
        'rank': 1,
        'monthly_progress': completedLessons.length / 3 * 100,
      };
    }
    if (path.startsWith('/academy/lessons/')) {
      final parts = path.split('/');
      final id = parts[3];
      final lesson = rows('/academy/courses')
          .expand((c) => (c['lessons'] as List).cast<DemoJson>())
          .firstWhere((l) => l['id'] == id);
      lesson['started'] = true;
      if (parts.last == 'complete') {
        final fresh = completedLessons.add(id);
        lesson['completed'] = true;
        return {
          'points': fresh ? 20 : 0,
          'message': 'Leçon terminée · démo',
          'gamification_synced': true,
        };
      }
      return {'ok': true};
    }
    if (path.startsWith('/academy/quizzes/')) {
      final id = path.split('/')[3];
      if (method == 'GET') return quiz(id.replaceFirst('-quiz', ''));
      final answers = data['answers'] as List? ?? [];
      final passed = answers.isNotEmpty && answers.first == 0;
      final fresh = passed && passedQuizzes.add(id);
      for (final course in rows('/academy/courses')) {
        if ((course['quiz'] as Map)['id'] == id && passed) {
          course['quiz_passed'] = true;
        }
      }
      return {
        'score': passed ? 100 : 0,
        'passed': passed,
        'points': fresh ? 40 : 0,
        'correct_answers': 1,
        'total_questions': 1,
        'corrections': [],
      };
    }
    return _unsupported();
  }

  DemoJson _find(String base, String id) => rows(base).firstWhere(
    (m) => m['id'] == id,
    orElse: () => throw ApiException(
      statusCode: 404,
      message: 'Cet exemple n’existe pas dans la démo.',
    ),
  );

  Never _unsupported([String? text]) => throw ApiException(
    statusCode: 400,
    message:
        text ??
        'Cette action n’est pas disponible dans la démo. Vos données réelles ne sont pas modifiées.',
  );
}
