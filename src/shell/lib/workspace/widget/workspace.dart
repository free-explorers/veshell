import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/settings/provider/state/focus_indicator_setting.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/widget/saturation_filter.dart';
import 'package:shell/shared/widget/sliding_container.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/tile_grab/model/tile_drop.dart';
import 'package:shell/tile_grab/model/tile_grab_marker.dart';
import 'package:shell/tile_grab/provider/tile_grab_controller.dart';
import 'package:shell/tile_grab/widget/tile_drop_slot.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/current_workspace_id.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/persistent_application_launcher.dart';
import 'package:shell/workspace/widget/tileable/persistent_window/persistent_window.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';
import 'package:shell/workspace/widget/workspace_panel.dart';

class WorkspaceWidget extends HookConsumerWidget {
  const WorkspaceWidget({
    required this.workspaceId,
    required this.isSelected,
    super.key,
  });

  final bool isSelected;
  final String workspaceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowManager = ref.watch(windowManagerProvider.notifier);
    final workspaceState = ref.watch(workspaceStateProvider(workspaceId));

    final workspaceFocusScopeNode = useFocusScopeNode(
      debugLabel: 'WorkspaceScope',
    );

    // Only the selected workspace of the screen the compositor reports as
    // focused may take focus. Every monitor mounts its own selected workspace
    // and the launcher's search field autofocuses, so without the screen gate
    // they all grab focus on mount and the last one wins: at startup that is an
    // arbitrary monitor, and the screen under the pointer never holds focus,
    // which leaves its actions and shortcuts dead until the pointer enters it.
    //
    // `platformFocusedScreen` (not `focusedScreen`) is the gate: it stays null
    // until the compositor's monitor layout is known, so no screen can grab
    // focus from a persisted fallback and pin the wrong monitor at startup.
    final isFocusedScreen =
        ref.watch(platformFocusedScreenProvider) == CurrentScreenId.of(context);
    final workspaceCanFocus = isSelected && isFocusedScreen;

    // `FocusScope.autofocus` only fires once per element lifetime (its flag is
    // reset only when the widget is deactivated). Reversing the workspace
    // hotkey mid-animation returns to a page that is still alive, so autofocus
    // no-ops while the workspace we leave loses focus, parking focus on the
    // root scope where the screen shortcuts no longer fire. Request focus
    // explicitly every time this workspace becomes selected instead.
    useEffect(() {
      if (workspaceCanFocus) {
        workspaceFocusScopeNode.requestFocus();
      }
      return null;
    }, [workspaceCanFocus]);

    final appLauncher = PersistentApplicationSelector(
      isSelected:
          workspaceState.selectedIndex ==
          workspaceState.tileableWindowList.length,
      onSelect: (entry) {
        final newWindowId = windowManager.createPersistentWindowForDesktopEntry(
          entry,
        );

        ref
            .read(workspaceStateProvider(workspaceId).notifier)
            .addWindow(newWindowId, selectWindow: true);
      },
    );

    final tileableList = <Tileable>[];
    for (final (index, windowId) in workspaceState.tileableWindowList.indexed) {
      tileableList.add(
        PersistentWindowTileable(
          windowId: windowId,
          isSelected: workspaceState.selectedIndex == index,
          onGrabFocus: () => ref
              .read(workspaceStateProvider(workspaceId).notifier)
              .setSelectedIndex(index),
        ),
      );
    }
    tileableList.add(appLauncher);

