import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/application/provider/app_launch_history.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/shortcut_manager/model/super_key.dart';
import 'package:shell/workspace/provider/launch_morphs.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_grid.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/launch_morph.dart';

/// Launches [entry], from [origin] when known; completes once the launch has
/// taken over (its opening animation included).
typedef AppDrawerLaunchCallback =
    Future<void> Function(LocalizedDesktopEntry entry, LaunchOrigin? origin);

/// The launcher's sections, where a launched item can come from.
enum _Section { frequent, list }

/// The widest the search field grows; past it a long empty bar reads as a
/// divider rather than a field.
const _maxSearchFieldWidth = 720.0;

/// The launcher's search field above the grid of matching applications.
///
/// With an empty search, the most used applications sit in a card of their
/// own, one row that stays put above the scrolling alphabetical list.
///
/// The keyboard stays in the search field: `Up`/`Down` move the selection a
/// row, `Left`/`Right` an entry once the caret is at that end of the text, and
/// `Enter` launches the selected entry (the first one until the selection is
/// moved). The selection is only drawn once the keyboard is in use (a search
/// typed or an arrow pressed). Launching clears the search.
class AppDrawer extends HookConsumerWidget {
  const AppDrawer({
    required this.onSelect,
    required this.searchFocusNode,
    super.key,
  });
  final AppDrawerLaunchCallback onSelect;

  /// The launcher tile's search node.
  ///
  /// The tile owns the keyboard policy — it focuses this node from its scope's
  /// focus event — so the field never asks for the focus itself.
  final FocusNode searchFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchText = useValueListenable(searchController).text;
    final matchList = ref.watch(
      appDrawerFilteredDesktopEntriesProvider(searchText),
    );
    // While searching, the most used lead the matches instead (see
    // `filterDesktopEntries`), so the card would only repeat them.
    final frequentList = searchText.trim().isEmpty
        ? ref.watch(appDrawerFrequentDesktopEntriesProvider).value ??
              const <LocalizedDesktopEntry>[]
        : const <LocalizedDesktopEntry>[];
    final selection = useState(0);
    // Whether an arrow key moved the selection since the last launch.
    final navigated = useState(false);
    final scrollController = useScrollController();
    // How to find where the entry `Enter` launches sits (see
    // `AppEntry.launchTarget`); rebuilt with the grid, so cleared first.
    final launchTarget = useRef<LaunchOriginGetter?>(null)..value = null;
    // The entry whose launch is morphing into its tile: it detached from the
    // section it was launched from, where a new one fades in at its place
    // (its copy in the other section stays). Read from the morphs, not kept
    // here: the tile takes the launcher's slot, which can rebuild the
    // launcher afresh.
    final reappearing = ref.watch(
      launchMorphsProvider.select(
        (morphs) => switch (morphs.values.lastOrNull) {
          final request? => (
            entry: (id: request.entry.desktopEntry.id, token: request),
            section: request.origin.section,
          ),
          null => null,
        },
      ),
    );
    AppEntryReappearance? reappearingIn(_Section section) =>
        reappearing != null && reappearing.section == section
        ? reappearing.entry
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The margins shrink with the tile, so a narrow tile keeps its room
        // for the field and the grid.
        final margin = (constraints.biggest.shortestSide * 0.06).clamp(
          12.0,
          48.0,
        );
        final gridPadding = margin / 2;
        final columnCount = appGridColumnCount(
          constraints.maxWidth - 2 * margin - 2 * gridPadding,
        );

        // One row: the most used applications are a shortcut, not a list.
        final frequentRow = frequentList.take(columnCount).toList();
        final matches = matchList.value ?? const <LocalizedDesktopEntry>[];
        // One selection runs over both cards, the row first, so the arrows
        // cross between them.
        final entryList = [...frequentRow, ...matches];
        final cells = appGridCells([
          frequentRow.length,
          matches.length,
        ], columnCount);

        // The entry list can shrink under the selection (an application
        // removed, or a narrower search), so the index is clamped on use.
        final selectedIndex = entryList.isEmpty
            ? null
            : selection.value.clamp(0, entryList.length - 1);

        // Searching happens at the top: the field may have scrolled out of
        // view while browsing, but keeps the keyboard, so typing brings it
        // and the first matches back.
        void scrollToTop() {
          if (scrollController.hasClients) {
            scrollController.jumpTo(0);
          }
        }

        void resetSearch() {
          searchController.clear();
          selection.value = 0;
          navigated.value = false;
          scrollToTop();
        }

        Future<void> launch(
          int index,
          LocalizedDesktopEntry entry,
          LaunchOrigin? origin,
        ) async {
          await onSelect(
            entry,
            origin == null
                ? null
                : (
                    item: origin.item,
                    icon: origin.icon,
                    label: origin.label,
                    section: index < frequentRow.length
                        ? _Section.frequent
                        : _Section.list,
                  ),
          );
          if (!context.mounted) {
            return;
          }
          ref.read(appLaunchHistoryStateProvider.notifier).recordLaunch(entry);
          // The launcher stays in the layout, so the next visit starts afresh.
          resetSearch();
        }

        void onLaunch(
          int index,
          LocalizedDesktopEntry entry,
          LaunchOrigin? origin,
        ) => unawaited(launch(index, entry, origin));

        void launchSelected() {
          if (selectedIndex != null) {
            onLaunch(
              selectedIndex,
              entryList[selectedIndex],
              launchTarget.value?.call(),
            );
          }
        }

        /// Moves the selection to [target] when there is one; returns whether
        /// the key was the launcher's (always, once a selection exists).
        bool moveTo(int? target) {
          if (selectedIndex == null) {
            return false;
          }
          navigated.value = true;
          if (target != null && target >= 0 && target < entryList.length) {
            selection.value = target;
          }
          return true;
        }

