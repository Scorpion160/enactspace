import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/recruitment/models/public_application_draft.dart';
import 'package:frontend/features/recruitment/services/public_recruitment_gateway.dart';
import 'package:frontend/features/recruitment/services/recruitment_service.dart';
import 'package:frontend/shared/attachments/attachment_picker.dart';

PublicApplicationDraft _draft(bool files) => PublicApplicationDraft(
  campaignId: 'campaign-qa',
  firstName: 'Awa',
  lastName: 'Test',
  email: 'awa@example.test',
  gender: 'femme',
  phone: '+221770000000',
  department: 'Génie Informatique',
  studyLevel: 'Master1',
  motivation: 'Apprendre et agir.',
  cvFile: files
      ? SelectedAttachment(
          name: 'cv-qa.pdf',
          bytes: Uint8List.fromList([37, 80, 68, 70]),
        )
      : null,
);

void main() {
  for (final files in [false, true]) {
    for (final entry in [
      (
        409,
        'Une candidature existe déjà pour cet email',
        PublicRecruitmentFailureKind.duplicateApplication,
      ),
      (
        409,
        'Le QUESTIONNAIRE a changé.',
        PublicRecruitmentFailureKind.questionnaireChanged,
      ),
      (409, 'Un autre conflit.', PublicRecruitmentFailureKind.server),
      (404, 'Campagne introuvable', PublicRecruitmentFailureKind.notFound),
      (
        422,
        'Vérifiez les champs obligatoires',
        PublicRecruitmentFailureKind.invalidApplication,
      ),
      (
        413,
        'Le formulaire dépasse la taille autorisée.',
        PublicRecruitmentFailureKind.fileTooLarge,
      ),
      (
        400,
        'Cette campagne de recrutement n’est pas ouverte.',
        PublicRecruitmentFailureKind.campaignClosed,
      ),
      (
        400,
        'Ce document n’est pas accepté.',
        PublicRecruitmentFailureKind.invalidApplication,
      ),
      (429, 'Too many requests', PublicRecruitmentFailureKind.rateLimited),
      (
        503,
        'SQLAlchemy Traceback sensitive diagnostic',
        PublicRecruitmentFailureKind.server,
      ),
    ]) {
      test('submission ${entry.$1} ${entry.$3.name} files=$files', () async {
        var requests = 0;
        final api = ApiClient(
          client: MockClient((request) async {
            requests++;
            expect(request.method, 'POST');
            expect(
              request.url.path,
              files
                  ? '/api/recruitment/applications/with-files'
                  : '/api/recruitment/applications',
            );
            if (files) {
              expect(
                request.headers['content-type'],
                contains('multipart/form-data'),
              );
              expect(request.body, contains('cv-qa.pdf'));
              expect(request.body, contains('campaign-qa'));
            }
            return http.Response(
              jsonEncode({'detail': entry.$2}),
              entry.$1,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final gateway = RecruitmentPublicGateway(
          service: RecruitmentService(apiClient: api),
        );
        await expectLater(
          gateway.submitApplication(_draft(files)),
          throwsA(
            isA<PublicRecruitmentFailure>()
                .having((e) => e.kind, 'kind', entry.$3)
                .having(
                  (e) => e.submissionMessage,
                  'safe human text',
                  isNot(contains('SQLAlchemy')),
                ),
          ),
        );
        expect(requests, 1);
      });
    }
    test('successful submission returns tracking code files=$files', () async {
      final gateway = RecruitmentPublicGateway(
        service: RecruitmentService(
          apiClient: ApiClient(
            client: MockClient(
              (request) async => http.Response(
                jsonEncode({
                  'id': 'application-qa',
                  'campaign_id': 'campaign-qa',
                  'first_name': 'Awa',
                  'last_name': 'Test',
                  'email': 'awa@example.test',
                  'status': 'submitted',
                  'tracking_code': 'ESP-2026-TEST0001',
                }),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          ),
        ),
      );
      final result = await gateway.submitApplication(_draft(files));
      expect(result.publicTrackingCode, 'ESP-2026-TEST0001');
    });
  }
  for (final error in [
    const SocketException('disconnected'),
    http.ClientException('offline'),
    TimeoutException('timeout'),
  ]) {
    test(
      'transport failure ${error.runtimeType} keeps network category',
      () async {
        final gateway = RecruitmentPublicGateway(
          service: RecruitmentService(
            apiClient: ApiClient(
              client: MockClient((request) async => throw error),
            ),
          ),
        );
        await expectLater(
          gateway.submitApplication(_draft(false)),
          throwsA(
            isA<PublicRecruitmentFailure>().having(
              (e) => e.kind,
              'network',
              PublicRecruitmentFailureKind.network,
            ),
          ),
        );
      },
    );
  }
}
