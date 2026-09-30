import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
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
    final selectedPath = ref.watch(
      overviewStateProvider(screenId).select((state) => state.selectedPath),
    );

    useEffect(() {
      searchController.addListener(() {
        searchTextState.value = searchController.text;
      });
      searchFocusNode.requestFocus();
      focusLog.info('Search request at first build');
      return null;
    }, []);

    final overviewNotifier = ref.read(overviewStateProvider(screenId).notifier);

    List<FileEntry> currentEntryList() =>
        ref.read(filteredEntryListProvider(screenId)).value ??
        const <FileEntry>[];

    void selectEntry(FileEntry entry) =>
        overviewNotifier.selectPath(entry.path);

    void moveSelection(int delta) {
      if (searchMode != SearchMode.file) {
        return;
      }
      final entryList = currentEntryList();
      if (entryList.isEmpty) {
        return;
      }
      final currentIndex = entryList.indexWhere(
        (entry) => entry.path == selectedPath,
      );
      final nextIndex = nextSelectionIndex(
        currentIndex: currentIndex,
        delta: delta,
        length: entryList.length,
      );
      overviewNotifier.selectPath(entryList[nextIndex].path);
    }

    void activateSelected() {
      if (searchMode != SearchMode.file) {
        return;
      }
      final entryList = currentEntryList();
      final index = entryList.indexWhere((entry) => entry.path == selectedPath);
      if (index < 0) {
        return;
      }
      unawaited(activateFileEntry(ref, screenId, entryList[index]));
    }

    void goToParent() {
      if (searchMode != SearchMode.file) {
        return;
      }
      overviewNotifier.selectPath(null);
      ref
          .read(fileExplorerStateProvider(screenId).notifier)
          .openParentDirectory();
    }

    void openDirectory(DirectoryPath path) {
      if (searchMode != SearchMode.file) {
        return;
      }
      overviewNotifier.selectPath(null);
      ref
          .read(fileExplorerStateProvider(screenId).notifier)
          .openDirectory(path);
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
                        ),
                        SearchMode.file => FileExplorerView(
                          searchText: searchTextState.value,
                          selectedPath: selectedPath,
                          onSelect: selectEntry,
                          onActivate: (entry) => unawaited(
                            activateFileEntry(ref, screenId, entry),
                          ),
                          onOpenDirectory: openDirectory,
                          onOpenParent: goToParent,
                        ),
                        SearchMode.settings => SettingsSearchResult(
                          searchText: searchTextState.value,
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

/// Activates a file explorer entry: enters a directory, or opens a file with
/// its default handler and dismisses the overview so the window is visible.
Future<void> activateFileEntry(
  WidgetRef ref,
  String screenId,
  FileEntry entry,
) async {
  final overviewNotifier = ref.read(overviewStateProvider(screenId).notifier);
  if (entry.isDirectory) {
    overviewNotifier.selectPath(null);
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
          Theme.of(context).colorScheme.primary,
        ),
        foregroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.onPrimary,
        ),
      );
    }
    return buttonType(onPressed: onSelected, icon: icon, style: style);
  }
}
