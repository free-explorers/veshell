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
import 'package:shell/shared/widget/frosted_surface.dart';
import 'package:shell/shared/widget/square_icon_button.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';

class SearchEngine extends HookConsumerWidget {
  const SearchEngine({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    final searchController = useTextEditingController();
    final searchFocusNode = useFocusNode();
    final resultFocus = useMemoized(
      () => OverviewResultFocus(searchNode: searchFocusNode),
      [searchFocusNode],
    );
    useEffect(() => resultFocus.dispose, [resultFocus]);
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

    return Shortcuts(
      // Bind `Enter` close to the search pane. `MaterialApp` installs
      // `DefaultTextEditingShortcuts` above this pane, and it maps `Enter` to a
      // do-nothing intent that the focused `EditableText` handles, stopping the
      // key before the global `navigation.activate` binding (which lives in
      // `VeshellShortcutManager`, above `MaterialApp`) or the framework default
      // can reach it. Without this local binding, `Enter` after a search is
      // swallowed and nothing is activated. `Space` is deliberately left alone:
      // it must keep typing a space in the search field.
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      child: Actions(
        actions: {
          // Activation while the search field (not a result row) has focus: the
          // framework's `ActivateIntent`, reached through the local `Enter`
          // binding above or the global `navigation.activate` one.
          // Registering it here — and not above the whole overview — keeps
          // `Enter` with the search field: a focused client surface is not a
          // descendant of the search pane, so no action is found and the key is
          // forwarded to the client as before.
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              activateOverviewSelection(ref, screenId);
              return null;
            },
          ),
          // While the search field (or any other part of the engine but the
          // result list) has focus. The result list registers its own handler
          // closer to focus once the keyboard is handed to it.
          NavigateIntent: CallbackAction<NavigateIntent>(
            onInvoke: (intent) {
              final direction = switch (intent.direction) {
                NavigationDirection.up => TraversalDirection.up,
                NavigationDirection.down => TraversalDirection.down,
                NavigationDirection.left => TraversalDirection.left,
                NavigationDirection.right => TraversalDirection.right,
              };
              // The settings tree is made of focusable `ListTile`s, so it uses
              // plain directional traversal.
              if (searchMode == SearchMode.settings) {
                primaryFocus?.focusInDirection(direction);
                return null;
              }
              // The result lists are a combobox: `down` hands the keyboard to
              // the list, other directions move across the panes.
              switch (intent.direction) {
                case NavigationDirection.down:
                  final index = selectedIndex ?? 0;
                  overviewNotifier.selectIndex(index);
                  resultFocus.moveTo(index);
                case NavigationDirection.up:
                case NavigationDirection.left:
                case NavigationDirection.right:
                  primaryFocus?.focusInDirection(direction);
              }
              return null;
            },
          ),
        },
        child: FrostedSurface(
          borderRadius: BorderRadius.circular(38),
          tint: frostedGlassTint(Theme.of(context).colorScheme),
          noise: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                      // The mode switcher is clicked or reached with
                      // `Super+Tab`, never by directional focus: keeping it out
                      // of the focus order lets `down` from the search field
                      // land on the first result instead of a mode button.
                      ExcludeFocus(
                        child: Column(
                          children: [
                            SquareIconButton(
                              icon: const Icon(MdiIcons.playBox),
                              onSelected: () => overviewNotifier.setSearchMode(
                                SearchMode.application,
                              ),
                              isSelected: searchMode == SearchMode.application,
                            ),
                            const SizedBox(height: 16),
                            SquareIconButton(
                              icon: const Icon(MdiIcons.file),
                              onSelected: () => overviewNotifier.setSearchMode(
                                SearchMode.file,
                              ),
                              isSelected: searchMode == SearchMode.file,
                            ),
                            const SizedBox(height: 16),
                            SquareIconButton(
                              icon: const Icon(MdiIcons.cog),
                              onSelected: () => overviewNotifier.setSearchMode(
                                SearchMode.settings,
                              ),
                              isSelected: searchMode == SearchMode.settings,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: switch (searchMode) {
                            SearchMode.application => ApplicationSearchResult(
                              searchText: searchText,
                              selectedIndex: selectedIndex,
                              resultFocus: resultFocus,
                              onSelect: overviewNotifier.selectIndex,
                              onActivate: (index) =>
                                  activateOverviewApplicationAt(
                                    ref,
                                    screenId,
                                    index,
                                  ),
                            ),
                            SearchMode.file => FileExplorerView(
                              searchText: searchText,
                              selectedIndex: selectedIndex,
                              resultFocus: resultFocus,
                              onSelect: overviewNotifier.selectIndex,
                              onActivate: (index) => unawaited(
                                activateFileIndex(ref, screenId, index),
                              ),
                              onOpenDirectory: (path) =>
                                  openOverviewBreadcrumb(ref, screenId, path),
                              onOpenParent: () =>
                                  goToOverviewParent(ref, screenId),
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
        ),
      ),
    );
  }
}
