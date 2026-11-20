import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/shared/ui/app_back_button.dart';

GoRouter routerFor(String initial, {bool twoShells = false}) {
  final routes = <RouteBase>[
    ShellRoute(
      builder: (context, state, child) => AppBackScope(
        fallbackPath: state.uri.path.split('/').length > 2 ? '/archives' : null,
        child: Scaffold(body: child),
      ),
      routes: [
        GoRoute(
          path: '/archives',
          builder: (context, state) => Column(
            children: [
              const Text('Collection'),
              TextButton(
                onPressed: () => context.push('/archives/projects/shery'),
                child: const Text('Ouvrir SHERY'),
              ),
            ],
          ),
          routes: [
            GoRoute(
              path: 'projects/:id',
              builder: (context, state) => Column(
                children: [
                  const Text('Fiche SHERY'),
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const Dialog(child: Text('Dossier PDF')),
                    ),
                    child: const Text('Lire PDF'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  ];
  return GoRouter(
    initialLocation: initial,
    routes: twoShells
        ? [
            ShellRoute(
              builder: (context, state, child) => child,
              routes: routes,
            ),
          ]
        : routes,
  );
}

void main() {
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('Android knows the nested detail can handle back', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final router = routerFor('/archives/projects/shery');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        onNavigationNotification: (notification) =>
            handleAppNavigationNotification(router, notification),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fiche SHERY'), findsOneWidget);
    expect(
      calls
          .where((c) => c.method == 'SystemNavigator.setFrameworkHandlesBack')
          .last
          .arguments,
      isTrue,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Collection'), findsOneWidget);
    expect(calls.where((c) => c.method == 'SystemNavigator.pop'), isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('system back closes the PDF before leaving the detail', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final router = routerFor('/archives');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        onNavigationNotification: (notification) =>
            handleAppNavigationNotification(router, notification),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir SHERY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lire PDF'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Dossier PDF'), findsNothing);
    expect(find.text('Fiche SHERY'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Collection'), findsOneWidget);
    expect(calls.where((c) => c.method == 'SystemNavigator.pop'), isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('root collection keeps normal system exit behavior', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final router = routerFor('/archives');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        onNavigationNotification: (notification) =>
            handleAppNavigationNotification(router, notification),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      calls
          .where((c) => c.method == 'SystemNavigator.setFrameworkHandlesBack')
          .last
          .arguments,
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'SystemNavigator.pop'), hasLength(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('two nested shells keep native back after explicit modal close', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final router = routerFor('/archives', twoShells: true);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        onNavigationNotification: (notification) =>
            handleAppNavigationNotification(router, notification),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir SHERY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lire PDF'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Dossier PDF'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Fiche SHERY'), findsOneWidget);
    expect(
      calls
          .where((c) => c.method == 'SystemNavigator.setFrameworkHandlesBack')
          .last
          .arguments,
      isTrue,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Collection'), findsOneWidget);
    expect(
      calls
          .where((c) => c.method == 'SystemNavigator.setFrameworkHandlesBack')
          .last
          .arguments,
      isFalse,
    );
    expect(calls.where((c) => c.method == 'SystemNavigator.pop'), isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
