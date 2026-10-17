import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/shared/ui/heritage_photo.dart';
import 'package:frontend/features/recruitment/widgets/public/recruitment_welcome.dart';

void main() {
  const photo = HeritagePhotoData(
    'haffe-2025-ecoute',
    'À Haffé, écouter pour mieux comprendre.',
  );
  testWidgets(
    'recruitment photos reveal captions and source only in the full view',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RecruitmentWelcome()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final photos = tester.widgetList<HeritagePhoto>(
        find.byType(HeritagePhoto),
      );
      expect(photos, hasLength(3));
      expect(photos.every((item) => !item.showCaption), isTrue);
      expect(find.text('Source : Photothèque Enactus ESP'), findsNothing);
      expect(find.text(photo.caption), findsNothing);
      final firstPhoto = find.byType(HeritagePhoto).first;
      await tester.ensureVisible(firstPhoto);
      await tester.tap(
        find.descendant(of: firstPhoto, matching: find.byType(InkWell)).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(photo.caption), findsOneWidget);
      expect(find.text('Source : Photothèque Enactus ESP'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Source : Photothèque Enactus ESP'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('other heritage screens retain their default captions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HeritagePhoto(photo: photo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(photo.caption), findsOneWidget);
    expect(find.text('Source : Photothèque Enactus ESP'), findsOneWidget);
  });
}
