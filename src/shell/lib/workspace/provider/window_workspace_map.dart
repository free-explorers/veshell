import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'window_workspace_map.g.dart';

/// Provide a map of WindowId to WorkspaceId
/// This provider is used to find the WorkspaceId of a WindowId
@Riverpod(keepAlive: true)
class WindowWorkspaceMap extends _$WindowWorkspaceMap {
  @override
  IMap<WindowId, WorkspaceId> build() {
    state = <WindowId, WorkspaceId>{}.toIMap();
    final screenList = ref.read(screenManagerProvider).screenIds;
    for (final screenId in screenList) {
      for (final workspaceId in ref.readScreen(screenId).workspaceList) {
        for (final windowId
            in ref.readWorkspace(workspaceId).tileableWindowList) {
          state = state.add(windowId, workspaceId);
        }
      }
    }

    return state;
  }

  void set(WindowId windowId, WorkspaceId workspaceId) {
    state = state.add(windowId, workspaceId);
  }

  void remove(WindowId windowId) {
    state = state.remove(windowId);
  }
}
