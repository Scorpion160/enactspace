import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recruitment/widgets/public/public_application_journey.dart';
import 'package:frontend/features/recruitment/widgets/public/public_application_field.dart';

void main() {
  const titles = [
    'Ton identité',
    'Ton parcours',
    'Tes motivations',
    'Tes disponibilités',
    'Tes documents',
    'Vérification',
  ];
  for (final width in [320.0, 390.0, 1024.0]) {
    for (final dark in [false, true]) {
      testWidgets('journey and answer card fit $width dark=$dark at large text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (var step = 0; step < 6; step++) {
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        PublicApplicationJourney(
                          campaignTitle:
                              'Une candidature pour construire ensemble des projets utiles',
                          currentStep: step,
                          titles: titles,
                        ),
                        const SizedBox(height: 24),
                        PublicApplicationQuestionCard(
                          number: 1,
                          total: 8,
                          requiredAnswer: true,
                          child: PublicApplicationField(
                            label:
                                'Quel changement aimerais-tu apporter dans ta communauté ?',
                            help:
                                'Tu peux décrire une situation et une première idée pour agir.',
                            child: TextFormField(minLines: 3, maxLines: 7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Étape ${step + 1} sur 6'), findsOneWidget);
          expect(find.text(titles[step]), findsOneWidget);
          for (final element in find.byType(Text).evaluate()) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.byWidget(element.widget),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
