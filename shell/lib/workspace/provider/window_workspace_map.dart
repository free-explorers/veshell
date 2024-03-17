import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/provider/persistent_json_by_folder.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'window_workspace_map.g.dart';

/// Provide a map of WindowId to WorkspaceId
/// This provider is used to find the WorkspaceId of a WindowId
@Riverpod(keepAlive: true)
class WindowWorkspaceMap extends _$WindowWorkspaceMap {
  @override
  IMap<WindowId, WorkspaceId> build() {
    final initialMap = <WindowId, WorkspaceId>{};
    final workspaceIdList = ref
        .read(persistentJsonByFolderProvider)
        .requireValue['Workspace']
        ?.keys;
    if (workspaceIdList != null) {
      for (final workspaceId in workspaceIdList) {
        final workspace = ref.read(workspaceStateProvider(workspaceId));
        for (final windowId in workspace.tileableWindowList) {
          initialMap[windowId] = workspaceId;
        }
      }
    }
    return initialMap.toIMap();
  }

  void set(WindowId windowId, WorkspaceId workspaceId) {
    state = state.add(windowId, workspaceId);
  }

  void remove(WindowId windowId) {
    state = state.remove(windowId);
  }
}
