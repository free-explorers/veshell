import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';
import 'package:shell/file_explorer/provider/file_opener.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/overview/provider/overview_search_text.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/settings/model/setting_search.dart';
import 'package:shell/settings/provider/settings_expanded_groups.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/shared/util/selection.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';

/// Focus handles shared between the overview's search field and its result
/// rows.
///
/// The overview behaves like a combobox: the search field keeps the keyboard
/// while filtering, and `Super+Down` (or a click) hands it to the result list;
/// `Super+Up` on the first row hands it back. Each row owns a `FocusNode`
/// (roving tab index), so assistive technology and the focus system see the
/// selected row rather than one opaque list.
class OverviewResultFocus {
  OverviewResultFocus({required this.searchNode});

  /// The search text field's node.
  final FocusNode searchNode;

  final Map<int, FocusNode> _rowNodes = <int, FocusNode>{};

  /// The focus node of the row at [index], created on first use.
  FocusNode rowNode(int index) => _rowNodes.putIfAbsent(
    index,
    () => FocusNode(debugLabel: 'OverviewRow$index'),
  );

  /// Whether any result row currently holds the keyboard focus.
  bool get hasRowFocus => _rowNodes.values.any((node) => node.hasFocus);

  /// Moves the keyboard focus to the row at [index].
  ///
  /// A row outside the built `ListView` window has no attached focus node yet,
  /// so the request is retried once after the scroll-into-view effect has built
  /// it. The retry only runs while a row still holds focus, so it never steals
  /// the keyboard back after the user moved on.
  void moveTo(int index) {
    rowNode(index).requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasRowFocus && !rowNode(index).hasFocus) {
        rowNode(index).requestFocus();
      }
    });
  }

  /// Returns the keyboard focus to the search field.
  void focusSearch() => searchNode.requestFocus();

  /// Disposes the row nodes. The search node is owned by its widget.
  void dispose() {
    for (final node in _rowNodes.values) {
      node.dispose();
    }
    _rowNodes.clear();
  }
}

