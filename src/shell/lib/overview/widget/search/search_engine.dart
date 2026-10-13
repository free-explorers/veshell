import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/file_explorer/widget/file_explorer_view.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/overview/provider/overview_search_text.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview_shortcuts.dart';
import 'package:shell/overview/widget/search/application_search_result.dart';
import 'package:shell/overview/widget/search/search_input.dart';
import 'package:shell/overview/widget/search/settings/settings_search_result.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/theme/provider/theme.dart';

class SearchEngine extends HookConsumerWidget {
  const SearchEngine({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final searchText = ref.watch(overviewSearchTextProvider(screenId));
    final searchMode = ref.watch(
      overviewStateProvider(screenId).select((state) => state.searchMode),
    );
    final selectedIndex = ref.watch(
      overviewStateProvider(screenId).select((state) => state.selectedIndex),
    );
    // Watched so the first-result focus below fires once an async list loads.
    final resultCount = watchOverviewResultCount(ref, screenId);

    // Set when the user edits the search box; the list then focuses its first
    // result once the new (possibly async) list is available.
    final selectFirstPending = useRef(false);
    // Guards the programmatic controller update below so it is not read back as
    // a user edit.
    final isSyncingController = useRef(false);

    useEffect(() {
      void listener() {
        if (isSyncingController.value) {
          return;
        }
        final text = searchController.text;
        // Focus/attach also notifies the controller with unchanged text; only a
        // real edit (which the provider does not yet hold) counts.
        if (text == ref.read(overviewSearchTextProvider(screenId))) {
          return;
        }
        ref.read(overviewSearchTextProvider(screenId).notifier).setText(text);
        // The result list changes with the filter; focus its first entry once
        // the new list is available.
        selectFirstPending.value = true;
        ref.read(overviewStateProvider(screenId).notifier).selectIndex(null);
      }

      searchController.addListener(listener);
      searchFocusNode.requestFocus();
      focusLog.info('Search request at first build');
      return () => searchController.removeListener(listener);
    }, []);

    // Focus the first result of a freshly filtered list, so a search can be
    // accepted with `Enter`. In Files mode this also opens the first preview.
    useEffect(() {
      if (!selectFirstPending.value || resultCount == 0) {
        return null;
      }
      selectFirstPending.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        ref.read(overviewStateProvider(screenId).notifier).selectIndex(0);
      });
      return null;
    }, [searchText, resultCount]);

    // Follow the search text when it is cleared from outside — for example by
    // the overview-level keyboard shortcuts, which cannot reach the controller.
    useEffect(() {
      if (searchController.text == searchText) {
        return null;
      }
      isSyncingController.value = true;
      searchController.value = TextEditingValue(
        text: searchText,
        selection: TextSelection.collapsed(offset: searchText.length),
      );
      isSyncingController.value = false;
      return null;
    }, [searchText]);

    final overviewNotifier = ref.read(overviewStateProvider(screenId).notifier);

    // Secondary activation, matching the double click. Kept local to the search
    // field (rather than in `OverviewShortcuts`) so a focused client surface
    // still receives `Enter`.
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.enter): () =>
          activateOverviewSelection(ref, screenId),
      const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
          activateOverviewSelection(ref, screenId),
    };

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
                          searchText: searchText,
                          selectedIndex: selectedIndex,
                          onSelect: overviewNotifier.selectIndex,
                          onActivate: (index) => activateOverviewApplicationAt(
                            ref,
                            screenId,
                            index,
                          ),
                        ),
                        SearchMode.file => FileExplorerView(
                          searchText: searchText,
                          selectedIndex: selectedIndex,
                          onSelect: overviewNotifier.selectIndex,
                          onActivate: (index) => unawaited(
                            activateFileIndex(ref, screenId, index),
                          ),
                          onOpenDirectory: (path) =>
                              openOverviewBreadcrumb(ref, screenId, path),
                          onOpenParent: () => goToOverviewParent(ref, screenId),
                        ),
                        SearchMode.settings => SettingsSearchResult(
                          searchText: searchText,
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
