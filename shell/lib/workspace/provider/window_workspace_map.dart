import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/provider/window.manager.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'window_workspace_map.g.dart';

/// Provide a map of WindowId to WorkspaceId
/// This provider is used to find the WorkspaceId of a WindowId
@Riverpod(keepAlive: true)
class WindowWorkspaceMap extends _$WindowWorkspaceMap {
  @override
  IMap<WindowId, WorkspaceId> build() {
    return IMap();
  }

  void set(WindowId windowId, WorkspaceId workspaceId) {
    state = state.add(windowId, workspaceId);
  }
}