/// The overview-level intent handlers.
///
/// It binds the standard intents to the overview's data, so the global
/// `navigate.*` bindings mean "work through the result list" here instead of
/// "work through workspaces/tileables". Placed above both the search engine and
/// the content pane so the directions act no matter which part of the overview
/// holds focus.
///
/// `Escape` resolves through the framework's `DismissIntent` binding (already
/// installed by `MaterialApp`), so a dialog or menu opened above the overview
/// wins; this action hides the overview only when nothing closer consumes it.
class OverviewShortcuts extends HookConsumerWidget {
  const OverviewShortcuts({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.tab, meta: true): CycleIntent(
          forward: true,
        ),
        SingleActivator(LogicalKeyboardKey.tab, meta: true, shift: true):
            CycleIntent(forward: false),
      },
      child: Actions(
        actions: {
          // Fallback for focus that is neither in the search pane nor in the
          // content pane: the vertical pair moves the result cursor and the
          // horizontal pair moves focus. It deliberately does not double as
          // "go to parent" / "activate" — those read as surprising on a
          // direction key.
          NavigateIntent: CallbackAction<NavigateIntent>(
            onInvoke: (intent) {
              switch (intent.direction) {
                case NavigationDirection.up:
                  moveOverviewSelection(ref, screenId, -1);
                case NavigationDirection.down:
                  moveOverviewSelection(ref, screenId, 1);
                case NavigationDirection.left:
                  primaryFocus?.focusInDirection(TraversalDirection.left);
                case NavigationDirection.right:
                  primaryFocus?.focusInDirection(TraversalDirection.right);
              }
              return null;
            },
          ),
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              ref.read(overviewStateProvider(screenId).notifier).hide();
              return null;
            },
          ),
          CycleIntent: CallbackAction<CycleIntent>(
            onInvoke: (intent) {
              cycleOverviewSearchMode(ref, screenId, intent.forward ? 1 : -1);
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

/// The number of results the active search mode offers on [screenId].
int overviewResultCount(WidgetRef ref, String screenId) {
  final searchText = ref.read(overviewSearchTextProvider(screenId));
  switch (ref.read(overviewStateProvider(screenId)).searchMode) {
    case SearchMode.application:
      return ref
              .read(appDrawerFilteredDesktopEntriesProvider(searchText))
              .value
              ?.length ??
          0;
    case SearchMode.file:
      return ref.read(filteredEntryListProvider(screenId)).value?.length ?? 0;
    case SearchMode.settings:
      return collectSettingVisibleRowList(
        ref.read(settingsPropertiesProvider),
        searchText,
        ref.read(settingsExpandedGroupsProvider).toSet(),
      ).length;
  }
}

/// Like [overviewResultCount], but **watches** the underlying providers so the
/// caller rebuilds when the active result list changes (used to focus the first
/// result once an async list has loaded).
int watchOverviewResultCount(WidgetRef ref, String screenId) {
  final searchText = ref.watch(overviewSearchTextProvider(screenId));
  final searchMode = ref.watch(
    overviewStateProvider(screenId).select((state) => state.searchMode),
  );
  switch (searchMode) {
    case SearchMode.application:
      return ref
              .watch(appDrawerFilteredDesktopEntriesProvider(searchText))
              .value
              ?.length ??
          0;
    case SearchMode.file:
      return ref.watch(filteredEntryListProvider(screenId)).value?.length ?? 0;
    case SearchMode.settings:
      return collectSettingVisibleRowList(
        ref.watch(settingsPropertiesProvider),
        searchText,
        ref.watch(settingsExpandedGroupsProvider).toSet(),
      ).length;
  }
}

/// Moves the overview selection by [delta] in the active result list.
void moveOverviewSelection(WidgetRef ref, String screenId, int delta) {
  final count = overviewResultCount(ref, screenId);
  if (count == 0) {
    return;
  }
  ref
      .read(overviewStateProvider(screenId).notifier)
      .selectIndex(
        nextSelectionIndex(
          currentIndex:
              ref.read(overviewStateProvider(screenId)).selectedIndex ?? -1,
          delta: delta,
          length: count,
        ),
      );
}

/// Launches the application at [index] as an ephemeral window and resets the
/// search.
void activateOverviewApplicationAt(WidgetRef ref, String screenId, int index) {
  final searchText = ref.read(overviewSearchTextProvider(screenId));
  final entryList = ref
      .read(appDrawerFilteredDesktopEntriesProvider(searchText))
      .value;
  if (entryList == null || index < 0 || index >= entryList.length) {
    return;
  }
  ref
      .read(overviewStateProvider(screenId).notifier)
      .startEphemeralApplication(entryList[index]);
  clearOverviewSearch(ref, screenId);
}

/// Activates the selected entry in the active search mode.
///
/// With nothing explicitly selected, the first result is activated, so a search
/// can be accepted with `Enter` without moving the selection first (the
/// per-mode guards no-op on an empty list).
void activateOverviewSelection(WidgetRef ref, String screenId) {
  final index = ref.read(overviewStateProvider(screenId)).selectedIndex ?? 0;
  switch (ref.read(overviewStateProvider(screenId)).searchMode) {
    case SearchMode.application:
      activateOverviewApplicationAt(ref, screenId, index);
    case SearchMode.file:
      unawaited(activateFileIndex(ref, screenId, index));
      clearOverviewSearch(ref, screenId);
    case SearchMode.settings:
      openOverviewSelectedSettingRow(ref, screenId, index);
  }
}

/// Opens or closes the settings group at [index], if it is one.
void openOverviewSelectedSettingRow(WidgetRef ref, String screenId, int index) {
  final rowList = collectSettingVisibleRowList(
    ref.read(settingsPropertiesProvider),
    ref.read(overviewSearchTextProvider(screenId)),
    ref.read(settingsExpandedGroupsProvider).toSet(),
  );
  if (index < 0 || index >= rowList.length) {
    return;
  }
  final row = rowList[index];
  if (row.isGroup) {
    ref.read(settingsExpandedGroupsProvider.notifier).toggle(row.path);
  }
}

/// Goes up to the parent directory (files mode only).
void goToOverviewParent(WidgetRef ref, String screenId) {
  if (ref.read(overviewStateProvider(screenId)).searchMode != SearchMode.file) {
    return;
  }
  ref.read(overviewStateProvider(screenId).notifier).selectIndex(null);
  ref.read(fileExplorerStateProvider(screenId).notifier).openParentDirectory();
}

/// Jumps to [path] from the file breadcrumb (files mode only).
void openOverviewBreadcrumb(
  WidgetRef ref,
  String screenId,
  DirectoryPath path,
) {
  if (ref.read(overviewStateProvider(screenId)).searchMode != SearchMode.file) {
    return;
  }
  ref.read(overviewStateProvider(screenId).notifier).selectIndex(null);
  ref.read(fileExplorerStateProvider(screenId).notifier).openBreadcrumb(path);
}

/// Cycles the search mode by [delta].
void cycleOverviewSearchMode(WidgetRef ref, String screenId, int delta) {
  final searchMode = ref.read(overviewStateProvider(screenId)).searchMode;
  final index = SearchMode.values.indexOf(searchMode);
  ref
      .read(overviewStateProvider(screenId).notifier)
      .setSearchMode(
        SearchMode.values[(index + delta) % SearchMode.values.length],
      );
}

/// Clears the search box.
void clearOverviewSearch(WidgetRef ref, String screenId) {
  ref.read(overviewSearchTextProvider(screenId).notifier).setText('');
}

/// Activates the file explorer entry at [index]: enters a directory, or opens
/// a file with its default handler and dismisses the overview.
Future<void> activateFileIndex(
  WidgetRef ref,
  String screenId,
  int index,
) async {
  final entryList = ref.read(filteredEntryListProvider(screenId)).value;
  if (entryList == null || index < 0 || index >= entryList.length) {
    return;
  }
  await activateFileEntry(ref, screenId, entryList[index]);
}

/// Activates a file explorer entry: enters a directory, or opens a file with
/// its default handler and dismisses the overview so the window is visible.
Future<void> activateFileEntry(
  WidgetRef ref,
  String screenId,
  FileEntry entry,
) async {
  final overviewNotifier = ref.read(overviewStateProvider(screenId).notifier);
  if (entry.isDirectory) {
    overviewNotifier.selectIndex(null);
    ref
        .read(fileExplorerStateProvider(screenId).notifier)
        .openDirectory(entry.path);
    return;
  }
  final didOpen = await ref
      .read(fileOpenerProvider.notifier)
      .openFile(entry.path);
  if (didOpen) {
    overviewNotifier.hide();
  }
}
