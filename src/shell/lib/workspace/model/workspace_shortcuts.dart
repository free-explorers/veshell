import 'package:material_ui/material_ui.dart';

/// An intent to focus the left tileable in workspace.
class FocusLeftTileableIntent extends Intent {
  ///
  const FocusLeftTileableIntent();
}

/// An intent to focus the right tileable in workspace.
class FocusRightTileableIntent extends Intent {
  ///
  const FocusRightTileableIntent();
}

/// An intent to move the current tileable one slot to the left.
class ReorderLeftTileableIntent extends Intent {
  ///
  const ReorderLeftTileableIntent();
}

/// An intent to move the current tileable one slot to the right.
class ReorderRightTileableIntent extends Intent {
  ///
  const ReorderRightTileableIntent();
}

/// An intent to close the current tileable.
class CloseTileableIntent extends Intent {
  ///
  const CloseTileableIntent();
}
