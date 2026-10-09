import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/widget/sliding_container.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/workspace/model/workspace_shortcuts.dart';
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
    useEffect(
      () {
        if (workspaceCanFocus) {
          workspaceFocusScopeNode.requestFocus();
        }
        return null;
      },
      [workspaceCanFocus],
    );

    final appLauncher = PersistentApplicationSelector(
      isSelected: workspaceState.selectedIndex ==
          workspaceState.tileableWindowList.length,
      onSelect: (entry) {
        final newWindowId =
            windowManager.createPersistentWindowForDesktopEntry(entry);

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
    return CurrentWorkspaceId(
      workspaceId: workspaceId,
      child: Actions(
        actions: {
          FocusLeftTileableIntent: CallbackAction<FocusLeftTileableIntent>(
            onInvoke: (_) {
              final nextIndex = workspaceState.selectedIndex - 1;
              if (nextIndex >= 0) {
                ref
                    .read(workspaceStateProvider(workspaceId).notifier)
                    .setSelectedIndex(nextIndex);
              }
              return null;
            },
          ),
          FocusRightTileableIntent: CallbackAction<FocusRightTileableIntent>(
            onInvoke: (_) {
              final nextIndex = workspaceState.selectedIndex + 1;
              if (nextIndex < tileableList.length) {
                ref
                    .read(workspaceStateProvider(workspaceId).notifier)
                    .setSelectedIndex(nextIndex);
              }
              return null;
            },
          ),
          ReorderLeftTileableIntent:
              CallbackAction<ReorderLeftTileableIntent>(
            onInvoke: (_) {
              ref
                  .read(workspaceStateProvider(workspaceId).notifier)
                  .moveSelectedWindowLeft();
              return null;
            },
          ),
          ReorderRightTileableIntent:
              CallbackAction<ReorderRightTileableIntent>(
            onInvoke: (_) {
              ref
                  .read(workspaceStateProvider(workspaceId).notifier)
                  .moveSelectedWindowRight();
              return null;
            },
          ),
          CloseTileableIntent: CallbackAction<CloseTileableIntent>(
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
                          .read(
                            workspaceStateProvider(workspaceId).notifier,
                          )
                          .setVisibleLength(value);
                    },
                  ),
                ),
                Expanded(
                  child: SlidingContainer(
                    index: workspaceState.selectedIndex,
                    visible: workspaceState.visibleLength,
                    onIndexChanged: (nextIndex) {
                      ref
                          .read(
                            workspaceStateProvider(workspaceId).notifier,
                          )
                          .setSelectedIndex(nextIndex);
                    },
                    isSwipeEnabled: CurrentScreenId.of(context) ==
                            ref.watch(focusedScreenProvider) &&
                        isSelected,
                    children: tileableList,
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
