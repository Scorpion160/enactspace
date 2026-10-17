import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Multiple shell Navigators may emit a root "cannot pop" notification after
/// a modal closes. Preserve the routed detail stack in Android's back state.
bool handleAppNavigationNotification(
  GoRouter router,
  NavigationNotification notification,
) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    unawaited(
      SystemNavigator.setFrameworkHandlesBack(
        notification.canHandlePop || router.canPop(),
      ),
    );
  }
  return true;
}

void returnToPreviousPage(BuildContext context, String fallbackPath) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(fallbackPath);
    }
  } else {
    Navigator.of(context).maybePop();
  }
}

class AppBackButton extends StatelessWidget {
  final String fallbackPath;
  const AppBackButton({super.key, required this.fallbackPath});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Retour',
    icon: const Icon(Icons.arrow_back_rounded),
    onPressed: () => returnToPreviousPage(context, fallbackPath),
  );
}

/// Advertises nested detail navigation to Android before a system back event.
class AppBackScope extends StatelessWidget {
  final String? fallbackPath;
  final Widget child;
  const AppBackScope({
    super.key,
    required this.fallbackPath,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    return PopScope<Object?>(
      canPop: fallbackPath == null || router == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && router != null && fallbackPath != null) {
          returnToPreviousPage(context, fallbackPath!);
        }
      },
      child: child,
    );
  }
}
