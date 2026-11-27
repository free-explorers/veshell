import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/dev_tools/provider/dev_tools_enabled.dart';
import 'package:shell/dev_tools/widget/dev_tools_overview.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview.dart';
import 'package:shell/overview/widget/overview_blur_target.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/pointer_screen.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/screen/widget/screen_panel.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/widget/sliding_container.dart';
import 'package:shell/shortcut_manager/model/layout_intents.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/status_bar/provider/status_bar_settings.dart';
import 'package:shell/status_bar/provider/status_notch_geometry.dart';
import 'package:shell/status_bar/widget/status_notch.dart';
import 'package:shell/status_bar/widget/status_top_panel.dart';
import 'package:shell/tile_grab/model/tile_grab_marker.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/workspace.dart';

/// Widget that represent the Screen in the widget tree
class ScreenWidget extends HookConsumerWidget {
  /// Const constructor
  const ScreenWidget({required this.screenId, super.key});

  final ScreenId screenId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenState = ref.watch(screenStateProvider(screenId));
    final overviewDisplayed = ref.watch(
      overviewStateProvider(screenId).select((state) => state.isDisplayed),
    );

    final screenFocusScopeNode = useFocusScopeNode(
      debugLabel: 'ScreenFocusNode',
    );

    // The workspaces are kept alive by the container below, so every one of
    // them is rebuilt whenever this list is. A page whose workspace and
    // selection did not change keeps its widget instance, and Flutter stops
    // there: switching workspaces rebuilds the two whose selection changed,
    // not all of them. The cache key holds every argument of the page: one
    // added to WorkspaceWidget must be added to the key too, or a cached page
    // would keep its old value.
    final workspacePageCache = useRef(<(WorkspaceId, bool), Widget>{});
    final workspacePages = <(WorkspaceId, bool), Widget>{
      for (final (index, workspaceId) in screenState.workspaceList.indexed)
        (workspaceId, screenState.selectedIndex == index):
            workspacePageCache.value[(
              workspaceId,
              screenState.selectedIndex == index,
            )] ??
            WorkspaceWidget(
              // A kept page follows its workspace when others are inserted
              // or removed.
              key: ValueKey(workspaceId),
              workspaceId: workspaceId,
              isSelected: screenState.selectedIndex == index,
            ),
    };
    workspacePageCache.value = workspacePages;

