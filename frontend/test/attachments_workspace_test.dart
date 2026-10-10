import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recruitment/services/recruitment_service.dart';
import 'package:frontend/features/recruitment/widgets/public/recruitment_welcome.dart';
import 'package:frontend/features/tasks/models/task_model.dart';
import 'package:frontend/shared/attachments/attachment_picker.dart';
import 'package:frontend/shared/ui/heritage_photo.dart';
import 'package:frontend/shared/ui/team_workspace_tools.dart';

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'public application submits the questionnaire and three named files without credentials',
    () async {
      final storage = AuthStorage(secureStore: MemorySecureStore());
      await storage.writeTokenPair(
        const AuthTokens(
          accessToken: 'private-access',
          refreshToken: 'private-refresh',
        ),
      );
      final service = RecruitmentService(
        apiClient: ApiClient(
          authStorage: storage,
          client: MockClient((request) async {
            expect(
              request.url.path,
              '/api/recruitment/applications/with-files',
            );
            expect(request.headers.containsKey('authorization'), isFalse);
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data;'),
            );
            for (final entry in [
              ('cv', 'cv.pdf', 'cv-content'),
              ('motivation_letter', 'lettre.pdf', 'letter-content'),
              ('attachment', 'portfolio.pdf', 'portfolio-content'),
            ]) {
              expect(
                request.body,
                contains('name="${entry.$1}"; filename="${entry.$2}"'),
              );
              expect(request.body, contains(entry.$3));
            }
            expect(request.body, contains('"questionnaire_version":"current"'));
            expect(request.body, contains('"motivation":"Agir ensemble."'));
            return _json({
              'id': 'candidate',
              'campaign_id': 'year',
              'first_name': 'Awa',
              'last_name': 'Test',
              'email': 'awa@example.org',
              'status': 'submitted',
              'tracking_code': 'TEST-2026',
            });
          }),
        ),
      );
      SelectedAttachment file(String name, String contents) =>
          SelectedAttachment(
            name: name,
            bytes: Uint8List.fromList(utf8.encode(contents)),
          );
      final result = await service.createApplication(
        campaignId: 'year',
        firstName: 'Awa',
        lastName: 'Test',
        email: 'awa@example.org',
        gender: 'femme',
        phone: '771234567',
        department: 'Génie Informatique',
        studyLevel: 'DIC1',
        motivation: 'Agir ensemble.',
        availability: 'Après les cours.',
        questionnaireVersion: 'current',
        questionnaireAnswers: {'motivation': 'Agir ensemble.'},
        cvFile: file('cv.pdf', 'cv-content'),
        motivationLetterFile: file('lettre.pdf', 'letter-content'),
        attachmentFile: file('portfolio.pdf', 'portfolio-content'),
      );
      expect(result.trackingCode, 'TEST-2026');
      expect((await storage.readTokenPair())!.accessToken, 'private-access');
    },
  );

  test('several files survive an authenticated token refresh', () async {
    final storage = AuthStorage(secureStore: MemorySecureStore());
    await storage.writeTokenPair(
      const AuthTokens(accessToken: 'old-access', refreshToken: 'old-refresh'),
    );
    var attempts = 0, refreshes = 0;
    final api = ApiClient(
      authStorage: storage,
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/refresh') {
          refreshes++;
          return _json({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          });
        }
        attempts++;
        expect(
          request.headers['authorization'],
          attempts == 1 ? 'Bearer old-access' : 'Bearer new-access',
        );
        expect(request.body, contains('filename="one.txt"'));
        expect(request.body, contains('first-file'));
        expect(request.body, contains('filename="two.txt"'));
        expect(request.body, contains('second-file'));
        return _json({'ok': true}, attempts == 1 ? 401 : 200);
      }),
    );
    expect(
      await api.postMultipartFiles(
        '/files/upload',
        token: 'old-access',
        files: {
          'one': (name: 'one.txt', bytes: utf8.encode('first-file')),
          'two': (name: 'two.txt', bytes: utf8.encode('second-file')),
        },
      ),
      {'ok': true},
    );
    expect(attempts, 2);
    expect(refreshes, 1);
  });

  test('server validation rights stay authoritative for a manager', () {
    final task = TaskModel.fromJson({
      'id': 'task',
      'title': 'Travail',
      'status': 'termine',
      'can_manage': true,
      'can_validate': false,
      'current_user_assigned': false,
      'proof_url': '/api/files/proof/download',
      'proof_filename': 'rapport.pdf',
    });
    expect(task.canReview, isFalse);
    expect(task.allowedStatusTransitions, isNot(contains('valide')));
    expect(task.proofFilename, 'rapport.pdf');
    expect(task.statusLabel, 'Terminé · à valider');
  });

  for (final width in [360.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'recruitment photos and attachment field fit width $width scale $scale dark $dark',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const RecruitmentWelcome(),
                          AttachmentPickerField(
                            label: 'CV facultatif',
                            application: true,
                            value: SelectedAttachment(
                              name:
                                  'Un-document-au-nom-long-pour-mon-dossier.pdf',
                              bytes: Uint8List.fromList([1, 2, 3]),
                            ),
                            onChanged: (_) {},
                          ),
                          const TeamWorkspaceTools(
                            name: 'Une équipe de projet',
                            projectId: 'project-42',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(HeritagePhoto), findsNWidgets(4));
            expect(tester.takeException(), isNull);
            await tester.scrollUntilVisible(
              find.text('Choisir un autre fichier'),
              400,
            );
            expect(tester.takeException(), isNull);
            await tester.scrollUntilVisible(find.text('Bilans'), 400);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final scope in ['pole', 'project']) {
    testWidgets('workspace opens tools with the $scope filter', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: SingleChildScrollView(
                child: TeamWorkspaceTools(
                  name: 'Équipe',
                  poleId: scope == 'pole' ? '42' : null,
                  projectId: scope == 'project' ? '42' : null,
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/veille',
            builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Blocages'));
      await tester.tap(find.text('Blocages'));
      await tester.pumpAndSettle();
      expect(find.text('/veille?${scope}_id=42&tab=blockers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class MemorySecureStore implements SecureKeyValueStore {
  final Map<String,String> values={};
  @override Future<String?> read(String key) async => values[key];
  @override Future<void> write(String key,String value) async { values[key]=value; }
  @override Future<void> delete(String key) async { values.remove(key); }
}
