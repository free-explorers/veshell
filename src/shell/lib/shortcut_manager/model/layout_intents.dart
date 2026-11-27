import 'package:material_ui/material_ui.dart';

/// An intent to show [delta] more tiles side by side in the focused
/// workspace (fewer when negative), never fewer than one.
class ChangeVisibleTileCountIntent extends Intent {
  ///
  const ChangeVisibleTileCountIntent(this.delta);

  /// How many tiles to add to the visible row; negative to remove.
  final int delta;
}

/// An intent to split the focused screen's monitor into [delta] more screens
/// (fewer when negative), never fewer than one.
class ChangeScreenCountIntent extends Intent {
  ///
  const ChangeScreenCountIntent(this.delta);

  /// How many screens to add to the monitor; negative to remove.
  final int delta;
}

/// An intent to toggle zen mode on the focused screen: its panels slide out,
/// leaving their selection lines in view.
class ToggleZenModeIntent extends Intent {
  ///
  const ToggleZenModeIntent();
}
