import 'package:flutter/material.dart';

/// InheritedWidget to provide a monitor Name throughout the widget tree
class CurrentMonitorName extends InheritedWidget {
  /// Creates a ScreenIdProvider with the given monitor Name.
  const CurrentMonitorName({
    required this.name,
    required super.child,
    super.key,
  });

  /// The monitor Name being provided to descendant widgets.
  final String name;

  /// Gets the monitor Name from the nearest ScreenIdProvider ancestor.
  static String of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<CurrentMonitorName>();
    if (provider == null) {
      throw FlutterError('ScreenIdProvider not found in the widget tree');
    }
    return provider.name;
  }

  @override
  bool updateShouldNotify(CurrentMonitorName oldWidget) =>
      name != oldWidget.name;
}
