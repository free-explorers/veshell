import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/overview/model/overview.dart';
import 'package:shell/overview/model/overview_content.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

part 'overview_state.g.dart';

@riverpod
class OverviewState extends _$OverviewState {
  @override
  Overview build(ScreenId screenId) {
    return Overview(
      screenId: screenId,
      contentList: <OverviewContent>[].lock,
      isDisplayed: false,
    );
  }

  /// Toggle visibility of the overview
  void toggle() {
    final isDisplayed = !state.isDisplayed;
    state = state.copyWith(
      isDisplayed: isDisplayed,
      // A hidden overview shows no preview slot, so drop the stale selection.
      selectedIndex: isDisplayed ? state.selectedIndex : null,
    );
  }

  /// Shows the overview focused on [windowId], bringing it into view.
  void show(EphemeralWindowId windowId) {
    final content = _windowContent(windowId);
    if (content == null) {
      return;
    }
    state = state.copyWith(
      isDisplayed: true,
      selectedContentId: content.contentId,
      selectedIndex: null,
    );
  }

  /// Hides the overview.
  void hide() {
    if (!state.isDisplayed) {
      return;
    }
    state = state.copyWith(isDisplayed: false, selectedIndex: null);
  }

  /// Switches the search engine to [searchMode], clearing the selection (the
  /// new mode has a different result list).
  void setSearchMode(SearchMode searchMode) {
    if (state.searchMode == searchMode) {
      return;
    }
    state = state.copyWith(searchMode: searchMode, selectedIndex: null);
  }

  /// Selects the result at [index], or clears the selection when `null`.
  ///
  /// In Files mode a non-null [index] also opens the entry in a preview tab:
  /// the selected preview is reused (its entry replaced in place), an existing
  /// tab for the same path is selected, or a new tab is appended.
  void selectIndex(int? index) {
    final entry = _entryForIndex(index);
    if (entry == null) {
      if (state.selectedIndex == index) {
        return;
      }
      state = state.copyWith(selectedIndex: index);
      return;
    }

    final selected = state.selectedContent;
    if (selected is PreviewOverviewContent) {
      if (state.selectedIndex == index && selected.entry == entry) {
        return;
      }
      state = state.copyWith(
        contentList: state.contentList.replaceFirst(
          from: selected,
          to: selected.copyWith(entry: entry),
        ),
        selectedIndex: index,
      );
      return;
    }

    final existing = _previewContentFor(entry);
    if (existing != null) {
      state = state.copyWith(
        contentList: state.contentList.replaceFirst(
          from: existing,
          to: existing.copyWith(entry: entry),
        ),
        selectedContentId: existing.contentId,
        selectedIndex: index,
      );
      return;
    }

    final content = OverviewContent.preview(
      id: state.nextContentId,
      entry: entry,
    );
    state = state.copyWith(
      contentList: state.contentList.add(content),
      selectedContentId: content.contentId,
      nextContentId: state.nextContentId + 1,
      selectedIndex: index,
    );
  }

  /// The entry at [index] in the active Files list, or `null` when [index] is
  /// null or the list is not (yet) available.
  FileEntry? _entryForIndex(int? index) {
    if (index == null || state.searchMode != SearchMode.file) {
      return null;
    }
    final entryList = ref.read(filteredEntryListProvider(state.screenId)).value;
    if (entryList == null || index < 0 || index >= entryList.length) {
      return null;
    }
    return entryList[index];
  }

  /// The open preview tab showing [entry]'s path, if any.
  PreviewOverviewContent? _previewContentFor(FileEntry entry) {
    for (final content in state.contentList) {
      if (content is PreviewOverviewContent &&
          content.entry.path == entry.path) {
        return content;
      }
    }
    return null;
  }

  /// The window content for [windowId], if it is open.
  WindowOverviewContent? _windowContent(EphemeralWindowId windowId) {
    for (final content in state.contentList) {
      if (content is WindowOverviewContent && content.windowId == windowId) {
        return content;
      }
    }
    return null;
  }

  /// Displays the content named by [contentId] (the Helm id selects the Helm).
  void selectContent(String contentId) {
    if (state.selectedContentId == contentId && state.selectedIndex == null) {
      return;
    }
    state = state.copyWith(selectedContentId: contentId, selectedIndex: null);
  }

  /// Selects [windowId] as the overview's displayed window.
  void focusWindow(EphemeralWindowId windowId) {
    final content = _windowContent(windowId);
    if (content == null) {
      return;
    }
    selectContent(content.contentId);
  }

  /// Selects the Helm dashboard as the overview's displayed slot.
  void selectHelm() {
    selectContent(helmContentId);
  }

  /// Closes the content named by [contentId], selecting its neighbour (or the
  /// Helm when nothing is left).
  void closeContent(String contentId) {
    final index = state.contentList.indexWhere(
      (content) => content.contentId == contentId,
    );
    if (index < 0) {
      return;
    }
    final contentList = state.contentList.removeAt(index);
    final selectedContentId = state.selectedContentId == contentId
        ? (contentList.isEmpty
              ? helmContentId
              : contentList[index.clamp(0, contentList.length - 1)].contentId)
        : state.selectedContentId;
    state = state.copyWith(
      contentList: contentList,
      selectedContentId: selectedContentId,
    );
  }

  /// Start an new Ephemeral Application
  void startEphemeralApplication(LocalizedDesktopEntry entry) {
    final windowId = ref
        .read(windowManagerProvider.notifier)
        .createEphemeralWindowForDesktopEntry(entry, state.screenId);

    final content = OverviewContent.window(windowId);
    state = state.copyWith(
      contentList: state.contentList.add(content),
      selectedContentId: content.contentId,
      selectedIndex: null,
    );

    unawaited(
      ref.read(ephemeralWindowStateProvider(windowId).notifier).launchSelf(),
    );
  }

  void removeWindow(EphemeralWindowId windowId) {
    final content = _windowContent(windowId);
    if (content == null) {
      return;
    }
    closeContent(content.contentId);
  }
}
