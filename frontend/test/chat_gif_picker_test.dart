import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/widgets/chat_gif_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog provides forty actual GIF animations', () async {
    final items = await loadChatGifs();
    expect(items.length, 40);
    expect(items.map((item) => item.id).toSet().length, 40);
    for (final gif in items) {
      expect(String.fromCharCodes(gif.bytes.take(3)), 'GIF');
      expect(gif.bytes.length, greaterThan(100));
    }
  });

  testWidgets('GIF search selects an internal item and retains import', (
    tester,
  ) async {
    ChatGif? selected;
    var imports = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatGifPicker(
            onSelected: (gif) => selected = gif,
            onImport: () => imports++,
          ),
        ),
      ),
    );
    await tester.runAsync(loadChatGifs);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'bravo');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('reaction-6')));
    expect(selected?.label, 'Bravo !');
    await tester.tap(find.byTooltip('Importer un GIF'));
    expect(imports, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
