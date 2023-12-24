import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.model.dart';
import 'package:shell/manager/window/window.manager.dart';

part 'workspace.provider.g.dart';

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

/// Provide the current Screen to all his childrens
@Riverpod(dependencies: [])
WorkspaceId currentWorkspaceId(CurrentWorkspaceIdRef ref) {
  // This provider is instentatied in Children Scope
  throw Exception('currentWorkspaceId was not initialized');
}

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
