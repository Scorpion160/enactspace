import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/alumni/screens/alumni_screen.dart';
import 'package:frontend/features/alumni/screens/alumni_profile_detail_screen.dart';
import 'package:frontend/features/alumni/services/alumni_gateway.dart';
import 'package:frontend/features/alumni/models/alumni_profile_model.dart';
import 'package:frontend/features/alumni/services/alumni_error_message.dart';

class _FailingGateway implements AlumniGateway {
  int attempts = 0;
  final Object error;
  _FailingGateway(this.error);
  @override
  Future<AlumniCenterData> loadCenter({
    String? search,
    bool mentorsOnly = false,
    String mentorshipStatus = 'all',
  }) async {
    attempts++;
    throw error;
  }

  @override
  Future<AlumniProfileModel> getProfile(String profileId) async => throw error;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('network and server diagnostics stay outside the UI', () {
    for (final error in [
      http.ClientException('ClientNetworkError uri=https://private/api/alumni'),
      TimeoutException('SQL connection secret'),
      ApiException(statusCode: 500, message: 'UndefinedColumn SQL password'),
      StateError('private internal diagnostics'),
    ]) {
      final message = alumniErrorMessage(error);
      expect(message, isNot(contains('SQL')));
      expect(message, isNot(contains('https://')));
      expect(message, isNot(contains('secret')));
      expect(message, isNot(contains('ClientNetworkError')));
    }
    expect(
      alumniErrorMessage(ApiException(statusCode: 401, message: 'raw')),
      contains('session'),
    );
    expect(
      alumniErrorMessage(ApiException(statusCode: 403, message: 'raw')),
      contains('droits'),
    );
  });

  for (final width in [360.0, 1440.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('Alumni retry remains readable at $width $brightness', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final gateway = _FailingGateway(
          http.ClientException(
            'ClientNetworkError uri=https://private/api/alumni',
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(body: AlumniScreen(gateway: gateway)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('ClientNetworkError'), findsNothing);
        expect(find.textContaining('https://'), findsNothing);
        await tester.ensureVisible(find.text('Réessayer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Réessayer'));
        await tester.pumpAndSettle();
        expect(gateway.attempts, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('profile detail does not leak server errors', (tester) async {
    final gateway = _FailingGateway(
      ApiException(statusCode: 500, message: 'UndefinedColumn private SQL'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AlumniProfileDetailScreen(profileId: 'missing', gateway: gateway),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('SQL'), findsNothing);
    expect(find.textContaining('Réessayez'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