    // Emphasize the focused tile only when it shares the screen with others.
    final focusIndicator = ref.watch(focusIndicatorSettingProvider);
    final showsFocusIndicator = workspaceState.visibleLength > 1;
    final grayscaleUnfocused =
        showsFocusIndicator && focusIndicator == FocusIndicator.grayscale;
    // The border marks a slot, not the tile sliding through it while a tile
    // is held, so it is hidden meanwhile; it keeps its gap so no tile moves.
    final (isGrabbing, landingGap) = ref.watch(
      tileGrabControllerProvider.select(
        (grab) => (
          grab != null,
          grab != null && grab.settling
              ? tileGapIndex(
                  workspaceId: workspaceId,
                  windowList: workspaceState.tileableWindowList,
                  heldWindowId: grab.windowId,
                  target: grab.target,
                )
              : null,
        ),
      ),
    );
    final selectionIndicator =
        showsFocusIndicator && focusIndicator == FocusIndicator.border
        ? SlidingSelectionIndicator(
            color: isGrabbing
                ? Colors.transparent
                : Theme.of(context).colorScheme.primary,
          )
        : null;
    return CurrentWorkspaceId(
      workspaceId: workspaceId,
      child: Actions(
        actions: {
          // The workspace owns the horizontal axis: tileables are laid out in
          // a row. Vertical navigation belongs to the enclosing screen (its
          // workspaces), so it is forwarded upwards.
          NavigateIntent: CallbackAction<NavigateIntent>(
            onInvoke: (intent) {
              final notifier = ref.read(
                workspaceStateProvider(workspaceId).notifier,
              );
              switch (intent.direction) {
                case NavigationDirection.left:
                  notifier.selectAdjacentTileable(-1);
                case NavigationDirection.right:
                  notifier.selectAdjacentTileable(1);
                case NavigationDirection.up:
                case NavigationDirection.down:
                  if (context.mounted) {
                    Actions.maybeInvoke(context, intent);
                  }
              }
              return null;
            },
          ),
          MoveIntent: CallbackAction<MoveIntent>(
            onInvoke: (intent) {
              final notifier = ref.read(
                workspaceStateProvider(workspaceId).notifier,
              );
              switch (intent.direction) {
                case NavigationDirection.left:
                  notifier.moveSelectedWindowLeft();
                case NavigationDirection.right:
                  notifier.moveSelectedWindowRight();
                case NavigationDirection.up:
                case NavigationDirection.down:
                  if (context.mounted) {
                    Actions.maybeInvoke(context, intent);
                  }
              }
              return null;
            },
          ),
          CloseIntent: CallbackAction<CloseIntent>(
            onInvoke: (_) {
              final tileable = tileableList[workspaceState.selectedIndex];
              if (tileable is PersistentWindowTileable) {
                ref
                    .read(
                      persistentWindowStateProvider(tileable.windowId).notifier,
                    )
                    .closeWindow();
              }

              return null;
            },
          ),
        },
        child: FocusScope(
          node: workspaceFocusScopeNode,
          onFocusChange: (value) {
            focusLog.info('Focus changed $value for Workspace $workspaceId');
          },
          autofocus: workspaceCanFocus,
          // Only the selected workspace of the focused screen may take focus;
          // an unselected one must not steal it, and neither must one on a
          // monitor the compositor has not focused.
          //
          // It is set explicitly because a `FocusScopeNode` reports
          // `descendantsAreFocusable` as `canRequestFocus && _descendants...`,
          // and `Focus` writes that getter straight back into the node.
          // Leaving it unset would latch it to false once the workspace is
          // deselected, never restoring it and making the launcher search and
          // window placeholders unreachable.
          canRequestFocus: workspaceCanFocus,
          descendantsAreFocusable: workspaceCanFocus,
          // A workspace-local overlay hosts the tileable notification popups so
          // they are clipped and scrolled by the workspace instead of floating
          // above the whole shell from the root overlay.
          child: Overlay.wrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FocusScope(
                  canRequestFocus: false,
                  descendantsAreFocusable: false,
                  child: WorkspacePanel(
                    tileableList: tileableList,
                    visibleLength: workspaceState.visibleLength,
                    onVisibleLengthChange: (value) {
                      ref
                          .read(workspaceStateProvider(workspaceId).notifier)
                          .setVisibleLength(value);
                    },
                  ),
                ),
                Expanded(
                  child: SlidingContainer(
                    // A released tile is landing here: bring its gap into
                    // view (with a single tile shown, the shown one slides
                    // out), so the tile is already shown once selected.
                    index: landingGap ?? workspaceState.selectedIndex,
                    visible: workspaceState.visibleLength,
                    firstVisibleIndex: workspaceState.firstVisibleIndex,
                    onIndexChanged: (nextIndex) {
                      ref
                          .read(workspaceStateProvider(workspaceId).notifier)
                          .setSelectedIndex(nextIndex);
                    },
                    onFirstVisibleIndexChanged: (firstVisibleIndex) {
                      ref
                          .read(workspaceStateProvider(workspaceId).notifier)
                          .setFirstVisibleIndex(firstVisibleIndex);
                    },
                    isSwipeEnabled:
                        CurrentScreenId.of(context) ==
                            ref.watch(focusedScreenProvider) &&
                        isSelected,
                    selectionIndicator: selectionIndicator,
                    // A held tile finds its gap from the row's geometry.
                    viewportMetaData: (scrollOffset) => TileRowMarker(
                      workspaceId: workspaceId,
                      visible: workspaceState.visibleLength,
                      scrollOffset: scrollOffset,
                    ),
                    // Tiles sliding aside for a held tile may come from off
                    // screen.
                    buildsNeighbors: isGrabbing,
                    children: [
                      // Always wrapped, even when not filtering, so changing
                      // the setting or the selection never remounts a tile.
                      // Keyed by window, so a tile keeps its state (and its
                      // slide) when it is reordered.
                      for (final (index, tileable) in tileableList.indexed)
                        TileDropSlot(
                          key: tileable is PersistentWindowTileable
                              ? ValueKey(tileable.windowId)
                              : const ValueKey('application-launcher'),
                          workspaceId: workspaceId,
                          index: index,
                          windowId: tileable is PersistentWindowTileable
                              ? tileable.windowId
                              : null,
                          child: _FocusSaturation(
                            desaturated:
                                grayscaleUnfocused &&
                                index != workspaceState.selectedIndex,
                            child: tileable,
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

/// How much an unfocused tile is darkened on top of the grayscale, so the
/// effect still reads on apps that are already gray.
const _unfocusedDim = 0.20;

/// Fades [child] to a dimmed grayscale while [desaturated].
class _FocusSaturation extends StatelessWidget {
  const _FocusSaturation({required this.desaturated, required this.child});

  final bool desaturated;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    // 0 is untouched, 1 is fully desaturated and dimmed.
    tween: Tween(end: desaturated ? 1 : 0),
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    builder: (context, amount, child) => SaturationFilter(
      saturation: 1 - amount,
      brightness: 1 - _unfocusedDim * amount,
      child: child,
    ),
    child: child,
  );
}
