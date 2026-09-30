import 'package:material_ui/material_ui.dart';

/// An intent to focus the workspace above.
class FocusWorkspaceAboveIntent extends Intent {
  ///
  const FocusWorkspaceAboveIntent();
}

/// An intent to focus the workspace below.
class FocusWorkspaceBelowIntent extends Intent {
  ///
  const FocusWorkspaceBelowIntent();
}

/// An intent to move the current workspace one slot above.
class ReorderWorkspaceAboveIntent extends Intent {
  ///
  const ReorderWorkspaceAboveIntent();
}

/// An intent to move the current workspace one slot below.
class ReorderWorkspaceBelowIntent extends Intent {
  ///
  const ReorderWorkspaceBelowIntent();
}

/// An intent to toggle the overview.
class ToggleOverviewIntent extends Intent {
  ///
  const ToggleOverviewIntent();
}

/// dump debug focus treee.
class DumpDebugFocusTree extends Intent {
  ///
  const DumpDebugFocusTree();
}

/// An intent to toggle the overview.
class ToggleDevToolsIntent extends Intent {
  ///
  const ToggleDevToolsIntent();
}
