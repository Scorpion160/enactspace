import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/models/chat_models.dart';
import 'package:frontend/features/chat/services/chat_gateway.dart';
import 'package:frontend/features/chat/widgets/chat_attachment_card.dart';
import 'package:frontend/core/brand/enact_brand_lockup.dart';

class _Gateway implements ChatGateway {
  int calls = 0;
  bool fail = false;
  @override
  Future<Uint8List> loadMediaBytes(String url) async {
    calls++;
    if (fail) { throw Exception('Network'); }
    return Uint8List.fromList([1, 2, 3]);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatMessageModel _message(String type) => ChatMessageModel.fromJson({
  'id': 'attachment', 'thread_id': 'thread', 'author_id': 'sender',
  'message_type': type, 'content': 'Une légende',
  'attachment_url': '/api/files/private/download',
  'attachment_name': type == 'document' ? 'rapport.pdf' : 'photo.png',
  'attachment_size_bytes': 2048,
});

void main() {
  testWidgets('private attachments load only on request and offer opening', (tester) async {
    final gateway = _Gateway();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      ChatAttachmentCard(gateway: gateway, message: _message('document')))));
    expect(gateway.calls, 0);
    expect(find.text('rapport.pdf'), findsOneWidget);
    await tester.tap(find.text('Télécharger'));
    await tester.pumpAndSettle();
    expect(gateway.calls, 1);
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.byTooltip('Enregistrer'), findsOneWidget);
    expect(find.text('/api/files/private/download'), findsNothing);
  });

  testWidgets('failed downloads can be retried without losing the caption', (tester) async {
    final gateway = _Gateway()..fail = true;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      ChatAttachmentCard(gateway: gateway, message: _message('image')))));
    await tester.tap(find.text('Télécharger'));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Une légende'), findsOneWidget);
    gateway.fail = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(gateway.calls, 2);
    expect(find.text('Ouvrir'), findsOneWidget);
  });

  testWidgets('the two brands fit a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: EnactBrandLockup())));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