        KeyEventResult handleKey(FocusNode node, KeyEvent event) {
          final keyboard = HardwareKeyboard.instance;
          if (event is KeyUpEvent ||
              keyboard.isShiftPressed ||
              keyboard.isControlPressed ||
              keyboard.isAltPressed ||
              // The compositor may report Super as `superKey`, which
              // `isMetaPressed` misses: a Super+Arrow chord is the shell's.
              isSuperKeyPressed(keyboard)) {
            return KeyEventResult.ignored;
          }
          final index = selectedIndex;
          final caret = searchController.selection;
          final textLength = searchController.text.length;
          final handled = switch (event.logicalKey) {
            LogicalKeyboardKey.arrowDown when index != null => moveTo(
              appGridMoveVertically(cells, index, 1),
            ),
            LogicalKeyboardKey.arrowUp when index != null => moveTo(
              appGridMoveVertically(cells, index, -1),
            ),
            // Left/Right edit the caret until it reaches that end of the
            // text, so the search stays editable and an empty search
            // navigates at once.
            LogicalKeyboardKey.arrowRight
                when index != null &&
                    caret.isCollapsed &&
                    caret.baseOffset >= textLength =>
              moveTo(index + 1),
            LogicalKeyboardKey.arrowLeft
                when index != null &&
                    caret.isCollapsed &&
                    caret.baseOffset <= 0 =>
              moveTo(index - 1),
            _ => false,
          };
          // A move blocked at the edge of the grid is still the launcher's
          // key: it must not fall through to the field (which would jump the
          // caret) or to the shell bindings.
          return handled ? KeyEventResult.handled : KeyEventResult.ignored;
        }

        void clearSearch() {
          resetSearch();
          searchFocusNode.requestFocus();
        }

        // Drawn only once the keyboard is in use: before that, `Enter` still
        // takes the first entry, but a highlight would read as a choice made
        // for the user.
        final shownIndex = searchText.isNotEmpty || navigated.value
            ? selectedIndex
            : null;

        final gridIndex = shownIndex == null
            ? null
            : shownIndex - frequentRow.length;
        final gridSliver = matches.isEmpty && searchText.trim().isNotEmpty
            ? SliverToBoxAdapter(child: _NoMatch(query: searchText.trim()))
            : AppGridSliver(
                entryList: matches,
                columnCount: columnCount,
                selectedIndex: gridIndex != null && gridIndex >= 0
                    ? gridIndex
                    : null,
                query: searchText,
                padding: gridPadding,
                launchTargetIndex: selectedIndex == null
                    ? null
                    : selectedIndex - frequentRow.length,
                launchTarget: launchTarget,
                reappearing: reappearingIn(_Section.list),
                onLaunch: (index, entry, origin) =>
                    onLaunch(frequentRow.length + index, entry, origin),
              );

        // The whole tile scrolls: browsing is when the search and the most
        // used are not needed, so the list gets the room.
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(margin),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _maxSearchFieldWidth,
                        ),
                        child: Focus(
                          canRequestFocus: false,
                          skipTraversal: true,
                          onKeyEvent: handleKey,
                          child: _AppDrawerTextField(
                            controller: searchController,
                            focusNode: searchFocusNode,
                            // Typing narrows the list: start again from the
                            // first match, at the top.
                            onChanged: () {
                              selection.value = 0;
                              scrollToTop();
                            },
                            onSubmitted: launchSelected,
                            onClear: clearSearch,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: margin / 2)),
                  if (frequentRow.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Card(
                        child: AppRow(
                          entryList: frequentRow,
                          columnCount: columnCount,
                          selectedIndex:
                              shownIndex != null &&
                                  shownIndex < frequentRow.length
                              ? shownIndex
                              : null,
                          padding: gridPadding,
                          launchTargetIndex: selectedIndex,
                          launchTarget: launchTarget,
                          reappearing: reappearingIn(_Section.frequent),
                          onLaunch: onLaunch,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: margin / 2)),
                  ],
                  _CardSliver(
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        gridSliver,
                        // A short result list still fills the tile: the card
                        // keeps its height while typing narrows the list.
                        _FillToBottom(bottomMargin: margin),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Empty room down to [bottomMargin] above the bottom of the viewport, or
/// nothing once the content above already reaches it.
///
/// `SliverFillRemaining` does this for a viewport's own children, but not
/// nested in sliver groups (it ignores the trailing padding and asserts once
/// scrolled), so the room is measured from the scroll extent above instead.
class _FillToBottom extends StatelessWidget {
  const _FillToBottom({required this.bottomMargin});

  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverToBoxAdapter(
        child: SizedBox(
          height: math.max(
            0,
            constraints.viewportMainAxisExtent -
                constraints.precedingScrollExtent -
                bottomMargin,
          ),
        ),
      ),
    );
  }
}

/// A [Card]'s surface (the theme's color and shape) behind a [sliver], so the
/// card can scroll with the page instead of holding a scroll view of its own.
class _CardSliver extends StatelessWidget {
  const _CardSliver({required this.sliver});

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedSliver(
      decoration: ShapeDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
        shape:
            theme.cardTheme.shape ??
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
      ),
      sliver: sliver,
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.noAppsMatch(query),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _AppDrawerTextField extends StatelessWidget {
  const _AppDrawerTextField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted(),
      // Without it `Enter` also unfocuses the field, taking the keyboard out
      // of the launcher (say, on a search matching nothing).
      onEditingComplete: () {},
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: ShellIcon(MdiIcons.magnify),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: IconButton(
                  tooltip: context.l10n.clearSearch,
                  onPressed: onClear,
                  icon: const ShellIcon(MdiIcons.close),
                ),
              ),
        hintText: context.l10n.searchApps,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: colorScheme.surface,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}
