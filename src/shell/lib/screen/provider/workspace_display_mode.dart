import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

part 'workspace_display_mode.g.dart';

/// What a workspace button in the screen panel shows. The enum names are the
/// values stored under `theme.workspaceIcon`, in the order shown in the
/// picker.
///
/// A category fixed on a workspace (`Workspace.forcedCategory`) is shown
/// whatever the mode.
enum WorkspaceDisplayMode {
  /// The application's icon when the workspace holds a single application,
  /// the workspace category's icon otherwise. The default.
  hybrid,

  /// Always the workspace category's icon.
  category,

  /// Always the applications' icons: the button is split between the (up to
  /// four) most present applications, each showing the part of its own icon
  /// that falls in its share.
  application,
}

const workspaceDisplayModePath = 'theme.workspaceIcon';
const WorkspaceDisplayMode workspaceDisplayModeFallback =
    WorkspaceDisplayMode.hybrid;

/// The workspace display modes, in the order shown in the picker.
final List<String> workspaceDisplayModeChoices = [
  for (final mode in WorkspaceDisplayMode.values) mode.name,
];

/// The localized label for a workspace display mode setting string.
String workspaceDisplayModeLabel(AppLocalizations l10n, String value) =>
    switch (WorkspaceDisplayMode.values.asNameMap()[value]) {
      WorkspaceDisplayMode.category => l10n.workspaceIconCategory,
      WorkspaceDisplayMode.application => l10n.workspaceIconApplication,
      _ => l10n.workspaceIconHybrid,
    };

@riverpod
WorkspaceDisplayMode currentWorkspaceDisplayMode(Ref ref) {
  final value = ref.watch(jsonValueByPathProvider(workspaceDisplayModePath));
  return WorkspaceDisplayMode.values.asNameMap()[value] ??
      workspaceDisplayModeFallback;
}
