import 'package:flutter/widgets.dart';

/// Whether the enclosing workspace may hold the keyboard: it is the selected
/// workspace of the screen that owns the keyboard, and that screen's overview
/// is closed.
///
/// The selected tile re-takes the keyboard when this turns true. Flutter's own
/// restore cannot be relied on there: the workspace's focus gates are still
/// closed when the compositor hands its monitor the keyboard back, and a
/// restore through closed gates drops the focus history, stopping at the
/// workspace scope instead of reaching the tile.
class WorkspaceFocusable extends InheritedWidget {
  const WorkspaceFocusable({
    required this.canFocus,
    required super.child,
    super.key,
  });

  final bool canFocus;

  /// Whether the nearest workspace may hold the keyboard; `true` outside a
  /// workspace (a tile shown on its own, in tests or previews).
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WorkspaceFocusable>()
          ?.canFocus ??
      true;

  @override
  bool updateShouldNotify(WorkspaceFocusable oldWidget) =>
      canFocus != oldWidget.canFocus;
}
