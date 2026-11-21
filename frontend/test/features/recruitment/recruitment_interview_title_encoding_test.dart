import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interview headings remain valid French UTF-8', () {
    final sourceFile = File(
      'lib/features/recruitment/widgets/internal/'
      'recruitment_interview_preparation.dart',
    );
    final source = utf8.decode(
      sourceFile.readAsBytesSync(),
      allowMalformed: false,
    );

    expect(source, contains('Entretiens en pr\u00e9paration'));
    expect(source, contains('Mes entretiens \u00e0 pr\u00e9parer'));
    expect(source, isNot(contains('Entretiens en pr?paration')));
    expect(source, isNot(contains('Mes entretiens ? pr?parer')));
    expect(source, isNot(contains('\uFFFD')));
  });
}
