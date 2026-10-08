import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/shared/layout/app_shell.dart';

void main() {
  const user = UserExperience(
    id: 'qa',
    email: 'qa@example.test',
    displayName: 'QA',
    status: 'active',
    gender: null,
    profileType: 'enacteur',
    roles: {'administrateur'},
    canReviewJoinRequests: true,
    canAccessRecruitment: true,
  );
  for (final entry in {
    '/recruitment': 'Recrutement',
    '/events': 'Événements',
  }.entries) {
    for (final width in [360.0, 384.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets(
            'Single line destination ${entry.key} $width $scale $dark',
            (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = Size(width, 844);
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
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
                    bottomNavigationBar: MobileBottomNavigation(
                      currentPath: entry.key,
                      userExperience: user,
                      unreadNotifications: 0,
                      unreadChatMessages: 0,
                      lateTasks: 0,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final label = find.text(entry.value);
              expect(label, findsOneWidget);
              final rich = find.descendant(
                of: label,
                matching: find.byType(RichText),
              );
              final paragraph = tester.renderObject<RenderParagraph>(rich);
              expect(paragraph.maxLines, 1);
              expect(paragraph.softWrap, isFalse);
              expect(paragraph.overflow, TextOverflow.ellipsis);
            },
          );
        }
      }
    }
  }
}
