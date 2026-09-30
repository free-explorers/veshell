import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/overview/model/overview.dart';
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
      windowList: <EphemeralWindowId>[].lock,
      isDisplayed: false,
    );
  }

  /// Toggle visibility of the overview
  void toggle() {
    final isDisplayed = !state.isDisplayed;
    state = state.copyWith(
      isDisplayed: isDisplayed,
      focusedWindowId: isDisplayed
          ? resolveOverviewFocusedWindow(
              state.windowList,
              state.focusedWindowId,
            )
          : state.focusedWindowId,
      // A hidden overview shows no preview slot, so drop the stale selection.
      selectedPath: isDisplayed ? state.selectedPath : null,
    );
  }

  /// Shows the overview focused on [windowId], bringing it into view.
  void show(EphemeralWindowId windowId) {
    if (!state.windowList.contains(windowId)) {
      return;
    }
    state = state.copyWith(isDisplayed: true, focusedWindowId: windowId);
  }

  /// Hides the overview.
  void hide() {
    if (!state.isDisplayed) {
      return;
    }
    state = state.copyWith(isDisplayed: false, selectedPath: null);
  }

  /// Switches the search engine to [searchMode].
  void setSearchMode(SearchMode searchMode) {
    if (state.searchMode == searchMode) {
      return;
    }
    state = state.copyWith(searchMode: searchMode);
  }

  /// Selects [path] as the preview target, or clears it when `null`.
  void selectPath(DirectoryPath? path) {
    if (state.selectedPath == path) {
      return;
    }
    state = state.copyWith(selectedPath: path);
  }

  /// Selects [windowId] as the overview's displayed window.
  void focusWindow(EphemeralWindowId windowId) {
    if (!state.windowList.contains(windowId) ||
        state.focusedWindowId == windowId) {
      return;
    }
    state = state.copyWith(focusedWindowId: windowId);
  }

  /// Start an new Ephemeral Application
  void startEphemeralApplication(LocalizedDesktopEntry entry) {
    final windowId = ref
        .read(windowManagerProvider.notifier)
        .createEphemeralWindowForDesktopEntry(entry, state.screenId);

    state = state.copyWith(
      windowList: state.windowList.add(windowId),
      focusedWindowId: windowId,
    );

    unawaited(
      ref.read(ephemeralWindowStateProvider(windowId).notifier).launchSelf(),
    );
  }

  void removeWindow(EphemeralWindowId windowId) {
    final windowList = state.windowList.remove(windowId);
    state = state.copyWith(
      windowList: windowList,
      focusedWindowId: resolveOverviewFocusedWindow(
        windowList,
        state.focusedWindowId,
      ),
    );
  }
}

/// The window the overview should display for [windowList]: [focused] while it
/// is still present, otherwise the first remaining window (or `null`).
EphemeralWindowId? resolveOverviewFocusedWindow(
  IList<EphemeralWindowId> windowList,
  EphemeralWindowId? focused,
) {
  if (focused != null && windowList.contains(focused)) {
    return focused;
  }
  return windowList.isEmpty ? null : windowList.first;
}
