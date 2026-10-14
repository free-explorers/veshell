import 'package:material_ui/material_ui.dart';

/// Shell-specific navigation intents.
///
/// Directional movement, activation and dismissal deliberately reuse Flutter's
/// own intents ([DirectionalFocusIntent], [ActivateIntent], [DismissIntent]) so
/// the shell's hotkeys drive the framework focus system: a configured key moves
/// focus through focusable widgets, activates the focused control and dismisses
/// the topmost overlay. Contexts that are still index-based (the workspace and
/// tileable lists) register an override for the same intent; contexts that are
/// focus-based (the overview and the Helm) let the framework handle it.
///
/// The intents below are the operations the framework has no vocabulary for.

/// A direction on the shell's spatial grid.
enum NavigationDirection { up, down, left, right }

/// Moves the selection/focus in [direction] within the current context.
///
/// This stays a shell intent rather than Flutter's `DirectionalFocusIntent`
/// because text fields register their own handler for that intent (to keep the
/// arrows for cursor movement), which would shadow the workspace/tileable
/// handlers whenever the launcher search field holds focus. Focus-based
/// contexts handle [NavigateIntent] by delegating to the framework traversal
/// (`FocusNode.focusInDirection`), so the behaviour is the framework's while
/// the binding stays ours.
class NavigateIntent extends Intent {
  ///
  const NavigateIntent(this.direction);

  /// The direction to move the selection in.
  final NavigationDirection direction;
}

/// Moves the currently selected item in [direction] within the current
/// context: horizontally the selected tileable is reordered in its workspace;
/// vertically the selected tileable is sent to the workspace above/below.
class MoveIntent extends Intent {
  ///
  const MoveIntent(this.direction);

  /// The direction to move the selected item in.
  final NavigationDirection direction;
}

/// Goes up to the parent of the current context (the parent directory in the
/// file explorer).
class ParentIntent extends Intent {
  ///
  const ParentIntent();
}

/// Closes the currently focused item (a tileable).
class CloseIntent extends Intent {
  ///
  const CloseIntent();
}

/// Cycles to the next/previous item of a context-owned set (search modes,
/// content tabs).
class CycleIntent extends Intent {
  ///
  const CycleIntent({required this.forward});

  /// Whether to cycle forward (`true`) or backward (`false`).
  final bool forward;
}
