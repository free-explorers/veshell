// ignore_for_file: constant_identifier_names

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:hooks_riverpod/misc.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';

part 'workspace_state.g.dart';

/// Typedef for WindowId
typedef WorkspaceId = String;

/// Desktop categories
enum WorkspaceCategory {
  Game,
  Development,
  Video,
  Audio,
  AudioVideo,
  Graphics,
  Office,
  Science,
  Education,
  FileManager,
  InstantMessaging,
  Network,
  Settings,
  System,
  Utility,
}

enum MeaningfulApplicationCategory { IDE, WebBrowser, Player }

/// Workspace provider
@riverpod
@JsonPersist()
class WorkspaceState extends _$WorkspaceState {
  KeepAliveLink? _keepAliveLink;
  String get persistKey => 'workspace_$workspaceId';
  @override
  Workspace build(WorkspaceId workspaceId) {
    _keepAliveLink = ref.keepAlive();
    persist(
      key: persistKey,
      storage: ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );

    return stateOrNull?.copyWith(
          tileableWindowList: stateOrNull!.tileableWindowList.where(
            (tileableId) {
              try {
                ref.read(persistentWindowStateProvider(tileableId));
                return true;
              } catch (e) {
                print(
                  'Failed to load persistentWindowsState while restoring workspace state',
                );
                return false;
              }
            },
          ).toIList(),
        ) ??
        Workspace(
          workspaceId: workspaceId,
          tileableWindowList: <PersistentWindowId>[].lock,
          selectedIndex: 0,
          visibleLength: 1,
        );
  }

  Future<void> delete() async {
    final storage = ref.read(persistentStorageStateProvider).requireValue;
    ref.onDispose(() {
      storage.delete(persistKey);
    });
    for (final windowId in state.tileableWindowList) {
      ref
          .read(persistentWindowStateProvider(windowId).notifier)
          .closeWindow(forceRemove: true);
    }
    _keepAliveLink?.close();
  }

  void reorderWindowList(IList<PersistentWindowId> newWindowList) {
    // first check if the list contain the same elements
    // then check if the elements are in different order
    if (!state.tileableWindowList.equalItems(newWindowList) &&
        state.tileableWindowList.length == newWindowList.length &&
        state.tileableWindowList
            .every((element) => newWindowList.contains(element))) {
      state = state.copyWith(
        tileableWindowList: newWindowList,
        selectedIndex: newWindowList
            .indexOf(state.tileableWindowList[state.selectedIndex]),
      );
    }
  }

  Future<void> addWindow(
    PersistentWindowId windowId, {
    bool selectWindow = false,
  }) async {
    return insertWindow(
      windowId,
      state.tileableWindowList.length,
      selectWindow: selectWindow,
    );
  }

  Future<void> insertWindow(
    PersistentWindowId windowId,
    int index, {
    bool selectWindow = false,
  }) async {
    final windowWorkspaceMap = ref.read(windowWorkspaceMapProvider);
    if (windowWorkspaceMap.containsKey(windowId)) {
      await ref
          .read(workspaceStateProvider(windowWorkspaceMap[windowId]!).notifier)
          .removeWindow(windowId);
    }
    final newWindowList = state.tileableWindowList.insert(index, windowId);
    state = state.copyWith(
      tileableWindowList: newWindowList,
      category: state.forcedCategory ?? await _determineCategory(newWindowList),
      selectedIndex: selectWindow ? index : state.selectedIndex,
    );
    ref
        .read(windowWorkspaceMapProvider.notifier)
        .set(windowId, state.workspaceId);
  }

  Future<void> removeWindow(PersistentWindowId windowId) async {
    final removedIsCurrentlyFocused =
        state.selectedIndex < state.tileableWindowList.length &&
            windowId == state.tileableWindowList[state.selectedIndex];
    final newWindowList = state.tileableWindowList.remove(windowId);

    var selectedIndex = state.selectedIndex;
    if (!removedIsCurrentlyFocused) {
      if (selectedIndex < state.tileableWindowList.length) {
        selectedIndex = newWindowList
            .indexOf(state.tileableWindowList[state.selectedIndex]);
      } else {
        selectedIndex--;
      }
    }
    state = state.copyWith(
      tileableWindowList: newWindowList,
      category: state.forcedCategory ?? await _determineCategory(newWindowList),
      selectedIndex: selectedIndex,
    );

    final workspaceId = ref.read(windowWorkspaceMapProvider).get(windowId);
    if (workspaceId != null && workspaceId == state.workspaceId) {
      ref.read(windowWorkspaceMapProvider.notifier).remove(windowId);
    }
  }

  void setSelectedIndex(int index) {
    state = state.copyWith(
      selectedIndex: index,
    );
  }

  void setVisibleLength(int length) {
    state = state.copyWith(
      visibleLength: length,
    );
  }

  Future<WorkspaceCategory?> _determineCategory(
    IList<PersistentWindowId> tileableWindowList,
  ) async {
    final appIdList = tileableWindowList
        .map(
          (windowId) => ref.read(
            persistentWindowStateProvider(windowId)
                .select((value) => value.properties.appId),
          ),
        )
        .whereNotNull()
        .toList();
    if (appIdList.isEmpty) return null;
    final categoryScoreMap = <WorkspaceCategory, int>{};

    for (final app in appIdList) {
      final workspaceCategoryCandidateList = <WorkspaceCategory>[];
      var multiplier = 1;
      final entry =
          await ref.read(localizedDesktopEntryForIdProvider(app).future);
      if (entry != null) {
        final categoriesString =
            entry.entries[DesktopEntryKey.categories.string];
        final appCategoryList =
            categoriesString != null ? categoriesString.split(';') : <String>[];
        for (final appCategory in appCategoryList) {
          final workspaceCategory = WorkspaceCategory.values.firstWhereOrNull(
            (workspaceCategory) => workspaceCategory.name == appCategory,
          );
          if (workspaceCategory != null) {
            workspaceCategoryCandidateList.add(workspaceCategory);
          }
          final meaningfulCategory =
              MeaningfulApplicationCategory.values.firstWhereOrNull(
            (meaningfulCategory) => meaningfulCategory.name == appCategory,
          );
          if (meaningfulCategory != null) {
            multiplier += 1;
          }
        }

        for (final workspaceCategoryCandidate
            in workspaceCategoryCandidateList) {
          if (categoryScoreMap.containsKey(workspaceCategoryCandidate)) {
            categoryScoreMap[workspaceCategoryCandidate] =
                categoryScoreMap[workspaceCategoryCandidate]! + 1 * multiplier;
          } else {
            categoryScoreMap[workspaceCategoryCandidate] = 1 * multiplier;
          }
        }
      }
    }
    MapEntry<WorkspaceCategory, int>? mostRatedCategoryEntry;
    for (final entry in categoryScoreMap.entries) {
      if (mostRatedCategoryEntry == null ||
          entry.value > mostRatedCategoryEntry.value) {
        mostRatedCategoryEntry = entry;
        mostRatedCategoryEntry = entry;
      }

      if (entry.value == mostRatedCategoryEntry.value &&
          WorkspaceCategory.values.indexOf(entry.key) <
              WorkspaceCategory.values.indexOf(mostRatedCategoryEntry.key)) {
        mostRatedCategoryEntry = entry;
      }
    }
    return mostRatedCategoryEntry?.key;
  }
}
