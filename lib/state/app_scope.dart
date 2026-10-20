import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Exposes the [AppState] to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  /// Creates the scope.
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  /// Returns the state and subscribes the caller to changes.
  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in the widget tree');
    return scope!.notifier!;
  }

  /// Returns the state without subscribing the caller to changes.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in the widget tree');
    return scope!.notifier!;
  }
}
