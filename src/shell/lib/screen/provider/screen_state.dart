import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:uuid/uuid.dart';

part 'screen_state.g.dart';

/// Screen provider
@riverpod
@JsonPersist()
class ScreenState extends _$ScreenState {
  String get persistKey => 'screen_$screenId';

  KeepAliveLink? _keepAliveLink;
  final _workspaceListenerMap =
      <WorkspaceId, ProviderSubscription<Workspace>>{};
  @override
  Screen build(ScreenId screenId) {
    _keepAliveLink = ref.keepAlive();
    final storage = ref.watch(persistentStorageStateProvider).requireValue;

    persist(
      key: persistKey,
      storage: storage,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );

    if (stateOrNull != null) {
      state = stateOrNull!;
    } else {
      state = Screen(
        screenId: screenId,
        workspaceList: IList([const Uuid().v4()]),
        selectedIndex: 0,
      );
    }
/*     state = stateOrNull ??
        Screen(
          screenId: screenId,
          workspaceList: IList([const Uuid().v4()]),
          selectedIndex: 0,
        ); */
// When the last workspace got a new window open in it
    // we create a new blank workspace
    listenSelf((prev, next) {
      if (next.workspaceList == prev?.workspaceList) return;
      for (final element in _workspaceListenerMap.values) {
        element.close();
      }
      _workspaceListenerMap.clear();
      for (final workspaceId in next.workspaceList) {
        _listenToWorkspaceChanges(workspaceId);
      }
    });

    return state;
  }

  Future<void> delete() async {
    _keepAliveLink?.close();
    for (final workspaceId in state.workspaceList) {
      await ref.read(workspaceStateProvider(workspaceId).notifier).delete();
    }
    await ref
        .read(persistentStorageStateProvider)
        .requireValue
        .delete(persistKey);
    ref.invalidateSelf();
  }

  /// Listen to workspace changes in order to always have a blank workspace
  /// at the end of the list
  void _listenToWorkspaceChanges(WorkspaceId workspaceId) {
    print('Listening to workspace changes for $workspaceId');
    if (_workspaceListenerMap.containsKey(workspaceId)) {
      return;
    }
    final workspaceListener =
        ref.listen(workspaceStateProvider(workspaceId), (_, workspace) {
      print('Workspace $workspaceId changed');
      final isLast = state.workspaceList.last == workspaceId;
      final isBeforeLast = state.workspaceList.length > 1 &&
          state.workspaceList[state.workspaceList.length - 2] == workspaceId;

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
        // Just delay the remove call to ensure that
        // a window is not being transfered
        final workspaceIdToCheck = state.workspaceList.last;
        Future.delayed(Duration.zero, () {
          if (ref
              .read(workspaceStateProvider(workspaceIdToCheck))
              .tileableWindowList
              .isEmpty) {
            removeWorkspace(workspaceIdToCheck);
            ref
                .read(workspaceStateProvider(workspaceIdToCheck).notifier)
                .delete();
          }
        });
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
    if (!state.workspaceList.contains(workspaceId)) return;
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
    final workspaceId = const Uuid().v4();
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

  void setCustomLabel(String? label) {
    state = state.copyWith(label: label);
  }
}
