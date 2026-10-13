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

/// Both spellings of the Super modifier: the engine reports `superKey` on some
/// setups and `metaLeft`/`metaRight` (matching the generic `meta`) on others.
const List<LogicalKeyboardKey> _superModifierList = [
  LogicalKeyboardKey.superKey,
  LogicalKeyboardKey.meta,
];

/// The overview-level keyboard handler.
///
/// Placed above both the search engine and the content pane so its `Super`
/// chords and `Escape` act no matter which part of the overview holds focus
/// (the search field, a content tab, a preview, or an embedded window).
///
/// Plain-key bindings that must stay with the search field (`Enter`) are *not*
/// here: a focused client surface forwards unmodified keys like `Enter` to the
/// client, so they stay local to `SearchEngine`.
class OverviewShortcuts extends HookConsumerWidget {
  const OverviewShortcuts({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);

    // Super-modified shortcuts, mirroring the global workspace/tileable
    // hotkeys: while the overview is open they act on the result list.
    final bindings = <ShortcutActivator, VoidCallback>{};
    void addSuperBinding(
      LogicalKeyboardKey key,
      VoidCallback callback, {
      bool shift = false,
    }) {
      for (final modifier in _superModifierList) {
        bindings[LogicalKeySet.fromSet({
              modifier,
              key,
              if (shift) LogicalKeyboardKey.shift,
            })] =
            callback;
      }
    }

    addSuperBinding(
      LogicalKeyboardKey.keyW,
      () => moveOverviewSelection(ref, screenId, -1),
    );
    addSuperBinding(
      LogicalKeyboardKey.keyS,
      () => moveOverviewSelection(ref, screenId, 1),
    );
    addSuperBinding(
      LogicalKeyboardKey.keyD,
      () => activateOverviewSelection(ref, screenId),
    );
    addSuperBinding(
      LogicalKeyboardKey.keyA,
      () => goToOverviewParent(ref, screenId),
    );
    addSuperBinding(
      LogicalKeyboardKey.tab,
      () => cycleOverviewSearchMode(ref, screenId, 1),
    );
    addSuperBinding(
      LogicalKeyboardKey.tab,
      () => cycleOverviewSearchMode(ref, screenId, -1),
      shift: true,
    );
    // Escape dismisses the overview, like the close button — but it never
    // opens it, so it uses `hide` rather than `toggle`.
    bindings[const SingleActivator(LogicalKeyboardKey.escape)] = () =>
        ref.read(overviewStateProvider(screenId).notifier).hide();

    return CallbackShortcuts(bindings: bindings, child: child);
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
