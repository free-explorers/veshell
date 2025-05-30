import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_display_mode.g.dart';

enum WorkspaceDisplayMode { hybrid, category, application }

@riverpod
WorkspaceDisplayMode CurrentWorkspaceDisplayMode(Ref ref) {
  return WorkspaceDisplayMode.hybrid;
}
