import 'package:material_ui/material_ui.dart';

/// InheritedWidget to provide a screen ID throughout the widget tree
class CurrentScreenId extends InheritedWidget {
  /// Creates a ScreenIdProvider with the given screen ID.
  const CurrentScreenId({
    required this.screenId,
    required super.child,
    super.key,
  });

  /// The screen ID being provided to descendant widgets.
  final String screenId;

  /// Gets the screen ID from the nearest ScreenIdProvider ancestor.
  static String of(BuildContext context) {
    final screenId = maybeOf(context);
    if (screenId == null) {
      throw FlutterError('ScreenIdProvider not found in the widget tree');
    }
    return screenId;
  }

  /// Like [of], but returns `null` when there is no provider ancestor.
  static String? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrentScreenId>()?.screenId;

  @override
  bool updateShouldNotify(CurrentScreenId oldWidget) =>
      screenId != oldWidget.screenId;
}
