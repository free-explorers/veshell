import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.dart';
import 'package:shell/workspace/model/workspace.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:uuid/uuid.dart';

part 'screen_state.g.dart';

/// Screen provider
@riverpod
class ScreenState extends _$ScreenState {
  late final KeepAliveLink _keepAliveLink;
  final _uuidGenerator = const Uuid();
  final _workspaceListenerMap =
      <WorkspaceId, ProviderSubscription<Workspace>>{};
  @override
  Screen build(ScreenId screenId) {
    throw Exception('Screen $screenId not found');
  }

  void initialize(Screen screen) {
    _keepAliveLink = ref.keepAlive();
    state = screen;

    // When the last workspace got a new window open in it
    // we create a new blank workspace
    ProviderSubscription<Workspace>? lastWorkspaceListenerSubscription;
    ref.listenSelf((prev, next) {
      final newWorkspaceList = prev == null
          ? next.workspaceList
          : next.workspaceList.where(
              (workspaceId) => !prev.workspaceList.contains(workspaceId),
            );

      final removedWorkspaceList = prev == null
          ? const <WorkspaceId>[]
          : prev.workspaceList.where(
              (workspaceId) => !next.workspaceList.contains(workspaceId),
            );

      for (final workspaceId in newWorkspaceList) {
        _listenToWorkspaceChanges(workspaceId);
      }

      for (final workspaceId in removedWorkspaceList) {
        _workspaceListenerMap[workspaceId]?.close();
        _workspaceListenerMap.remove(workspaceId);
      }
    });
  }

  /// Listen to workspace changes in order to always have a blank workspace
  /// at the end of the list
  void _listenToWorkspaceChanges(WorkspaceId workspaceId) {
    if (_workspaceListenerMap.containsKey(workspaceId)) {
      return;
    }
    final workspaceListener =
        ref.listen(workspaceStateProvider(workspaceId), (_, workspace) {
      final isLast = state.workspaceList.last == workspaceId;
      final isBeforeLast = state.workspaceList.length > 1 &&
          state.workspaceList[state.workspaceList.length - 2] == workspaceId;
      final isFocused =
          state.selectedIndex == state.workspaceList.indexOf(workspaceId);
      // If the last workspace got a new window open in it
      // we create a new blank workspace
      if (isLast && workspace.tileableWindowList.isNotEmpty) {
        createNewWorkspace();
      }

      // if the before last workspace become empty
      // and the last empty workspace is not focused
      // remove the last empty workspace
      if (isBeforeLast &&
          workspace.tileableWindowList.isEmpty &&
          state.selectedIndex != state.workspaceList.length - 1) {
        removeWorkspace(state.workspaceList.last);
      }
    });
    _workspaceListenerMap[workspaceId] = workspaceListener;
  }

  void insertWorkspace(WorkspaceId workspaceId, int index) {
    final newSelectedIndex = state.selectedIndex >= index
        ? state.selectedIndex + 1
        : state.selectedIndex;
    state = state.copyWith(
      workspaceList: state.workspaceList.insert(index, workspaceId),
      selectedIndex: newSelectedIndex,
    );
  }

  void removeWorkspace(WorkspaceId workspaceId) {
    final removedIndex = state.workspaceList.indexOf(workspaceId);
    final newSelectedIndex = state.selectedIndex > removedIndex
        ? state.selectedIndex - 1
        : state.selectedIndex;
    state = state.copyWith(
      workspaceList: state.workspaceList.remove(workspaceId),
      selectedIndex: newSelectedIndex,
    );
  }

  void updateWorkspaceList(IList<WorkspaceId> workspaceList) {
    final newSelectedIndex =
        workspaceList.indexOf(state.workspaceList[state.selectedIndex]);
    state = state.copyWith(
      workspaceList: workspaceList,
      selectedIndex: newSelectedIndex,
    );
  }

  WorkspaceId createNewWorkspace() {
    final workspaceId = _uuidGenerator.v4();

    ref.read(workspaceStateProvider(workspaceId).notifier).initialize(
          Workspace(
            workspaceId: workspaceId,
            tileableWindowList: <String>[].lock,
            focusedIndex: 0,
          ),
        );
    state = state.copyWith(workspaceList: state.workspaceList.add(workspaceId));
    return workspaceId;
  }

  void selectWorkspace(int index) {
    if (index == state.selectedIndex) {
      return;
    }
    var newIndex = index;
    final previousIndex = state.selectedIndex;
    final previousWorkspaceId = state.workspaceList[previousIndex];
    final previousWorkspaceState =
        ref.read(workspaceStateProvider(previousWorkspaceId));
    if (previousWorkspaceId != state.workspaceList.last &&
        previousWorkspaceState.tileableWindowList.isEmpty &&
        state.workspaceList.length > 1) {
      state = state.copyWith(
        workspaceList: state.workspaceList.remove(previousWorkspaceId),
      );
      if (index > previousIndex) {
        newIndex--;
      }
    }
    state = state.copyWith(selectedIndex: newIndex);
  }

  void reorderWorkspace(int oldIndex, int newIndex) {
    final workspaceList = state.workspaceList;
    final workspaceId = workspaceList[oldIndex];
    state = state.copyWith(
      workspaceList:
          workspaceList.removeAt(oldIndex).insert(newIndex, workspaceId),
    );
  }
}
