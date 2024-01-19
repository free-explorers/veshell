import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/provider/window.manager.dart';
import 'package:shell/workspace/model/workspace.dart';
import 'package:shell/workspace/provider/current_workspace_id.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';

part 'workspace_state.g.dart';

/// Typedef for WindowId
typedef WorkspaceId = String;

/// Workspace provider
@riverpod
class WorkspaceState extends _$WorkspaceState {
  late final KeepAliveLink _keepAliveLink;

  @override
  Workspace build(WorkspaceId workspaceId) {
    throw Exception('Workspace $workspaceId not found');
  }

  void initialize(Workspace workspace) {
    _keepAliveLink = ref.keepAlive();
    state = workspace;
  }

  void addWindow(WindowId windowId) {
    final windowWorkspaceMap = ref.read(windowWorkspaceMapProvider);
    if (windowWorkspaceMap.containsKey(windowId)) {
      ref
          .read(workspaceStateProvider(windowWorkspaceMap[windowId]!).notifier)
          .removeWindow(windowId);
    }
    state = state.copyWith(
      tileableWindowList: state.tileableWindowList.add(windowId),
    );
    ref
        .read(windowWorkspaceMapProvider.notifier)
        .set(windowId, state.workspaceId);
  }

  void removeWindow(WindowId windowId) {
    state = state.copyWith(
      tileableWindowList: state.tileableWindowList.remove(windowId),
    );
  }

  void setFocusedIndex(int index) {
    state = state.copyWith(
      focusedIndex: index,
    );
  }
}
