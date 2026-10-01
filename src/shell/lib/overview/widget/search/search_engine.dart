import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';
import 'package:shell/file_explorer/provider/file_opener.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/file_explorer/widget/file_explorer_view.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/search/application_search_result.dart';
import 'package:shell/overview/widget/search/search_input.dart';
import 'package:shell/overview/widget/search/settings/settings_search_result.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/settings/model/setting_search.dart';
import 'package:shell/settings/provider/settings_expanded_groups.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/util/selection.dart';
import 'package:shell/theme/provider/theme.dart';

/// Both spellings of the Super modifier: the engine reports `superKey` on some
/// setups and `metaLeft`/`metaRight` (matching the generic `meta`) on others.
const List<LogicalKeyboardKey> _superModifierList = [
  LogicalKeyboardKey.superKey,
  LogicalKeyboardKey.meta,
];

class SearchEngine extends HookConsumerWidget {
  const SearchEngine({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final searchTextState = useState('');
    final searchMode = ref.watch(
      overviewStateProvider(screenId).select((state) => state.searchMode),
    );
    final selectedIndex = ref.watch(
      overviewStateProvider(screenId).select((state) => state.selectedIndex),
    );

    useEffect(() {
      searchController.addListener(() {
        searchTextState.value = searchController.text;
        // The result list changes with the filter; drop the stale selection.
        ref.read(overviewStateProvider(screenId).notifier).selectIndex(null);
      });
      searchFocusNode.requestFocus();
      focusLog.info('Search request at first build');
      return null;
    }, []);

    final overviewNotifier = ref.read(overviewStateProvider(screenId).notifier);

    /// The number of results the active mode offers.
    int currentResultCount() {
      switch (searchMode) {
        case SearchMode.application:
          return ref
                  .read(
                    appDrawerFilteredDesktopEntriesProvider(
                      searchTextState.value,
                    ),
                  )
                  .value
                  ?.length ??
              0;
        case SearchMode.file:
          return ref.read(filteredEntryListProvider(screenId)).value?.length ??
              0;
        case SearchMode.settings:
          return collectSettingVisibleRowList(
            ref.read(settingsPropertiesProvider),
            searchTextState.value,
            ref.read(settingsExpandedGroupsProvider).toSet(),
          ).length;
      }
    }

    void moveSelection(int delta) {
      final count = currentResultCount();
      if (count == 0) {
        return;
      }
      overviewNotifier.selectIndex(
        nextSelectionIndex(
          currentIndex: selectedIndex ?? -1,
          delta: delta,
          length: count,
        ),
      );
    }

    /// Launches the application at [index] as an ephemeral window and resets
    /// the search.
    void activateApplicationAt(int index) {
      final entryList = ref
          .read(appDrawerFilteredDesktopEntriesProvider(searchTextState.value))
          .value;
      if (entryList == null || index < 0 || index >= entryList.length) {
        return;
      }
      overviewNotifier.startEphemeralApplication(entryList[index]);
      searchController.clear();
    }

    /// Opens or closes the settings group at the selected row, if it is one.
    void openSelectedSettingRow(int index) {
      final rowList = collectSettingVisibleRowList(
        ref.read(settingsPropertiesProvider),
        searchTextState.value,
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

    void activateSelected() {
      final index = selectedIndex;
      if (index == null) {
        return;
      }
      switch (searchMode) {
        case SearchMode.application:
          activateApplicationAt(index);
        case SearchMode.file:
          unawaited(activateFileIndex(ref, screenId, index));
          searchController.clear();
        case SearchMode.settings:
          openSelectedSettingRow(index);
      }
    }

    void goToParent() {
      if (searchMode != SearchMode.file) {
        return;
      }
      overviewNotifier.selectIndex(null);
      ref
          .read(fileExplorerStateProvider(screenId).notifier)
          .openParentDirectory();
    }

    void openBreadcrumb(DirectoryPath path) {
      if (searchMode != SearchMode.file) {
        return;
      }
      overviewNotifier.selectIndex(null);
      ref
          .read(fileExplorerStateProvider(screenId).notifier)
          .openBreadcrumb(path);
    }

    void cycleSearchMode(int delta) {
      final index = SearchMode.values.indexOf(searchMode);
      overviewNotifier.setSearchMode(
        SearchMode.values[(index + delta) % SearchMode.values.length],
      );
    }

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

    addSuperBinding(LogicalKeyboardKey.keyW, () => moveSelection(-1));
    addSuperBinding(LogicalKeyboardKey.keyS, () => moveSelection(1));
    addSuperBinding(LogicalKeyboardKey.keyD, activateSelected);
    addSuperBinding(LogicalKeyboardKey.keyA, goToParent);
    addSuperBinding(LogicalKeyboardKey.tab, () => cycleSearchMode(1));
    addSuperBinding(
      LogicalKeyboardKey.tab,
      () => cycleSearchMode(-1),
      shift: true,
    );
    // Secondary activation, matching the double click.
    bindings[const SingleActivator(LogicalKeyboardKey.enter)] =
        activateSelected;
    bindings[const SingleActivator(LogicalKeyboardKey.numpadEnter)] =
        activateSelected;

    return CallbackShortcuts(
      bindings: bindings,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(38),
          color: Theme.of(context).colorScheme.surface.withAlpha(200),
        ),
        child: Column(
          children: [
            SearchInput(
              searchController: searchController,
              searchFocusNode: searchFocusNode,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Column(
                    children: [
                      SearchModeButton(
                        icon: const Icon(MdiIcons.playBox),
                        onSelected: () => overviewNotifier.setSearchMode(
                          SearchMode.application,
                        ),
                        isSelected: searchMode == SearchMode.application,
                      ),
                      const SizedBox(height: 16),
                      SearchModeButton(
                        icon: const Icon(MdiIcons.file),
                        onSelected: () =>
                            overviewNotifier.setSearchMode(SearchMode.file),
                        isSelected: searchMode == SearchMode.file,
                      ),
                      const SizedBox(height: 16),
                      SearchModeButton(
                        icon: const Icon(MdiIcons.cog),
                        onSelected: () =>
                            overviewNotifier.setSearchMode(SearchMode.settings),
                        isSelected: searchMode == SearchMode.settings,
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: switch (searchMode) {
                        SearchMode.application => ApplicationSearchResult(
                          searchText: searchTextState.value,
                          selectedIndex: selectedIndex,
                          onSelect: overviewNotifier.selectIndex,
                          onActivate: activateApplicationAt,
                        ),
                        SearchMode.file => FileExplorerView(
                          searchText: searchTextState.value,
                          selectedIndex: selectedIndex,
                          onSelect: overviewNotifier.selectIndex,
                          onActivate: (index) => unawaited(
                            activateFileIndex(ref, screenId, index),
                          ),
                          onOpenDirectory: openBreadcrumb,
                          onOpenParent: goToParent,
                        ),
                        SearchMode.settings => SettingsSearchResult(
                          searchText: searchTextState.value,
                          selectedIndex: selectedIndex,
                        ),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class SearchModeButton extends StatelessWidget {
  const SearchModeButton({
    required this.icon,
    required this.onSelected,
    this.isSelected = false,
    super.key,
  });

  final bool isSelected;
  final Widget icon;
  final void Function()? onSelected;
  @override
  Widget build(BuildContext context) {
    var buttonType = IconButton.new;
    var style = IconButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(surfaceRadius),
      ),
      padding: const EdgeInsets.all(12),
      iconSize: 28,
    );
    if (isSelected) {
      buttonType = IconButton.filled;
      style = style.copyWith(
        backgroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.primaryContainer,
        ),
        foregroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      );
    }
    return buttonType(onPressed: onSelected, icon: icon, style: style);
  }
}
