import 'package:flutter/material.dart';

/// A presentation can use production widgets without activating device services.
/// This marker never changes authentication, permissions, or API configuration.
class PreviewModeScope extends InheritedWidget {
  const PreviewModeScope({
    super.key,
    required super.child,
    this.services = const {},
  });
  final Map<Type, Object> services;

  static T? service<T extends Object>(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PreviewModeScope>()?.services[T]
          as T?;

  static bool active(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PreviewModeScope>() != null;

  static bool block(BuildContext context, [String? message]) {
    if (!active(context)) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ?? 'Cette action est présentée dans la démo. Aucun service réel n’est activé.',
        ),
      ),
    );
    return true;
  }

  @override
  bool updateShouldNotify(PreviewModeScope oldWidget) => false;
}
