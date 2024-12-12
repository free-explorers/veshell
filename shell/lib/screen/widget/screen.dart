import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview.dart';
import 'package:shell/screen/provider/current_screen_id.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/screen/widget/screen_panel.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/widget/sliding_container.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
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

    return Actions(
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
      },
      child: MouseRegion(
        onEnter: (event) {
          screenFocusScopeNode.requestFocus();
          focusLog.info('screenFocusScopeNode.requestFocus on MouseEnter');
        },
        child: FocusScope(
          node: screenFocusScopeNode,
          onFocusChange: (value) {
            focusLog.info('screenFocusScopeNode.onFocusChange: $value');
            if (value) {
              ref
                  .read(focusedScreenProvider.notifier)
                  .setFocusedScreen(screenId);
            }
          },
          child: Stack(
            children: [
              Row(
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
              const OverviewWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
