import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/provider/overview_is_displayed.dart';
import 'package:shell/overview/widget/overview.dart';
import 'package:shell/screen/model/screen_shortcuts.dart';
import 'package:shell/screen/provider/current_screen_id.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/screen/widget/screen_panel.dart';
import 'package:shell/shared/widget/sliding_container.dart';
import 'package:shell/workspace/provider/current_workspace_id.dart';
import 'package:shell/workspace/widget/workspace.dart';

/// Widget that represent the Screen in the widget tree
class ScreenWidget extends HookConsumerWidget {
  /// Const constructor
  const ScreenWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = ref.watch(currentScreenIdProvider);
    final screenState = ref.watch(screenStateProvider(screenId));

    final screenFocusScopeNode =
        useFocusScopeNode(debugLabel: 'ScreenFocusNode');

    final overviewAnimationController = useAnimationController(
      duration: const Duration(milliseconds: 200),
    );

    final animation = CurvedAnimation(
      parent: overviewAnimationController,
      curve: Curves.easeIn,
    );
    useEffect(
      () {
        ref.listen(overviewIsDisplayedProvider(screenId), (previous, next) {
          if (next) {
            overviewAnimationController.forward();
          } else {
            overviewAnimationController.reverse();
          }
        });

        return null;
      },
      [],
    );

    /* useEffect(
      () {
        onFocusChange() {
          if (screenFocusScopeNode.hasFocus) {
            screenFocusScopeNode.requestFocus();
          }
        }

        FocusManager.instance.addListener(onFocusChange);
        return () {
          FocusManager.instance.removeListener(onFocusChange);
        };
      },
      [],
    ); */
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyW):
            const FocusWorkspaceAboveIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS):
            const FocusWorkspaceBelowIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyO):
            const ToggleOverviewIntent(),
      },
      child: Actions(
        actions: {
          FocusWorkspaceAboveIntent: CallbackAction<FocusWorkspaceAboveIntent>(
            onInvoke: (_) {
              final nextIndex = screenState.selectedIndex - 1;
              if (nextIndex >= 0) {
                ref
                    .read(screenStateProvider(screenId).notifier)
                    .selectWorkspace(nextIndex);
              }
              return null;
            },
          ),
          FocusWorkspaceBelowIntent: CallbackAction<FocusWorkspaceBelowIntent>(
            onInvoke: (_) {
              final nextIndex = screenState.selectedIndex + 1;
              if (nextIndex < screenState.workspaceList.length) {
                ref
                    .read(screenStateProvider(screenId).notifier)
                    .selectWorkspace(nextIndex);
              }
              return null;
            },
          ),
          ToggleOverviewIntent: CallbackAction<ToggleOverviewIntent>(
            onInvoke: (_) {
              ref.read(overviewIsDisplayedProvider(screenId).notifier).toggle();
              return null;
            },
          ),
        },
        child: MouseRegion(
          onEnter: (event) => screenFocusScopeNode.requestFocus(),
          child: FocusScope(
            node: screenFocusScopeNode,
            onFocusChange: (value) {
              if (value) {
                ref
                    .read(focusedScreenProvider.notifier)
                    .setFocusedScreen(screenId);
              }
            },
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Stack(
                  children: [
                    child!,
                    if (overviewAnimationController.value > 0.0)
                      Opacity(
                        opacity: overviewAnimationController.value,
                        child: const Overview(),
                      ),
                  ],
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: SlidingContainer(
                      direction: Axis.vertical,
                      index: screenState.selectedIndex,
                      children: screenState.workspaceList
                          .mapIndexed(
                            (index, workspaceId) => ProviderScope(
                              key: Key(workspaceId),
                              overrides: [
                                currentWorkspaceIdProvider
                                    .overrideWith((ref) => workspaceId),
                              ],
                              child: WorkspaceWidget(
                                isSelected: screenState.selectedIndex == index,
                              ),
                            ),
                          )
                          .toList(),
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
      ),
    );
  }
}