    return CurrentScreenId(
      screenId: screenId,
      child: Actions(
        actions: {
          ToggleOverviewIntent: CallbackAction<ToggleOverviewIntent>(
            onInvoke: (_) {
              print('In ToggleOverviewIntent');
              ref.read(overviewStateProvider(screenId).notifier).toggle();
              return null;
            },
          ),
          DumpDebugFocusTree: CallbackAction<DumpDebugFocusTree>(
            onInvoke: (_) {
              print('In DumpDebugFocusTree');
              debugDumpFocusTree();
              return null;
            },
          ),
          // The screen count belongs to this screen's monitor; it never goes
          // below one from a hotkey.
          ChangeScreenCountIntent: CallbackAction<ChangeScreenCountIntent>(
            onInvoke: (intent) {
              final provider = monitorConfigurationStateProvider(
                CurrentMonitorName.of(context),
              );
              if (intent.delta > 0) {
                ref.read(provider.notifier).addScreen();
              } else if (ref.read(provider).screenList.length > 1) {
                ref.read(provider.notifier).removeLastScreenConfiguration();
              }
              return null;
            },
          ),
          ToggleDevToolsIntent: CallbackAction<ToggleDevToolsIntent>(
            onInvoke: (_) {
              ref.read(devToolsEnabledProvider.notifier).toggle();
              return null;
            },
          ),
        },
        // The pointer entering a screen only records where the user is
        // looking (for what surfaces on its own); the keyboard moves on a
        // click. A press anywhere on the screen focuses it, panels and empty
        // space included.
        child: MouseRegion(
          onEnter: (event) {
            ref.read(pointerScreenProvider.notifier).set(screenId);
          },
          child: Listener(
            onPointerDown: (event) {
              if (screenFocusScopeNode.hasFocus) {
                return;
              }
              // The focused screen is set as state, not only asked of
              // Flutter's focus: a focus request alone can lose to a widget
              // that takes focus during the same press (a text field on
              // another screen unfocuses on a press outside it, handing focus
              // to its own scope). The state opens this screen's workspace,
              // whose selected tile then takes the keyboard.
              ref
                  .read(focusedScreenProvider.notifier)
                  .setFocusedScreen(screenId);
              screenFocusScopeNode.requestFocus();
              focusLog.info('screen $screenId: requestFocus on press');
            },
            child: FocusScope(
              node: screenFocusScopeNode,
              onFocusChange: (value) {
                focusLog.info('screen $screenId: onFocusChange $value');
                if (value) {
                  ref
                      .read(focusedScreenProvider.notifier)
                      .setFocusedScreen(screenId);
                }
              },
              // Marks the screen under a held tile, which Super+WASD navigates.
              child: MetaData(
                metaData: TileGrabScreenMarker(screenId),
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  children: [
                    // Screen-level notification popups (workspace buttons,
                    // screen panel) are hosted in an Overlay below the
                    // overview. An OverlayPortal would otherwise land in the
                    // root overlay and float above the overview. Composed
                    // through `OverviewBlurTarget` so the overview owns the
                    // blur it applies to the rest of the screen while open.
                    OverviewBlurTarget(
                      screenId: screenId,
                      child: Overlay.wrap(
                        child: Actions(
                          actions: {
                            // The screen owns the vertical axis: workspaces are
                            // stacked per screen. Horizontal navigation is
                            // owned by the focused workspace, whose handler
                            // sits closer to focus, so the screen leaves it
                            // alone.
                            NavigateIntent: CallbackAction<NavigateIntent>(
                              onInvoke: (intent) {
                                final notifier = ref.read(
                                  screenStateProvider(screenId).notifier,
                                );
                                switch (intent.direction) {
                                  case NavigationDirection.up:
                                    notifier.selectAdjacentWorkspace(-1);
                                  case NavigationDirection.down:
                                    notifier.selectAdjacentWorkspace(1);
                                  case NavigationDirection.left:
                                  case NavigationDirection.right:
                                    break;
                                }
                                return null;
                              },
                            ),
                            // Vertically, a move sends the selected tile to the
                            // workspace above/below; horizontal reordering is
                            // owned by the workspace itself (its handler is
                            // closer to focus and delegates up here).
                            MoveIntent: CallbackAction<MoveIntent>(
                              onInvoke: (intent) {
                                final notifier = ref.read(
                                  screenStateProvider(screenId).notifier,
                                );
                                switch (intent.direction) {
                                  case NavigationDirection.up:
                                    notifier.moveSelectedTileableToWorkspace(
                                      -1,
                                    );
                                  case NavigationDirection.down:
                                    notifier.moveSelectedTileableToWorkspace(1);
                                  case NavigationDirection.left:
                                  case NavigationDirection.right:
                                    break;
                                }
                                return null;
                              },
                            ),
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            textDirection: TextDirection.rtl,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // The top panel style of the status bar
                                    // lays the workspaces out below it.
                                    if (ref.watch(
                                      statusBarSettingsProvider.select(
                                        (settings) => settings.showsTopPanel,
                                      ),
                                    ))
                                      const StatusTopPanel(),
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: SlidingContainer(
                                              direction: Axis.vertical,
                                              // Switching workspaces back and
                                              // forth reuses them rather than
                                              // building each one again.
                                              keepsPagesAlive: true,
                                              index: screenState.selectedIndex,
                                              onIndexChanged: (newIndex) {
                                                ref
                                                    .read(
                                                      screenStateProvider(
                                                        screenId,
                                                      ).notifier,
                                                    )
                                                    .selectWorkspace(newIndex);
                                              },
                                              isSwipeEnabled:
                                                  screenId ==
                                                      ref.watch(
                                                        placementScreenProvider,
                                                      ) &&
                                                  !overviewDisplayed,
                                              children: workspacePages.values
                                                  .toList(),
                                            ),
                                          ),
                                          // Hung from the top of the screen,
                                          // above the workspaces sliding
                                          // under it.
                                          _PlacedStatusNotch(
                                            screenId: screenId,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Material(
                                elevation: 4,
                                child: ScreenPanel(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const OverviewWidget(),
                    if (ref.watch(devToolsEnabledProvider))
                      const DevToolsOverview(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The status notch, placed right before the workspace panels' visible tile
/// picker, reaching over its rounded end. Hidden until the panel is measured.
class _PlacedStatusNotch extends ConsumerWidget {
  const _PlacedStatusNotch({required this.screenId});

  final ScreenId screenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trailingWidth = ref.watch(
      workspacePanelTrailingWidthProvider(screenId),
    );
    if (!ref.watch(statusBarSettingsProvider.select((s) => s.showsNotch))) {
      return const SizedBox.shrink();
    }
    return PositionedDirectional(
      top: 0,
      end: trailingWidth - StatusNotch.pickerOverlap,
      child: Visibility.maintain(
        visible: trailingWidth > 0,
        child: const StatusNotch(),
      ),
    );
  }
}
