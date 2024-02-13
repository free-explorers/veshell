// ignore_for_file: constant_identifier_names

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/window/model/window.dart';
import 'package:shell/window/provider/window.manager.dart';
import 'package:shell/window/provider/window_state.dart';
import 'package:shell/workspace/model/workspace.dart';
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
class WorkspaceState extends _$WorkspaceState {
  @override
  Workspace build(WorkspaceId workspaceId) {
    throw Exception('Workspace $workspaceId not found');
  }

  void initialize(Workspace workspace) {
    state = workspace;
  }

  void reorderWindowList(IList<String> newWindowList) {
    // first check if the list contain the same elements
    // then check if the elements are in different order
    if (!state.tileableWindowList.equalItems(newWindowList) &&
        state.tileableWindowList.length == newWindowList.length &&
        state.tileableWindowList
            .every((element) => newWindowList.contains(element))) {
      state = state.copyWith(
        tileableWindowList: newWindowList,
        focusedIndex:
            newWindowList.indexOf(state.tileableWindowList[state.focusedIndex]),
      );
    }
  }

  Future<void> addWindow(WindowId windowId) async {
    return insertWindow(windowId, state.tileableWindowList.length);
  }

  Future<void> insertWindow(WindowId windowId, int index) async {
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
    );
    ref
        .read(windowWorkspaceMapProvider.notifier)
        .set(windowId, state.workspaceId);
  }

  Future<void> removeWindow(WindowId windowId) async {
    final newWindowList = state.tileableWindowList.remove(windowId);
    state = state.copyWith(
      tileableWindowList: newWindowList,
      category: state.forcedCategory ?? await _determineCategory(newWindowList),
    );
  }

  void closeWindow(PersistentWindow window) {
    if (window.surfaceId != null) {
      ref.read(windowManagerProvider.notifier).closeWindow(window.windowId);
    } else {
      removeWindow(window.windowId);
    }
  }

  void setFocusedIndex(int index) {
    state = state.copyWith(
      focusedIndex: index,
    );
  }

  Future<WorkspaceCategory?> _determineCategory(
    IList<String> tileableWindowList,
  ) async {
    final appIdList = tileableWindowList
        .map(
          (windowId) => ref.read(
            windowStateProvider(windowId).select((value) => value.appId),
          ),
        )
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
